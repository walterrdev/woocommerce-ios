import Codegen

/// Represents the data associated with gift card stats over a specific period.
public struct GiftCardStatsTotals: Decodable, Equatable, GeneratedCopiable, GeneratedFakeable {
    /// Number of Gift Cards
    public let giftCardsCount: Int

    /// Used Amount
    public let usedAmount: Decimal

    /// Refunded Amount
    public let refundedAmount: Decimal

    /// Net Amount
    public let netAmount: Decimal

    public init(giftCardsCount: Int,
                usedAmount: Decimal,
                refundedAmount: Decimal,
                netAmount: Decimal) {
        self.giftCardsCount = giftCardsCount
        self.usedAmount = usedAmount
        self.refundedAmount = refundedAmount
        self.netAmount = netAmount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let giftCardsCount = try container.decode(Int.self, forKey: .giftCardsCount)
        let usedAmount = try container.decode(Decimal.self, forKey: .usedAmount)
        let refundedAmount = try container.decode(Decimal.self, forKey: .refundedAmount)
        let netAmount = try container.decode(Decimal.self, forKey: .netAmount)

        self.init(giftCardsCount: giftCardsCount,
                  usedAmount: usedAmount,
                  refundedAmount: refundedAmount,
                  netAmount: netAmount)
    }
}

extension GiftCardStatsTotals: WCAnalyticsStatsTotals {
    /// Represents a type of gift cards total data
    public enum TotalData: Double {
        case giftCardsCount
        case usedAmount
        case refundedAmount
        case netAmount
    }

    public func getDoubleValue(for data: TotalData) -> Double {
        switch data {
        case .giftCardsCount:
            return Double(giftCardsCount)
        case .usedAmount:
            return (usedAmount as NSNumber).doubleValue
        case .refundedAmount:
            return (refundedAmount as NSNumber).doubleValue
        case .netAmount:
            return (netAmount as NSNumber).doubleValue
        }
    }
}


// MARK: - Constants!
//
private extension GiftCardStatsTotals {
    enum CodingKeys: String, CodingKey {
        case giftCardsCount = "giftcards_count"
        case usedAmount = "used_amount"
        case refundedAmount = "refunded_amount"
        case netAmount = "net_amount"
    }
}
