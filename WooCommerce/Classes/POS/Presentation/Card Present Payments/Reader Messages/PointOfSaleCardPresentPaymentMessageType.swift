import Foundation

enum PointOfSaleCardPresentPaymentMessageType {
    case preparingForPayment(viewModel: PointOfSaleCardPresentPaymentPreparingForPaymentMessageViewModel)
    case tapSwipeOrInsertCard(viewModel: PointOfSaleCardPresentPaymentTapSwipeInsertCardMessageViewModel)
    case processing(viewModel: PointOfSaleCardPresentPaymentProcessingMessageViewModel)
    case displayReaderMessage(viewModel: PointOfSaleCardPresentPaymentDisplayReaderMessageMessageViewModel)
    case paymentSuccess(viewModel: PointOfSaleCardPresentPaymentSuccessMessageViewModel)
    case paymentError(viewModel: PointOfSaleCardPresentPaymentErrorMessageViewModel)
    case paymentErrorNonRetryable(viewModel: PointOfSaleCardPresentPaymentNonRetryableErrorMessageViewModel)
    case cancelledOnReader(viewModel: PointOfSaleCardPresentPaymentCancelledOnReaderMessageViewModel)
}
