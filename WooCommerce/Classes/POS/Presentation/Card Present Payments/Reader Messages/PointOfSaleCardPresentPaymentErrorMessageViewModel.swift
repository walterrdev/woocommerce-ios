import Foundation
import enum Yosemite.CardReaderServiceError

struct PointOfSaleCardPresentPaymentErrorMessageViewModel {
    let title = Localization.title
    let message: String
    let tryAgainButtonViewModel: CardPresentPaymentsModalButtonViewModel

    init(error: Error,
         tryAgainButtonAction: @escaping () -> Void) {
        self.message = Self.message(for: error)
        self.tryAgainButtonViewModel = CardPresentPaymentsModalButtonViewModel(
            title: Localization.tryAgain,
            actionHandler: tryAgainButtonAction)
    }

    private static func message(for error: Error) -> String {
        if let error = error as? CardReaderServiceError {
            return error.errorDescription ?? error.localizedDescription
        } else {
            return error.localizedDescription
        }
    }
}

private extension PointOfSaleCardPresentPaymentErrorMessageViewModel {
    enum Localization {
        static let title = NSLocalizedString(
            "pointOfSale.cardPresent.paymentError.title",
            value: "Payment failed",
            comment: "Error message. Presented to users after collecting a payment fails on the Point of Sale Checkout"
        )

        static let tryAgain =  NSLocalizedString(
            "pointOfSale.cardPresent.paymentError.tryAgain.button.title",
            value: "Try Again",
            comment: "Button to try to collect a payment again. Presented to users after collecting a payment fails on the Point of Sale Checkout"
        )
    }
}
