@testable import WooCommerce
import Foundation

/// Mock version of `BlazeEligibilityChecker` for easier unit testing.
final class MockBlazeEligibilityChecker: BlazeEligibilityCheckerProtocol {

    private let isSiteEligible: Bool
    private let isProductEligible: Bool

    init(isSiteEligible: Bool = false, isProductEligible: Bool = false) {
        self.isSiteEligible = isSiteEligible
        self.isProductEligible = isProductEligible
    }

    func isEligible() async -> Bool {
        isSiteEligible
    }

    func isEligible(product: WooCommerce.ProductFormDataModel, isPasswordProtected: Bool) async -> Bool {
        isProductEligible
    }
}
