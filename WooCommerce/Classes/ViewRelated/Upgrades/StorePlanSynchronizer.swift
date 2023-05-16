import Foundation
import Yosemite
import Combine

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

    /// Observable subscription store.
    ///
    private var subscriptions: Set<AnyCancellable> = []

    init(stores: StoresManager = ServiceLocator.stores,
         pushNotesManager: PushNotesManager = ServiceLocator.pushNotesManager) {
        self.stores = stores
        self.localNotificationScheduler = .init(pushNotesManager: pushNotesManager, stores: stores)

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

        let oneDayTimeInterval: TimeInterval = 86400

        if expiryDate.timeIntervalSinceNow - oneDayTimeInterval > 0 {
            scheduleBeforeExpirationNotification(siteID: siteID, expiryDate: expiryDate)
        }

        if expiryDate.timeIntervalSinceNow + oneDayTimeInterval > 0 {
            scheduleAfterExpirationNotification(siteID: siteID, expiryDate: expiryDate)
        }
    }

    func cancelFreeTrialExpirationNotifications(siteID: Int64) {
        localNotificationScheduler.cancel(scenario: .oneDayAfterFreeTrialExpires(siteID: siteID))
        localNotificationScheduler.cancel(scenario: .oneDayBeforeFreeTrialExpires(
            siteID: siteID,
            expiryDate: Date() // placeholder date, irrelevant to the notification identifier
        ))
    }

    func scheduleBeforeExpirationNotification(siteID: Int64, expiryDate: Date) {
        guard let notification = LocalNotification(scenario: .oneDayBeforeFreeTrialExpires(siteID: siteID, expiryDate: expiryDate)) else {
            return
        }
        /// Scheduled for 1 day before the expiry date
        var triggerDateComponents = expiryDate.dateAndTimeComponents()
        guard let day = triggerDateComponents.day else {
            return
        }
        triggerDateComponents.day = day - 1
        triggerDateComponents.timeZone = .current
        triggerDateComponents.calendar = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        Task {
            await localNotificationScheduler.schedule(notification: notification,
                                                      trigger: trigger,
                                                      remoteFeatureFlag: .oneDayBeforeFreeTrialExpiresNotification,
                                                      shouldSkipIfScheduled: true)
        }
    }

    func scheduleAfterExpirationNotification(siteID: Int64, expiryDate: Date) {
        guard let notification = LocalNotification(scenario: .oneDayAfterFreeTrialExpires(siteID: siteID)) else {
            return
        }
        /// Scheduled for 1 day after the expiry date
        var triggerDateComponents = expiryDate.dateAndTimeComponents()
        guard let day = triggerDateComponents.day else {
            return
        }
        triggerDateComponents.day = day + 1
        triggerDateComponents.timeZone = .current
        triggerDateComponents.calendar = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        Task {
            await localNotificationScheduler.schedule(notification: notification,
                                                      trigger: trigger,
                                                      remoteFeatureFlag: .oneDayAfterFreeTrialExpiresNotification,
                                                      shouldSkipIfScheduled: true)
        }
    }
}
