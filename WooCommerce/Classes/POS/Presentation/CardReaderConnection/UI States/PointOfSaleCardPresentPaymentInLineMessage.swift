import SwiftUI

struct PointOfSaleCardPresentPaymentInLineMessage: View {
    private let messageType: PointOfSaleCardPresentPaymentMessageType

    init(messageType: PointOfSaleCardPresentPaymentMessageType) {
        self.messageType = messageType
    }

    var body: some View {

        // TODO: replace temporary inline message UI based on design
        switch messageType {
        case .preparingForPayment(let viewModel):
            PointOfSaleCardPresentPaymentPreparingForPaymentMessageView(viewModel: viewModel)
        case .tapSwipeOrInsertCard(let viewModel):
            PointOfSaleCardPresentPaymentTapSwipeInsertCardMessageView(viewModel: viewModel)
        case .processing:
            POSCardPresentPaymentMessageView(viewModel: POSCardPresentPaymentMessageViewModel(title: "processing..."))
        case .displayReaderMessage(let viewModel):
            PointOfSaleCardPresentPaymentDisplayReaderMessageMessageView(viewModel: viewModel)
        case .paymentSuccess:
            POSCardPresentPaymentMessageView(viewModel: POSCardPresentPaymentMessageViewModel(title: "Payment successful!"))
        case .paymentError(let viewModel):
            PointOfSaleCardPresentPaymentErrorMessageView(viewModel: viewModel)
        case .paymentErrorNonRetryable(let viewModel):
            PointOfSaleCardPresentPaymentNonRetryableErrorMessageView(viewModel: viewModel)
        case .cancelledOnReader:
            POSCardPresentPaymentMessageView(viewModel: POSCardPresentPaymentMessageViewModel(title: "Payment cancelled on reader"))
        }
    }
}

#Preview {
    PointOfSaleCardPresentPaymentInLineMessage(messageType: .processing(
        viewModel: PointOfSaleCardPresentPaymentProcessingMessageViewModel()))
}
