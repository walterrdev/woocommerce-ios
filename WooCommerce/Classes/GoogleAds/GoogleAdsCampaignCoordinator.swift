import Foundation
import Yosemite

/// Reusable coordinator to handle Google Ads campaigns.
///
final class GoogleAdsCampaignCoordinator: Coordinator {
    let navigationController: UINavigationController

    private let siteID: Int64
    private let siteAdminURL: String

    private let hasGoogleAdsCampaigns: Bool
    private let shouldAuthenticateAdminPage: Bool
    private var bottomSheetPresenter: BottomSheetPresenter?

    init(siteID: Int64,
         siteAdminURL: String,
         hasGoogleAdsCampaigns: Bool,
         shouldAuthenticateAdminPage: Bool,
         navigationController: UINavigationController) {
        self.siteID = siteID
        self.siteAdminURL = siteAdminURL
        self.shouldAuthenticateAdminPage = shouldAuthenticateAdminPage
        self.hasGoogleAdsCampaigns = hasGoogleAdsCampaigns
        self.navigationController = navigationController
    }

    func start() {
        guard let url = createGoogleAdsCampaignURL() else {
            return
        }
        let controller = createCampaignViewController(with: url)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissCampaignView))
        navigationController.present(UINavigationController(rootViewController: controller), animated: true)
    }
}

// MARK: - Private helpers
//
private extension GoogleAdsCampaignCoordinator {
    @objc func dismissCampaignView() {
        navigationController.dismiss(animated: true)
    }

    func createCampaignViewController(with url: URL) -> UIViewController {
        let redirectHandler: (URL) -> Void = { [weak self] newURL in
            if newURL != url {
                self?.checkIfCampaignCreationSucceeded(url: newURL)
            }
        }
        if shouldAuthenticateAdminPage {
            let viewModel = DefaultAuthenticatedWebViewModel(
                title: Localization.googleForWooCommerce,
                initialURL: url,
                redirectHandler: redirectHandler
            )
            return AuthenticatedWebViewController(viewModel: viewModel)
        } else {
            let controller = WebViewHostingController(url: url, redirectHandler: redirectHandler)
            controller.title = Localization.googleForWooCommerce
            return controller
        }
    }

    func checkIfCampaignCreationSucceeded(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let queryItems = components?.queryItems
        let creationSucceeded = queryItems?.first(where: {
            $0.name == Constants.campaignParam &&
            $0.value == Constants.savedValue
        }) != nil
        if creationSucceeded {
            // dismisses the web view
            navigationController.dismiss(animated: true) { [self] in
                showSuccessView()
            }
            DDLogDebug("🎉 Google Ads campaign creation success")
        }
    }

    func createGoogleAdsCampaignURL() -> URL? {
        let path: String = {
            if hasGoogleAdsCampaigns {
                Constants.campaignDashboardPath
            } else {
                Constants.campaignCreationPath
            }
        }()
        return URL(string: siteAdminURL.appending(path))
    }

    func showSuccessView() {
        bottomSheetPresenter = buildBottomSheetPresenter()
        let controller = CelebrationHostingController(
            title: Localization.successTitle,
            subtitle: Localization.successSubtitle,
            closeButtonTitle: Localization.successCTA,
            image: .blazeSuccessImage,
            onTappingDone: { [weak self] in
            self?.bottomSheetPresenter?.dismiss()
            self?.bottomSheetPresenter = nil
        })
        bottomSheetPresenter?.present(controller, from: navigationController)
    }

    func buildBottomSheetPresenter() -> BottomSheetPresenter {
        BottomSheetPresenter(configure: { bottomSheet in
            var sheet = bottomSheet
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.prefersGrabberVisible = true
            sheet.detents = [.medium(), .large()]
        })
    }
}


private extension GoogleAdsCampaignCoordinator {
    enum Constants {
        static let campaignDashboardPath = "admin.php?page=wc-admin&path=%2Fgoogle%2Fdashboard"
        static let campaignCreationPath = "admin.php?page=wc-admin&path=%2Fgoogle%2Fdashboard&subpath=%2Fcampaigns%2Fcreate"
        static let campaignParam = "campaign"
        static let savedValue = "saved"
    }

    enum Localization {
        static let googleForWooCommerce = NSLocalizedString(
            "googleAdsCampaignCoordinator.googleForWooCommerce",
            value: "Google for WooCommerce",
            comment: "Title of the Google Ads campaign view"
        )
        static let successTitle = NSLocalizedString(
            "googleAdsCampaignCoordinator.successTitle",
            value: "Ready to Go!",
            comment: "Title of the celebration view when a Google ads campaign is successfully created."
        )
        static let successSubtitle = NSLocalizedString(
            "googleAdsCampaignCoordinator.successSubtitle",
            value: "Your new campaign has been created. Exciting times ahead for your sales!",
            comment: "Subtitle of the celebration view when a Google Ads campaign is successfully created."
        )
        static let successCTA = NSLocalizedString(
            "googleAdsCampaignCoordinator.successCTA",
            value: "Done",
            comment: "Button to dismiss the celebration view when a Google Ads campaign is successfully created."
        )
    }
}
