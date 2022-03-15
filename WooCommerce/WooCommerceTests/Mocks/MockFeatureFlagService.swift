@testable import WooCommerce
import Experiments

struct MockFeatureFlagService: FeatureFlagService {
    private let isJetpackConnectionPackageSupportOn: Bool
    private let isHubMenuOn: Bool
    private let isTaxLinesInSimplePaymentsOn: Bool
    private let isInboxOn: Bool
    private let isSplitViewInOrdersTabOn: Bool

    init(isJetpackConnectionPackageSupportOn: Bool = false,
         isHubMenuOn: Bool = false,
         isTaxLinesInSimplePaymentsOn: Bool = false,
         isInboxOn: Bool = false,
         isSplitViewInOrdersTabOn: Bool = false) {
        self.isJetpackConnectionPackageSupportOn = isJetpackConnectionPackageSupportOn
        self.isHubMenuOn = isHubMenuOn
        self.isTaxLinesInSimplePaymentsOn = isTaxLinesInSimplePaymentsOn
        self.isInboxOn = isInboxOn
        self.isSplitViewInOrdersTabOn = isSplitViewInOrdersTabOn
    }

    func isFeatureFlagEnabled(_ featureFlag: FeatureFlag) -> Bool {
        switch featureFlag {
        case .jetpackConnectionPackageSupport:
            return isJetpackConnectionPackageSupportOn
        case .hubMenu:
            return isHubMenuOn
        case .taxLinesInSimplePayments:
            return isTaxLinesInSimplePaymentsOn
        case .inbox:
            return isInboxOn
        case .splitViewInOrdersTab:
            return isSplitViewInOrdersTabOn
        default:
            return false
        }
    }
}
