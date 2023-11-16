import SwiftUI
import UIKit
import Yosemite

/// Displays a grid view of all available menu in the "Menu" tab (eg. View Store, Reviews, Coupons, etc...)
final class HubMenuViewController: UIHostingController<HubMenu> {
    private let viewModel: HubMenuViewModel
    private let tapToPayBadgePromotionChecker: TapToPayBadgePromotionChecker

    init(siteID: Int64,
         navigationController: UINavigationController?,
         tapToPayBadgePromotionChecker: TapToPayBadgePromotionChecker) {
        self.viewModel = HubMenuViewModel(siteID: siteID,
                                          navigationController: navigationController,
                                          tapToPayBadgePromotionChecker: tapToPayBadgePromotionChecker)
        self.tapToPayBadgePromotionChecker = tapToPayBadgePromotionChecker
        super.init(rootView: HubMenu(viewModel: viewModel))
        configureTabBarItem()
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.viewDidAppear()
    }

    /// Present the specific Review Details View from a push notification
    ///
    func pushReviewDetailsViewController(using parcel: ProductReviewFromNoteParcel) {
        viewModel.showReviewDetails(using: parcel)
    }

    func showPaymentsMenu(onCompletion: ((LegacyInPersonPaymentsMenuViewController?) -> Void)? = nil) -> LegacyInPersonPaymentsMenuViewController? {
        if viewModel.swiftUIPaymentsMenuEnabled {
            showNewPaymentsMenu()
            onCompletion?(nil)
            return nil
        } else {
            return showLegacyPaymentsMenu(onCompletion: onCompletion)
        }
    }

    func showNewPaymentsMenu() {
        viewModel.showingPayments = true
    }

    func showLegacyPaymentsMenu(onCompletion: ((LegacyInPersonPaymentsMenuViewController) -> Void)? = nil) -> LegacyInPersonPaymentsMenuViewController {
        let inPersonPaymentsMenuViewController = LegacyInPersonPaymentsMenuViewController(
            tapToPayBadgePromotionChecker: tapToPayBadgePromotionChecker,
            viewDidLoadAction: onCompletion)
        show(inPersonPaymentsMenuViewController, sender: self)

        return inPersonPaymentsMenuViewController
    }

    func showCoupons() {
        let enhancedCouponListViewController = EnhancedCouponListViewController(siteID: viewModel.siteID)
        show(enhancedCouponListViewController, sender: self)
    }

    /// Pushes the Settings & Privacy screen onto the navigation stack.
    ///
    func showPrivacySettings() {
        guard let navigationController else {
            return DDLogError("⛔️ Could not find a navigation controller context.")
        }
        guard let privacy = UIStoryboard.dashboard.instantiateViewController(ofClass: PrivacySettingsViewController.self) else {
            return DDLogError("⛔️ Could not instantiate PrivacySettingsViewController")
        }

        let settings = SettingsViewController()
        navigationController.setViewControllers(navigationController.viewControllers + [settings, privacy], animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // We want to hide navigation bar *only* on HubMenu screen. But on iOS 16, the `navigationBarHidden(true)`
        // modifier on `HubMenu` view hides the navigation bar for the whole navigation stack.
        // Here we manually hide or show navigation bar when entering or leaving the HubMenu screen.
        if #available(iOS 16.0, *) {
            self.navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if #available(iOS 16.0, *) {
            self.navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }
}

extension HubMenuViewController: DeepLinkNavigator {
    func navigate(to destination: any DeepLinkDestinationProtocol) {
        switch destination {
        case is PaymentsMenuDestination:
            if viewModel.swiftUIPaymentsMenuEnabled {
                _ = showPaymentsMenu() { [weak self] _ in
                    self?.viewModel.inPersonPaymentsMenuViewModel.navigate(to: destination)
                }
            } else {
                legacyHandlePaymentsMenuDeepLink(to: destination)
            }
        case is HubMenuDestination:
            handleHubMenuDeepLink(to: destination)
        default:
            break
        }
    }

    private func handleHubMenuDeepLink(to destination: any DeepLinkDestinationProtocol) {
        guard let hubMenuDestination = destination as? HubMenuDestination else {
            return
        }
        switch hubMenuDestination {
        case .paymentsMenu:
            _ = showPaymentsMenu()
        }
    }

    private func legacyHandlePaymentsMenuDeepLink(to destination: any DeepLinkDestinationProtocol) {
        guard let paymentsMenuDestination = destination as? PaymentsMenuDestination else {
            return
        }
        switch paymentsMenuDestination {
        case .collectPayment:
            _ = showPaymentsMenu { legacyPaymentsMenu in
                legacyPaymentsMenu?.openSimplePaymentsAmountFlow()
            }
        case .tapToPay:
            _ = showPaymentsMenu { legacyPaymentsMenu in
                legacyPaymentsMenu?.presentSetUpTapToPayOnIPhoneViewController()
            }
        }
    }
}

private extension HubMenuViewController {
    func configureTabBarItem() {
        tabBarItem.title = Localization.tabTitle
        tabBarItem.image = .hubMenu
        tabBarItem.accessibilityIdentifier = "tab-bar-menu-item"
    }
}

private extension HubMenuViewController {
    enum Localization {
        static let tabTitle = NSLocalizedString("Menu", comment: "Title of the Menu tab")
    }
}
