import Foundation
import SwiftUI

final class CardPresentPaymentConnectingFailedUpdateAddressAlertViewModel: ObservableObject {
    let title = Localization.title
    let image = Image(uiImage: .paymentErrorImage)
    let settingsAdminUrl: URL

    @Published var shouldShowSettingsWebView: Bool = false

    @Published var primaryButtonViewModel: CardPresentPaymentsModalButtonViewModel? = nil
    let cancelButtonViewModel: CardPresentPaymentsModalButtonViewModel

    private let retrySearchAction: () -> Void

    private var openSettingsButtonViewModel: CardPresentPaymentsModalButtonViewModel {
        CardPresentPaymentsModalButtonViewModel(
            title: Localization.openAdmin,
            actionHandler: { [weak self] in
                guard let self else { return }
                shouldShowSettingsWebView = true
                primaryButtonViewModel = retryButtonViewModel
            })
    }

    private var retryButtonViewModel: CardPresentPaymentsModalButtonViewModel

    init(settingsAdminUrl: URL,
         retrySearchAction: @escaping () -> Void,
         cancelSearchAction: @escaping () -> Void) {
        self.settingsAdminUrl = settingsAdminUrl
        self.retrySearchAction = retrySearchAction
        self.retryButtonViewModel = CardPresentPaymentsModalButtonViewModel(
            title: Localization.retry,
            actionHandler: retrySearchAction)
        self.cancelButtonViewModel = CardPresentPaymentsModalButtonViewModel(
            title: Localization.cancel,
            actionHandler: cancelSearchAction)
        self.primaryButtonViewModel = openSettingsButtonViewModel
    }

    func settingsWebViewWasDismissed() {
        retrySearchAction()
    }
}

private extension CardPresentPaymentConnectingFailedUpdateAddressAlertViewModel {
    enum Localization {
        static let title = NSLocalizedString(
            "cardPresentPayment.alert.connectingFailedUpdateAddress.title",
            value: "Please correct your store address to proceed",
            comment: "Title of the alert presented when the user tries to connect to a specific card reader and it fails " +
            "due to address problems"
        )

        static let openAdmin = NSLocalizedString(
            "cardPresentPayment.alert.connectingFailedUpdateAddress.openSettings.button.title",
            value: "Enter Address",
            comment: "Button to open a webview at the admin pages, so that the merchant can update their store address " +
            "to continue setting up In Person Payments"
        )

        static let retry = NSLocalizedString(
            "cardPresentPayment.alert.connectingFailedUpdateAddress.retry.button.title",
            value: "Retry After Updating",
            comment: "Button to try again after connecting to a specific reader fails due to address problems. " +
            "Intended for use after the merchant corrects the address in the store admin pages."
        )

        static let cancel = NSLocalizedString(
            "cardPresentPayment.alert.connectingFailedUpdateAddress.cancel.button.title",
            value: "Cancel",
            comment: "Button to dismiss the alert presented when connecting to a specific reader fails due to address " +
            "problems. This also cancels searching."
        )
    }
}
