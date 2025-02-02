import XCTest
import Yosemite
@testable import WooCommerce

final class BlazeEligibilityCheckerTests: XCTestCase {
    private var stores: MockStoresManager!

    override func setUp() {
        super.setUp()
        stores = MockStoresManager(sessionManager: .makeForTesting())
        ServiceLocator.setStores(stores)
    }

    override func tearDown() {
        stores = nil
        super.tearDown()
    }

    // MARK: - `isSiteEligible` for site

    func test_isEligible_is_true_when_authenticated_with_wpcom_and_feature_flag_enabled_and_blaze_approved() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: true)
        let checker = BlazeEligibilityChecker(stores: stores)

        // When
        let isEligible = checker.isSiteEligible(site)

        // Then
        XCTAssertTrue(isEligible)
    }

    func test_isEligible_is_false_when_authenticated_without_wpcom() {
        // Given
        let site = mockSite(isEligibleForBlaze: true)
        let nonWPCOMCredentialsValues: [Credentials] = [
            .applicationPassword(username: "", password: "", siteAddress: ""),
            .wporg(username: "", password: "", siteAddress: "")
        ]

        for nonWPCOMCredentials in nonWPCOMCredentialsValues {
            stores.authenticate(credentials: nonWPCOMCredentials)
            let checker = BlazeEligibilityChecker(stores: stores)

            // When
            let isEligible = checker.isSiteEligible(site)

            // Then
            XCTAssertFalse(isEligible)
        }
    }

    func test_isEligible_is_false_when_blaze_is_not_approved() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: false)
        let checker = BlazeEligibilityChecker(stores: stores)

        // When
        let isEligible = checker.isSiteEligible(site)

        // Then
        XCTAssertFalse(isEligible)
    }

    func test_isEligible_is_false_when_site_user_is_not_admin() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: true, isAdmin: false)
        let checker = BlazeEligibilityChecker(stores: stores)

        // When
        let isEligible = checker.isSiteEligible(site)

        // Then
        XCTAssertFalse(isEligible)
    }

    func test_isEligible_is_false_when_jetpack_not_installed() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: true,
                            isJetpackThePluginInstalled: false)
        let checker = BlazeEligibilityChecker(stores: stores)

        // When
        let isEligible = checker.isSiteEligible(site)

        // Then
        XCTAssertFalse(isEligible)
    }

    func test_isEligible_is_false_when_jetpack_installed_but_not_connected() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: true,
                            isJetpackThePluginInstalled: true,
                            isJetpackConnected: false)
        let checker = BlazeEligibilityChecker(stores: stores)

        // When
        let isEligible = checker.isSiteEligible(site)

        // Then
        XCTAssertFalse(isEligible)
    }

    // MARK: - `isProductEligible`

    func test_isProductEligible_is_true_when_wpcom_auth_and_feature_flag_enabled_and_blaze_approved_and_product_public_without_password() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: true)
        let checker = BlazeEligibilityChecker(stores: stores)
        let product = Product.fake().copy(statusKey: ProductStatus.published.rawValue)

        // When
        let isEligible = checker.isProductEligible(
            site: site,
            product: EditableProductModel(product: product),
            isPasswordProtected: false
        )

        // Then
        XCTAssertTrue(isEligible)
    }

    func test_isProductEligible_is_false_when_product_is_not_public() {
        // Given
        let nonPublicStatuses: [ProductStatus] = [.draft, .pending, .privateStatus, .autoDraft, .custom("status")]
        let checker = BlazeEligibilityChecker(stores: stores)

        for nonPublicStatus in nonPublicStatuses {
            let product = Product.fake().copy(statusKey: nonPublicStatus.rawValue)

            // When
            let isEligible = checker.isProductEligible(
                site: mockSite(isEligibleForBlaze: true),
                product: EditableProductModel(product: product),
                isPasswordProtected: false
            )

            // Then
            XCTAssertFalse(isEligible)
        }
    }

    func test_isProductEligible_is_false_when_product_is_password_protected() {
        // Given
        let checker = BlazeEligibilityChecker(stores: stores)
        let product = Product.fake().copy(statusKey: ProductStatus.published.rawValue)

        // When
        let isEligible = checker.isProductEligible(
            site: mockSite(isEligibleForBlaze: true),
            product: EditableProductModel(product: product),
            isPasswordProtected: true
        )

        // Then
        XCTAssertFalse(isEligible)
    }

    func test_isProductEligible_is_false_when_authenticated_without_wpcom() {
        // Given
        let nonWPCOMCredentialsValues: [Credentials] = [
            .applicationPassword(username: "", password: "", siteAddress: ""),
            .wporg(username: "", password: "", siteAddress: "")
        ]
        let product = Product.fake().copy(statusKey: ProductStatus.published.rawValue)

        for nonWPCOMCredentials in nonWPCOMCredentialsValues {
            stores.authenticate(credentials: nonWPCOMCredentials)
            let checker = BlazeEligibilityChecker(stores: stores)

            // When
            let isEligible = checker.isProductEligible(
                site: mockSite(isEligibleForBlaze: false),
                product: EditableProductModel(product: product),
                isPasswordProtected: false
            )

            // Then
            XCTAssertFalse(isEligible)
        }
    }

    func test_isProductEligible_is_false_when_blaze_is_not_approved() {
        // Given
        stores.authenticate(credentials: .wpcom(username: "", authToken: "", siteAddress: ""))
        let site = mockSite(isEligibleForBlaze: false)
        let checker = BlazeEligibilityChecker(stores: stores)
        let product = Product.fake().copy(statusKey: ProductStatus.published.rawValue)

        // When
        let isEligible = checker.isProductEligible(
            site: site,
            product: EditableProductModel(product: product),
            isPasswordProtected: false
        )

        // Then
        XCTAssertFalse(isEligible)
    }
}

private extension BlazeEligibilityCheckerTests {
    func mockSite(isEligibleForBlaze: Bool,
                  isAdmin: Bool = true,
                  isJetpackThePluginInstalled: Bool = true,
                  isJetpackConnected: Bool = true) -> Site {
        Site.fake().copy(siteID: 134,
                         isJetpackThePluginInstalled: isJetpackThePluginInstalled,
                         isJetpackConnected: isJetpackConnected,
                         canBlaze: isEligibleForBlaze,
                         isAdmin: isAdmin)
    }
}
