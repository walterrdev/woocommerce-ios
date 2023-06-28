import Foundation
import Yosemite
import Combine
import Experiments

/// Type that fetches and shares a `WPCom` store plan(subscription).
/// The plan is stored on memory and not on the Storage Layer because this only relates to `WPCom` stores.
///
final class StorePlanSynchronizer: ObservableObject {

    /// Dependency state.
    ///
    enum PlanState: Equatable {
        case notLoaded
        case loading
        case loaded(WPComSitePlan)
        case failed
        case unavailable
        case expired
    }

    /// Current synced plan.
    ///
    @Published private(set) var planState = PlanState.notLoaded

    /// Current logged-in site. `Nil` if not logged-in.
    ///
    private var site: Site?

    /// Stores manager.
    ///
    private let stores: StoresManager

    /// Handles local notifications for free trial plan expiration
    ///
    private let localNotificationScheduler: LocalNotificationScheduler

    /// Time zone used to scheduling local notifications.
    ///
    private let timeZone: TimeZone

    /// Observable subscription store.
    ///
    private var subscriptions: Set<AnyCancellable> = []

    private let featureFlagService: FeatureFlagService

    init(stores: StoresManager = ServiceLocator.stores,
         timeZone: TimeZone = .current,
         pushNotesManager: PushNotesManager = ServiceLocator.pushNotesManager,
         featureFlagService: FeatureFlagService = ServiceLocator.featureFlagService) {
        self.stores = stores
        self.localNotificationScheduler = .init(pushNotesManager: pushNotesManager, stores: stores)
        self.timeZone = timeZone
        self.featureFlagService = featureFlagService

        stores.site.sink { [weak self] site in
            guard let self else { return }
            self.site = site
            self.reloadPlan()
        }
        .store(in: &subscriptions)
    }

    /// Loads the plan from network
    ///
    func reloadPlan() {
        // If there is no logged-in site set the state to `.notLoaded`
        guard let site else {
            planState = .notLoaded
            return
        }

        // If the site is not a WPCom store set the state to `.unavailable`
        guard site.isWordPressComStore else {
            planState = .unavailable
            return
        }

        // Do not fetch the plan if the plan it is already being loaded.
        guard planState != .loading else { return }

        planState = .loading
            let action = PaymentAction.loadSiteCurrentPlan(siteID: site.siteID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let plan):
                self.planState = .loaded(plan)
                self.scheduleOrCancelNotificationsIfNeeded(for: plan)
            case .failure(LoadSiteCurrentPlanError.noCurrentPlan):
                // Since this is a WPCom store, if it has no plan its plan must have expired or been cancelled.
                // Generally, expiry is `.success(plan)` with a plan expiry date in the past, but in some cases, we just
                // don't get any plans marked as `current` in the plans response.
                self.planState = .expired
            case .failure(let error):
                self.planState = .failed
                DDLogError("⛔️ Error synchronizing WPCom plan: \(error)")
            }
        }
        stores.dispatch(action)
    }
}

// MARK: - Local notifications about trial plan expiration
//
private extension StorePlanSynchronizer {
    func scheduleOrCancelNotificationsIfNeeded(for plan: WPComSitePlan) {
        guard let siteID = site?.siteID else {
            return
        }
        guard plan.isFreeTrial, let expiryDate = plan.expiryDate else {
            /// cancels any scheduled notifications
            return cancelFreeTrialExpirationNotifications(siteID: siteID)
        }

        /// Normalizes expiry date to remove timezone difference
        let timeZoneDifference = timeZone.secondsFromGMT()
        let normalizedDate = Date(timeInterval: -Double(timeZoneDifference), since: expiryDate)
        let now = Date().normalizedDate() // with time removed

        /// Schedules pre-expiration notification if the plan is not expired in a day.
        if normalizedDate.timeIntervalSince(now) > Constants.oneDayTimeInterval {
            scheduleBeforeExpirationNotification(siteID: siteID, expiryDate: normalizedDate)
        }

        /// Schedules post-expiration notification if the plan hasn't expired for a day.
        if now.timeIntervalSince(normalizedDate) < Constants.oneDayTimeInterval {
            scheduleAfterExpirationNotification(siteID: siteID, expiryDate: normalizedDate)
        }

        if let subscribedDate = plan.subscribedDate,
           // Schedule notification only if the Free trial is subscribed less than 24 hrs ago
           Date().timeIntervalSince(subscribedDate) < Constants.oneDayTimeInterval {
            schedule24HrsAfterSubscribedNotification(siteID: siteID, subcribedDate: subscribedDate)
        }
    }

    func cancelFreeTrialExpirationNotifications(siteID: Int64) {
        localNotificationScheduler.cancel(scenario: .oneDayAfterFreeTrialExpires(siteID: siteID))
        localNotificationScheduler.cancel(scenario: .oneDayBeforeFreeTrialExpires(
            siteID: siteID,
            expiryDate: Date() // placeholder date, irrelevant to the notification identifier
        ))
        localNotificationScheduler.cancel(scenario: .twentyFourHoursAfterFreeTrialSubscribed(siteID: siteID))
    }

    func schedule24HrsAfterSubscribedNotification(siteID: Int64, subcribedDate: Date) {
        // TODO: #10094 Remove after adding remote feature flag
        guard featureFlagService.isFeatureFlagEnabled(.twentyFourHoursAfterFreeTrialSubscribedNotification) else {
            return
        }

        let notification = LocalNotification(scenario: .twentyFourHoursAfterFreeTrialSubscribed(siteID: siteID))

        /// Scheduled 24 hrs after subcribed date
        let triggerDateComponents = subcribedDate.addingTimeInterval(Constants.oneDayTimeInterval).dateAndTimeComponents()
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        Task {
            await localNotificationScheduler.schedule(notification: notification,
                                                      trigger: trigger,
                                                      remoteFeatureFlag: nil, // TODO: #10094 Add remote feature flag
                                                      shouldSkipIfScheduled: true)
        }
    }

    func scheduleBeforeExpirationNotification(siteID: Int64, expiryDate: Date) {
        let notification = LocalNotification(scenario: .oneDayBeforeFreeTrialExpires(siteID: siteID,
                                                                                     expiryDate: expiryDate))
        /// Scheduled for 1 day before the expiry date
        let triggerDateComponents = expiryDate.addingTimeInterval(-Constants.oneDayTimeInterval).dateAndTimeComponents()
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        Task {
            await localNotificationScheduler.schedule(notification: notification,
                                                      trigger: trigger,
                                                      remoteFeatureFlag: .oneDayBeforeFreeTrialExpiresNotification,
                                                      shouldSkipIfScheduled: true)
        }
    }

    func scheduleAfterExpirationNotification(siteID: Int64, expiryDate: Date) {
        let notification = LocalNotification(scenario: .oneDayAfterFreeTrialExpires(siteID: siteID))
        /// Scheduled for 1 day after the expiry date
        let triggerDateComponents = expiryDate.addingTimeInterval(Constants.oneDayTimeInterval).dateAndTimeComponents()
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        Task {
            await localNotificationScheduler.schedule(notification: notification,
                                                      trigger: trigger,
                                                      remoteFeatureFlag: .oneDayAfterFreeTrialExpiresNotification,
                                                      shouldSkipIfScheduled: true)
        }
    }
}

private extension StorePlanSynchronizer {
    enum Constants {
        static let oneDayTimeInterval: TimeInterval = 86400
    }
}
