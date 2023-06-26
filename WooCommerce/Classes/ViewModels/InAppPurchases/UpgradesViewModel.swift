import Foundation
import SwiftUI
import Yosemite

enum UpgradeViewState {
    case loading
    case loaded(WooWPComPlan)
    case purchasing(WooWPComPlan)
    case waiting(WooWPComPlan)
    case completed(WooWPComPlan)
    case prePurchaseError(PrePurchaseError)
    case purchaseUpgradeError(PurchaseUpgradeError)

    var shouldShowPlanDetailsView: Bool {
        switch self {
        case .loading, .loaded, .purchasing, .prePurchaseError:
            return true
        default:
            return false
        }
    }
}

enum PrePurchaseError: Error {
    case fetchError
    case entitlementsError
    case inAppPurchasesNotSupported
    case maximumSitesUpgraded
    case userNotAllowedToUpgrade
}

enum PurchaseUpgradeError {
    case inAppPurchaseFailed(WooWPComPlan, InAppPurchaseStore.Errors)
    case planActivationFailed(InAppPurchaseStore.Errors)
    case unknown
}

/// ViewModel for the Upgrades View
/// Drives the site's available In-App Purchases plan upgrades
///
final class UpgradesViewModel: ObservableObject {

    private let inAppPurchasesPlanManager: InAppPurchasesForWPComPlansProtocol
    private let siteID: Int64
    private let stores: StoresManager

    @Published var entitledWpcomPlanIDs: Set<String>

    @Published var upgradeViewState: UpgradeViewState = .loading

    private let localPlans: [WooPlan]

    private let analytics: Analytics

    init(siteID: Int64,
         inAppPurchasesPlanManager: InAppPurchasesForWPComPlansProtocol = InAppPurchasesForWPComPlansManager(),
         stores: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics) {
        self.siteID = siteID
        self.inAppPurchasesPlanManager = inAppPurchasesPlanManager
        self.stores = stores
        self.analytics = analytics

        entitledWpcomPlanIDs = []

        if let essentialPlan = WooPlan() {
            self.localPlans = [essentialPlan]
        } else {
            self.localPlans = []
        }

        if let site = ServiceLocator.stores.sessionManager.defaultSite, !site.isSiteOwner {
            self.upgradeViewState = .prePurchaseError(.userNotAllowedToUpgrade)
            analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .userNotAllowedToUpgrade))
        } else {
            Task {
                await fetchViewData()
            }
        }
    }

    /// Sync wrapper for `fetchViewData`, so can be called directly from where this
    /// ViewModel is referenced, outside of the initializer
    ///
    public func retryFetch() {
        Task {
            await fetchViewData()
        }
    }

    @MainActor
    private func fetchViewData() async {
        upgradeViewState = .loading
        await fetchPlans()
    }

    /// Retrieves all In-App Purchases WPCom plans
    ///
    @MainActor
    func fetchPlans() async {
        do {
            guard await inAppPurchasesPlanManager.inAppPurchasesAreSupported() else {
                upgradeViewState = .prePurchaseError(.inAppPurchasesNotSupported)
                analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .inAppPurchasesNotSupported))
                return
            }

            async let wpcomPlans = inAppPurchasesPlanManager.fetchPlans()
            async let hardcodedPlanDataIsValid = checkHardcodedPlanDataValidity()

            try await loadUserEntitlements(for: wpcomPlans)
            guard entitledWpcomPlanIDs.isEmpty else {
                upgradeViewState = .prePurchaseError(.maximumSitesUpgraded)
                analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .maximumSitesUpgraded))
                return
            }

            guard let plan = try await retrievePlanDetailsIfAvailable(.essentialMonthly,
                                                                      from: wpcomPlans,
                                                                      hardcodedPlanDataIsValid: hardcodedPlanDataIsValid)
            else {
                upgradeViewState = .prePurchaseError(.fetchError)
                analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .fetchError))
                return
            }
            upgradeViewState = .loaded(plan)
            analytics.track(.planUpgradeScreenLoaded)
        } catch {
            DDLogError("fetchPlans \(error)")
            upgradeViewState = .prePurchaseError(.fetchError)
            analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .fetchError))
        }
    }


    @MainActor
    private func checkHardcodedPlanDataValidity() async -> Bool {
        return await withCheckedContinuation { continuation in
            stores.dispatch(FeatureFlagAction.isRemoteFeatureFlagEnabled(
                .hardcodedPlanUpgradeDetailsMilestone1AreAccurate,
                defaultValue: true) { isEnabled in
                continuation.resume(returning: isEnabled)
            })
        }
    }

    private let notificationCenter: NotificationCenter = NotificationCenter.default
    private var applicationDidBecomeActiveObservationToken: NSObjectProtocol?

    /// Triggers the purchase of the specified In-App Purchases WPCom plans by the passed plan ID
    /// linked to the current site ID
    ///
    @MainActor
    func purchasePlan(with planID: String) async {
        analytics.track(event: .InAppPurchases.planUpgradePurchaseButtonTapped(planID))
        guard let wooWPComPlan = planCanBePurchasedFromCurrentState() else {
            return
        }

        upgradeViewState = .purchasing(wooWPComPlan)

        observeInAppPurchaseDrawerDismissal { [weak self] in
            /// The drawer gets dismissed when the IAP is cancelled too. That gets dealt with in the `do-catch`
            /// below, but this is usually received before the `.userCancelled`, so we need to wait a little
            /// before we try to advance to the waiting state.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                guard let self else { return }
                /// If the user cancelled, the state will be `.loaded(_)` by now, so we don't advance to waiting.
                /// Likewise, errors will have moved us to `.error(_)`, so we won't advance then either.
                if case .purchasing(_) = self.upgradeViewState {
                    self.upgradeViewState = .waiting(wooWPComPlan)
                }
            }
        }

        do {
            let result = try await inAppPurchasesPlanManager.purchasePlan(with: planID,
                                                                          for: siteID)
            stopObservingInAppPurchaseDrawerDismissal()
            switch result {
            case .userCancelled:
                upgradeViewState = .loaded(wooWPComPlan)
                analytics.track(.planUpgradeProcessingScreenDismissed)
            case .success(.verified(_)):
                upgradeViewState = .completed(wooWPComPlan)
                analytics.track(.planUpgradeCompletedScreenLoaded)
            default:
                // TODO: handle `pending` here... somehow – requires research
                // TODO: handle `.success(.unverified(_))` here... somehow
                return
            }
        } catch {
            DDLogError("purchasePlan \(error)")
            stopObservingInAppPurchaseDrawerDismissal()
            guard let recognisedError = error as? InAppPurchaseStore.Errors else {
                upgradeViewState = .purchaseUpgradeError(.unknown)
                analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .unknown))
                return
            }

            switch recognisedError {
            case .unverifiedTransaction,
                    .transactionProductUnknown,
                    .inAppPurchasesNotSupported,
                    .inAppPurchaseProductPurchaseFailed,
                    .inAppPurchaseStoreKitFailed:
                upgradeViewState = .purchaseUpgradeError(.inAppPurchaseFailed(wooWPComPlan, recognisedError))
            case .transactionMissingAppAccountToken,
                    .appAccountTokenMissingSiteIdentifier,
                    .storefrontUnknown:
                upgradeViewState = .purchaseUpgradeError(.planActivationFailed(recognisedError))
            }
        }
    }

    private func planCanBePurchasedFromCurrentState() -> WooWPComPlan? {
        switch upgradeViewState {
        case .loaded(let plan), .purchaseUpgradeError(.inAppPurchaseFailed(let plan, _)):
            return plan
        default:
            return nil
        }
    }

    /// Observes the `didBecomeActiveNotification` for one invocation of the notification.
    /// Using this in the scope of `purchasePlan` tells us when Apple's IAP view has completed.
    ///
    /// However, it can also be triggered by other actions, e.g. a phone call ending.
    ///
    /// One good example test is to start an IAP, then background the app and foreground it again
    /// before the IAP drawer is shown.  You'll see that this notification is received, even though the
    /// IAP drawer is then shown on top. Dismissing or completing the IAP will not then trigger this
    /// notification again.
    ///
    /// It's not perfect, but it's what we have.
    private func observeInAppPurchaseDrawerDismissal(whenFired action: @escaping (() -> Void)) {
        applicationDidBecomeActiveObservationToken = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main) { [weak self] notification in
                action()
                self?.stopObservingInAppPurchaseDrawerDismissal()
            }
    }

    private func stopObservingInAppPurchaseDrawerDismissal() {
        if let token = applicationDidBecomeActiveObservationToken {
            notificationCenter.removeObserver(token)
        }
    }

    /// Retrieves a specific In-App Purchase WPCom plan from the available products
    ///
    private func retrievePlanDetailsIfAvailable(_ type: AvailableInAppPurchasesWPComPlans,
                                                from wpcomPlans: [WPComPlanProduct],
                                                hardcodedPlanDataIsValid: Bool) -> WooWPComPlan? {
        guard let wpcomPlanProduct = wpcomPlans.first(where: { $0.id == type.rawValue }),
              let wooPlan = localPlans.first(where: { $0.id == wpcomPlanProduct.id }) else {
            return nil
        }
        return WooWPComPlan(wpComPlan: wpcomPlanProduct,
                            wooPlan: wooPlan,
                            hardcodedPlanDataIsValid: hardcodedPlanDataIsValid)
    }
}

private extension UpgradesViewModel {
    /// Iterates through all available WPCom plans and checks whether the merchant is entitled to purchase them
    /// via In-App Purchases
    ///
    @MainActor
    func loadUserEntitlements(for plans: [WPComPlanProduct]) async {
        do {
            for wpcomPlan in plans {
                if try await inAppPurchasesPlanManager.userIsEntitledToPlan(with: wpcomPlan.id) {
                    self.entitledWpcomPlanIDs.insert(wpcomPlan.id)
                } else {
                    self.entitledWpcomPlanIDs.remove(wpcomPlan.id)
                }
            }
        } catch {
            DDLogError("loadEntitlements \(error)")
            upgradeViewState = .prePurchaseError(.entitlementsError)
            analytics.track(event: .InAppPurchases.planUpgradePurchaseFailed(error: .entitlementsError))
        }
    }
}

extension UpgradesViewModel {
    func trackDismiss(step: WooAnalyticsEvent.InAppPurchases.Step) {
        analytics.track(event: .InAppPurchases.planUpgradeScreenDismissed(step: step))
    }
    
    func track(_ stat: WooAnalyticsStat) {
        analytics.track(stat)
    }
}

extension UpgradesViewModel {
    enum AvailableInAppPurchasesWPComPlans: String {
        case essentialMonthly = "debug.woocommerce.express.essential.monthly"
    }
}

struct WooWPComPlan {
    let wpComPlan: WPComPlanProduct
    let wooPlan: WooPlan
    let hardcodedPlanDataIsValid: Bool
}
