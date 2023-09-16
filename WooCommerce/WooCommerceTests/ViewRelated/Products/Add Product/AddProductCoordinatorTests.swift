import TestKit
import XCTest
import Yosemite

@testable import WooCommerce
import WordPressUI

final class AddProductCoordinatorTests: XCTestCase {
    private var navigationController: UINavigationController!

    override func setUp() {
        super.setUp()
        navigationController = UINavigationController()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        window.rootViewController = navigationController
    }

    override func tearDown() {
        navigationController = nil
        super.tearDown()
    }

    func test_it_presents_bottom_sheet_on_start() throws {
        // Arrange
        let coordinator = makeAddProductCoordinator()

        // Action
        coordinator.start()
        waitUntil {
            coordinator.navigationController.presentedViewController != nil
        }

        // Assert
        assertThat(coordinator.navigationController.presentedViewController, isAnInstanceOf: BottomSheetViewController.self)
    }

    func test_it_presents_AddProductWithAIActionSheet_on_start_when_eligible_for_ProductCreationAI() throws {
        // Given
        let coordinator = makeAddProductCoordinator(
            addProductWithAIEligibilityChecker: MockProductCreationAIEligibilityChecker(isEligible: true)
        )

        // When
        coordinator.start()
        waitUntil {
            coordinator.navigationController.presentedViewController != nil
        }

        // Then
        assertThat(coordinator.navigationController.presentedViewController, isAnInstanceOf: AddProductWithAIActionSheetHostingController.self)
    }
}

private extension AddProductCoordinatorTests {
    func makeAddProductCoordinator(
        addProductWithAIEligibilityChecker: ProductCreationAIEligibilityCheckerProtocol = MockProductCreationAIEligibilityChecker()
    ) -> AddProductCoordinator {
        let view = UIView()
        return AddProductCoordinator(siteID: 100,
                                     source: .productsTab,
                                     sourceView: view,
                                     sourceNavigationController: navigationController,
                                     addProductWithAIEligibilityChecker: addProductWithAIEligibilityChecker,
                                     isFirstProduct: false)
    }
}
