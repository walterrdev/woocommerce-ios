import UIKit
import Yosemite

/// Controller to wrap the products split view
///
final class ProductsSplitViewWrapperController: UIViewController {
    private let siteID: Int64

    private lazy var productsSplitViewController = WooSplitViewController(columnForCollapsingHandler: handleCollapsingSplitView)
    private lazy var productsViewController = ProductsViewController(siteID: siteID)

    init(siteID: Int64) {
        self.siteID = siteID
        super.init(nibName: nil, bundle: nil)
        configureTabBarItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
        configureChildViewController()
    }

    override var shouldShowOfflineBanner: Bool {
        return true
    }
}

private extension ProductsSplitViewWrapperController {
    func handleCollapsingSplitView(splitViewController: UISplitViewController) -> UISplitViewController.Column {
        // TODO: update the collapsing logic
        .secondary
    }
}

private extension ProductsSplitViewWrapperController {
    func configureSplitView() {
        let productsNavigationController = WooTabNavigationController()
        productsNavigationController.viewControllers = [productsViewController]
        productsSplitViewController.setViewController(productsNavigationController, for: .primary)
    }

    func configureTabBarItem() {
        tabBarItem.title = Localization.tabTitle
        tabBarItem.image = .productImage
        tabBarItem.accessibilityIdentifier = "tab-bar-products-item"
    }

    func configureChildViewController() {
        guard let contentView = productsSplitViewController.view else {
            return assertionFailure("Split view not available")
        }
        addChild(productsSplitViewController)
        view.addSubview(contentView)
        productsSplitViewController.didMove(toParent: self)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.pinSubviewToAllEdges(contentView)
    }
}

extension ProductsSplitViewWrapperController {
    private enum Localization {
        static let tabTitle = NSLocalizedString("productsTab.tabTitle",
                                                value: "Products",
                                                comment: "Title of the Products tab — plural form of Product")
    }
}
