import Foundation
import UIKit
import WordPressUI

/// Type to handle the privacy banner presentation.
///
final class PrivacyBannerPresenter {

    /// User Defaults database
    ///
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// Present the banner when the appropriate conditions are met.
    ///
    func presentIfNeeded(from viewController: UIViewController) {
        // Do not present the privacy banner  when running UI tests.
        let isUITesting: Bool = CommandLine.arguments.contains("-ui_testing")
        guard isUITesting == false else {
            return
        }

        guard ServiceLocator.featureFlagService.isFeatureFlagEnabled(.privacyChoices) else {
            return
        }

        let useCase = PrivacyBannerPresentationUseCase(defaults: defaults)
        Task {
            if await useCase.shouldShowPrivacyBanner() {
                await presentPrivacyBanner(from: viewController)
            }
        }
    }

    /// Presents the privacy banner using a `BottomSheetViewController`
    ///
    @MainActor private func presentPrivacyBanner(from viewController: UIViewController) {
        let privacyBanner = PrivacyBannerViewController(onCompletion: { [weak self] result in
            switch result {
            case .success(let destination):
                switch destination {
                case .dismiss:
                    viewController.dismiss(animated: true)

                case .settings:
                    viewController.dismiss(animated: true)
                    MainTabBarController.navigateToPrivacySettings()
                }
            case .failure(let error):
                switch error {
                case .sync(let analyticsOptOut):
                    viewController.dismiss(animated: true)
                    self?.showErrorNotice(optOut: analyticsOptOut)
                }
            }
        })

        let bottomSheetViewController = BottomSheetViewController(childViewController: privacyBanner)
        bottomSheetViewController.show(from: viewController)
    }

    /// Presents an error notice and provide a retry action to update the analytics setting.
    ///
    @MainActor private func showErrorNotice(optOut: Bool) {
        // Needed to treat every notice as unique. When not unique the notice presenter won't display subsequent error notices.
        let info = NoticeNotificationInfo(identifier: UUID().uuidString)
        let notice = Notice(title: Localization.errorTitle, feedbackType: .error, notificationInfo: info, actionTitle: Localization.retry, actionHandler: {
            let useCase = UpdateAnalyticsSettingUseCase()
            Task {
                do {
                    try await useCase.update(optOut: optOut)
                } catch {
                    // If the retry fails, show the error notice again.
                    self.showErrorNotice(optOut: optOut)
                }
            }
        })
        ServiceLocator.noticePresenter.enqueue(notice: notice)
    }
}

extension PrivacyBannerPresenter {
    enum Localization {
        static let errorTitle = NSLocalizedString("There was an error saving your privacy choices.",
                                                  comment: "Notice title when there is an error saving the privacy banner choice")
        static let retry = NSLocalizedString("Retry", comment: "Retry title on the notice action button")
    }
}
