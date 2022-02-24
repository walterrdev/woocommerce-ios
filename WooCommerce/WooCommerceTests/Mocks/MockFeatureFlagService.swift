@testable import WooCommerce
import Experiments

struct MockFeatureFlagService: FeatureFlagService {
    private let isJetpackConnectionPackageSupportOn: Bool
    private let isHubMenuOn: Bool
    private let isMyStoreTabUpdatesOn: Bool
    private let isTaxLinesInSimplePaymentsOn: Bool
    private let isInboxOn: Bool

    init(isJetpackConnectionPackageSupportOn: Bool = false,
         isHubMenuOn: Bool = false,
         isMyStoreTabUpdatesOn: Bool = false,
         isTaxLinesInSimplePaymentsOn: Bool = false,
         isInboxOn: Bool = false) {
        self.isJetpackConnectionPackageSupportOn = isJetpackConnectionPackageSupportOn
        self.isHubMenuOn = isHubMenuOn
        self.isMyStoreTabUpdatesOn = isMyStoreTabUpdatesOn
        self.isTaxLinesInSimplePaymentsOn = isTaxLinesInSimplePaymentsOn
        self.isInboxOn = isInboxOn
    }

    func isFeatureFlagEnabled(_ featureFlag: FeatureFlag) -> Bool {
        switch featureFlag {
        case .jetpackConnectionPackageSupport:
            return isJetpackConnectionPackageSupportOn
        case .hubMenu:
            return isHubMenuOn
        case .myStoreTabUpdates:
            return isMyStoreTabUpdatesOn
        case .taxLinesInSimplePayments:
            return isTaxLinesInSimplePaymentsOn
        case .inbox:
            return isInboxOn
        default:
            return false
        }
    }
}
