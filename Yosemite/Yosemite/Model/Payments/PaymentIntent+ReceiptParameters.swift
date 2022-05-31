import Hardware
import WooFoundation

public extension PaymentIntent {
    /// Maps a PaymentIntent into an struct that contains only the data we need to
    /// render a receipt.
    /// - Returns: an optional struct containing all the data that needs to go into a receipt
    func receiptParameters() -> CardPresentReceiptParameters? {
        guard let cardDetails = paymentMethod()?.cardPresentDetails else {
            return nil
        }

        let orderID = metadata?[CardPresentReceiptParameters.MetadataKeys.orderID]
            .flatMap { Int64($0) }

        return CardPresentReceiptParameters(amount: amount,
                                            formattedAmount: formattedAmount(amount),
                                            currency: currency,
                                            date: created,
                                            storeName: metadata?[CardPresentReceiptParameters.MetadataKeys.store],
                                            cardDetails: cardDetails,
                                            orderID: orderID)
    }

    private func formattedAmount(_ amount: UInt) -> String {
        let formatter = CurrencyFormatter(currencySettings: CurrencySettings())
        let decimalPosition = 2

        var amount: Decimal = Decimal(amount)
        amount = amount / pow(10, decimalPosition)

        return formatter.localize(amount, in: decimalPosition) ?? ""
    }
}
