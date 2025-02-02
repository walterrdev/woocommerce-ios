@testable import WooCommerce
import Experiments

struct MockFeatureFlagService: FeatureFlagService {
    private let isInboxOn: Bool
    private let isShowInboxCTAEnabled: Bool
    private let isUpdateOrderOptimisticallyOn: Bool
    private let shippingLabelsOnboardingM1: Bool
    private let isDomainSettingsEnabled: Bool
    private let isSupportRequestEnabled: Bool
    private let jetpackSetupWithApplicationPassword: Bool
    private let isReadOnlyGiftCardsEnabled: Bool
    private let betterCustomerSelectionInOrder: Bool
    private let productBundles: Bool
    private let productBundlesInOrderForm: Bool
    private let isScanToUpdateInventoryEnabled: Bool
    private let isBackendReceiptsEnabled: Bool
    private let sideBySideViewForOrderForm: Bool
    private let isSubscriptionsInOrderCreationCustomersEnabled: Bool
    private let isDisplayPointOfSaleToggleEnabled: Bool
    private let isProductCreationAIv2M1Enabled: Bool
    private let googleAdsCampaignCreationOnWebView: Bool

    init(isInboxOn: Bool = false,
         isShowInboxCTAEnabled: Bool = false,
         isUpdateOrderOptimisticallyOn: Bool = false,
         shippingLabelsOnboardingM1: Bool = false,
         isDomainSettingsEnabled: Bool = false,
         isSupportRequestEnabled: Bool = false,
         jetpackSetupWithApplicationPassword: Bool = false,
         isReadOnlyGiftCardsEnabled: Bool = false,
         betterCustomerSelectionInOrder: Bool = false,
         productBundles: Bool = false,
         productBundlesInOrderForm: Bool = false,
         isScanToUpdateInventoryEnabled: Bool = false,
         isBackendReceiptsEnabled: Bool = false,
         sideBySideViewForOrderForm: Bool = false,
         isSubscriptionsInOrderCreationCustomersEnabled: Bool = false,
         isDisplayPointOfSaleToggleEnabled: Bool = false,
         isProductCreationAIv2M1Enabled: Bool = false,
         googleAdsCampaignCreationOnWebView: Bool = false) {
        self.isInboxOn = isInboxOn
        self.isShowInboxCTAEnabled = isShowInboxCTAEnabled
        self.isUpdateOrderOptimisticallyOn = isUpdateOrderOptimisticallyOn
        self.shippingLabelsOnboardingM1 = shippingLabelsOnboardingM1
        self.isDomainSettingsEnabled = isDomainSettingsEnabled
        self.isSupportRequestEnabled = isSupportRequestEnabled
        self.jetpackSetupWithApplicationPassword = jetpackSetupWithApplicationPassword
        self.isReadOnlyGiftCardsEnabled = isReadOnlyGiftCardsEnabled
        self.betterCustomerSelectionInOrder = betterCustomerSelectionInOrder
        self.productBundles = productBundles
        self.productBundlesInOrderForm = productBundlesInOrderForm
        self.isScanToUpdateInventoryEnabled = isScanToUpdateInventoryEnabled
        self.isBackendReceiptsEnabled = isBackendReceiptsEnabled
        self.sideBySideViewForOrderForm = sideBySideViewForOrderForm
        self.isSubscriptionsInOrderCreationCustomersEnabled = isSubscriptionsInOrderCreationCustomersEnabled
        self.isDisplayPointOfSaleToggleEnabled = isDisplayPointOfSaleToggleEnabled
        self.isProductCreationAIv2M1Enabled = isProductCreationAIv2M1Enabled
        self.googleAdsCampaignCreationOnWebView = googleAdsCampaignCreationOnWebView
    }

    func isFeatureFlagEnabled(_ featureFlag: FeatureFlag) -> Bool {
        switch featureFlag {
        case .inbox:
            return isInboxOn
        case .showInboxCTA:
            return isShowInboxCTAEnabled
        case .updateOrderOptimistically:
            return isUpdateOrderOptimisticallyOn
        case .shippingLabelsOnboardingM1:
            return shippingLabelsOnboardingM1
        case .domainSettings:
            return isDomainSettingsEnabled
        case .supportRequests:
            return isSupportRequestEnabled
        case .jetpackSetupWithApplicationPassword:
            return jetpackSetupWithApplicationPassword
        case .readOnlyGiftCards:
            return isReadOnlyGiftCardsEnabled
        case .betterCustomerSelectionInOrder:
            return betterCustomerSelectionInOrder
        case .productBundles:
            return productBundles
        case .productBundlesInOrderForm:
            return productBundlesInOrderForm
        case .scanToUpdateInventory:
            return isScanToUpdateInventoryEnabled
        case .backendReceipts:
            return isBackendReceiptsEnabled
        case .sideBySideViewForOrderForm:
            return sideBySideViewForOrderForm
        case .subscriptionsInOrderCreationCustomers:
            return isSubscriptionsInOrderCreationCustomersEnabled
        case .displayPointOfSaleToggle:
            return isDisplayPointOfSaleToggleEnabled
        case .productCreationAIv2M1:
            return isProductCreationAIv2M1Enabled
        case .googleAdsCampaignCreationOnWebView:
            return googleAdsCampaignCreationOnWebView
        default:
            return false
        }
    }
}
