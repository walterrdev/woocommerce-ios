import Foundation
import Yosemite

/// Helper to update an `order` given an `OrderFeeLine` input type.
///
struct FeesInputTransformer {
    /// Adds, deletes, or updates a fee line input into an existing order.
    ///
    static func setFee(input: OrderFeeLine?, on order: Order) -> Order {
        // If input is `nil`, then we remove the first existing fee line.
        guard let input = input else {
            let updatedLines = order.fees.enumerated().map { index, line -> OrderFeeLine in
                if index == 0 {
                    return OrderFactory.deletedFeeLine(line)
                }
                return line
            }
            return order.copy(fees: updatedLines)
        }

        // If there is no existing fee lines, we insert the input one.
        guard let existingFeeLine = order.fees.first else {
            return order.copy(fees: [input])
        }

        // Since we only support one fee line, if we find one, we update the existing with the new input values.
        var updatedLines = order.fees
        let updatedFeeLine = existingFeeLine.copy(total: input.total)
        updatedLines[0] = updatedFeeLine

        return order.copy(fees: updatedLines)
    }

    /// Adds a fee into an existing order.
    ///
    static func append(input: OrderFeeLine, on order: Order) -> Order {
        guard !order.fees.contains(input) else {
            return order
        }

        return order.copy(fees: order.fees + [input])
    }

    /// Updates a fee into an existing order. If the fee is not there, it returns the order as it is.
    ///
    static func update(input: OrderFeeLine, on order: Order) -> Order {
        guard let index = order.fees.firstIndex(where: { $0.feeID == input.feeID }) else {
            return order
        }

        var updatedLines = order.fees
        updatedLines[index] = input

        return order.copy(fees: updatedLines)
    }

    /// Removes a fee line input from an existing order.
    /// If the order does not have that fee added it does nothing
    ///
    static func remove(input: OrderFeeLine, from order: Order) -> Order {
        let updatedLines = order.fees.map { line -> OrderFeeLine in
            if line.feeID == input.feeID {
                return OrderFactory.deletedFeeLine(line)
            }
            return line
        }
        return order.copy(fees: updatedLines)
    }
}
