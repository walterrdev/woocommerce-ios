import Foundation
import SwiftUI

struct PointOfSaleCardPresentPaymentOptionalReaderUpdateInProgressAlertViewModel {
    let title: String = Localization.title
    let image: Image
    let progressTitle: String
    let progressSubtitle: String = Localization.messageOptional
    let cancelButtonTitle: String
    let cancelReaderUpdate: (() -> Void)?

    init(progress: Float, cancel: (() -> Void)?) {
        self.image = Image(uiImage: .softwareUpdateProgress(progress: CGFloat(progress)))
        self.progressTitle = String(format: Localization.percentCompleteFormat, 100 * progress)

        self.cancelButtonTitle = Localization.cancelOptionalButtonText
        self.cancelReaderUpdate = cancel
    }
}

private extension PointOfSaleCardPresentPaymentOptionalReaderUpdateInProgressAlertViewModel {
    enum Localization {
        static let title = NSLocalizedString(
            "pointOfSale.cardPresentPayment.alert.optionalReaderUpdateInProgress.title",
            value: "Updating software",
            comment: "Dialog title that displays when a software update is being installed"
        )

        static let messageOptional = NSLocalizedString(
            "pointOfSale.cardPresentPayment.alert.optionalReaderUpdateInProgress.message",
            value: "Your reader will automatically restart and reconnect after the update is complete.",
            comment: "Label that displays when an optional software update is happening"
        )

        static let cancelOptionalButtonText = NSLocalizedString(
            "pointOfSale.cardPresentPayment.alert.optionalReaderUpdateInProgress.button.cancel.title",
            value: "Cancel",
            comment: "Label for a cancel button when an optional software update is happening"
        )

        static let percentCompleteFormat = NSLocalizedString(
            "pointOfSale.cardPresentPayment.alert.optionalReaderUpdateInProgress.progress.format",
            value: "%.0f%% complete",
            comment: "Label that describes the completed progress of an update being installed (e.g. 15% complete). Keep the %.0f%% exactly as is"
        )
    }
}
