import Foundation
import Storage

public struct CardPresentPaymentsOnboardingUseCase {
    let storageManager: StorageManagerType
    let dispatch: (Action) -> Void
    let siteID: Int64

    public init(siteID: Int64, storageManager: StorageManagerType, dispatch: @escaping (Action) -> Void) {
        self.storageManager = storageManager
        self.dispatch = dispatch
        self.siteID = siteID
    }

    public func synchronizeRequiredData(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        // We need to sync settings to check the store's country
        let settingsAction = SettingAction.synchronizeGeneralSiteSettings(siteID: siteID) { error in
            if let error = error {
                DDLogError("[CardPresentPaymentsOnboarding] Error syncing site settings: \(error)")
            }
            group.leave()
        }
        group.enter()
        dispatch(settingsAction)

        // We need to sync plugins to check if WCPay is installed, up to date, and active
        let sitePluginsAction = SitePluginAction.synchronizeSitePlugins(siteID: siteID) { result in
            if case let .failure(error) = result {
                DDLogError("[CardPresentPaymentsOnboarding] Error syncing site plugins: \(error)")
            }
            group.leave()
        }
        group.enter()
        dispatch(sitePluginsAction)

        // We need to sync payment gateway accounts to see if WCPay is set up correctly
        let paymentGatewayAccountsAction = PaymentGatewayAccountAction.loadAccounts(siteID: siteID) { result in
            if case let .failure(error) = result {
                DDLogError("[CardPresentPaymentsOnboarding] Error syncing payment gateway accounts: \(error)")
            }
            group.leave()
        }
        group.enter()
        dispatch(paymentGatewayAccountsAction)

        group.notify(queue: .main, execute: completion)
    }

    public func checkOnboardingState() -> CardPresentPaymentOnboardingState {
        // Country checks
        guard isCountrySupported() else {
            return .countryNotSupported
        }

        // Plugin checks
        guard let plugin = getWCPayPlugin() else {
            return .wcpayNotInstalled
        }
        guard isWCPayVersionSupported(plugin: plugin) else {
            return .wcpayUnsupportedVersion
        }
        guard isWCPayActivated(plugin: plugin) else {
            return .wcpayNotActivated
        }

        // Account checks
        guard let account = getWCPayAccount() else {
            return .genericError
        }
        guard isWCPaySetupCompleted(account: account) else {
            return .wcpaySetupNotCompleted
        }
        guard !isWCPayInTestModeWithLiveStripeAccount(account: account) else {
            return .wcpayInTestModeWithLiveStripeAccount
        }
        guard !isStripeAccountUnderReview(account: account) else {
            return .stripeAccountUnderReview
        }
        guard !isStripeAccountPendingRequirements(account: account) else {
            return .stripeAccountPendingRequirement
        }
        guard !isStripeAccountOverdueRequirements(account: account) else {
            return .stripeAccountOverdueRequirement
        }
        guard !isStripeAccountRejected(account: account) else {
            return .stripeAccountRejected
        }
        guard !isInUndefinedState(account: account) else {
            return .genericError
        }

        return .completed
    }
}

private extension CardPresentPaymentsOnboardingUseCase {
    func isCountrySupported() -> Bool {
        // TODO: not implemented yet
        return true
    }

    func getWCPayPlugin() -> SitePlugin? {
        storageManager.viewStorage
            .loadPlugin(siteID: siteID, name: Constants.pluginName)?
            .toReadOnly()
    }

    func isWCPayVersionSupported(plugin: SitePlugin) -> Bool {
        // TODO: not implemented yet
        return true
    }

    func isWCPayActivated(plugin: SitePlugin) -> Bool {
        // TODO: not implemented yet
        return true
    }

    func getWCPayAccount() -> PaymentGatewayAccount? {
        storageManager.viewStorage
            .loadPaymentGatewayAccounts(siteID: siteID)
            .first(where: \.isCardPresentEligible)?
            .toReadOnly()
    }

    func isWCPaySetupCompleted(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return true
    }

    func isWCPayInTestModeWithLiveStripeAccount(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

    func isStripeAccountUnderReview(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

    func isStripeAccountPendingRequirements(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

    func isStripeAccountOverdueRequirements(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

    func isStripeAccountRejected(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

    func isInUndefinedState(account: PaymentGatewayAccount) -> Bool {
        // TODO: not implemented yet
        return false
    }

}

private enum Constants {
    static let pluginName = "WooCommerce Payments"
}
