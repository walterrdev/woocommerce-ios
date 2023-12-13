import Experiments
import SwiftUI
import WooFoundation
import Yosemite

/// View model for `CollapsibleProductCard`.
struct CollapsibleProductCardViewModel: Identifiable {
    var id: Int64 {
        productRow.productViewModel.id
    }

    /// The main/parent product row.
    let productRow: CollapsibleProductRowCardViewModel

    /// Child product rows, if the product is the parent of child order items
    let childProductRows: [CollapsibleProductRowCardViewModel]

    init(productRow: CollapsibleProductRowCardViewModel,
         childProductRows: [CollapsibleProductRowCardViewModel]) {
        self.productRow = productRow
        self.childProductRows = childProductRows
    }
}

/// View model for `CollapsibleProductRowCard`.
struct CollapsibleProductRowCardViewModel: Identifiable {
    var id: Int64 {
        productViewModel.id
    }

    /// Whether a product in an order item has a parent order item
    let hasParentProduct: Bool

    /// Whether the product row is read-only. Defaults to `false`.
    ///
    /// Used to remove product editing controls for read-only order items (e.g. child items of a product bundle).
    let isReadOnly: Bool

    /// Whether a product in an order item is configurable
    let isConfigurable: Bool

    /// Closure to configure a product if it is configurable.
    let configure: (() -> Void)?

    /// Label showing product details for an order item.
    /// Can include product type (if the row is configurable), variation attributes (if available), and stock status.
    ///
    let productDetailsLabel: String

    let productViewModel: ProductRowViewModel
    let stepperViewModel: ProductStepperViewModel
    let priceSummaryViewModel: CollapsibleProductCardPriceSummaryViewModel

    private let currencyFormatter: CurrencyFormatter
    private let analytics: Analytics

    init(hasParentProduct: Bool = false,
         isReadOnly: Bool = false,
         isConfigurable: Bool = false,
         productTypeDescription: String,
         attributes: [VariationAttributeViewModel],
         stockStatus: ProductStockStatus,
         stockQuantity: Decimal?,
         manageStock: Bool,
         productViewModel: ProductRowViewModel,
         stepperViewModel: ProductStepperViewModel,
         currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings),
         analytics: Analytics = ServiceLocator.analytics,
         configure: (() -> Void)? = nil) {
        self.hasParentProduct = hasParentProduct
        self.isReadOnly = isReadOnly
        self.isConfigurable = configure != nil ? isConfigurable : false
        self.configure = configure
        productDetailsLabel = CollapsibleProductRowCardViewModel.createProductDetailsLabel(isConfigurable: isConfigurable,
                                                                                           productTypeDescription: productTypeDescription,
                                                                                           attributes: attributes,
                                                                                           stockStatus: stockStatus,
                                                                                           stockQuantity: stockQuantity,
                                                                                           manageStock: manageStock)
        self.productViewModel = productViewModel
        self.stepperViewModel = stepperViewModel
        self.priceSummaryViewModel = .init(pricedIndividually: productViewModel.pricedIndividually,
                                           quantity: stepperViewModel.quantity,
                                           price: productViewModel.price)
        self.currencyFormatter = currencyFormatter
        self.analytics = analytics

        observeProductQuantityFromStepperViewModel()
    }

    func trackAddDiscountTapped() {
        analytics.track(event: .Orders.productDiscountAddButtonTapped())
    }

    func trackEditDiscountTapped() {
        analytics.track(event: .Orders.productDiscountEditButtonTapped())
    }
}

extension CollapsibleProductRowCardViewModel {
    /// Formatted price label based on a product's price and quantity. Accounting for discounts, if any.
    /// e.g: If price is $5, quantity is 10, and discount is $1, outputs "$49.00"
    ///
    var totalPriceAfterDiscountLabel: String? {
        guard let price = productViewModel.price,
              let priceDecimal = currencyFormatter.convertToDecimal(price) else {
            return nil
        }
        let subtotalDecimal = priceDecimal.multiplying(by: stepperViewModel.quantity as NSDecimalNumber)
        let totalPriceAfterDiscount = subtotalDecimal.subtracting((productViewModel.discount ?? Decimal.zero) as NSDecimalNumber)

        return currencyFormatter.formatAmount(totalPriceAfterDiscount)
    }

    /// Formatted discount label for an individual product
    ///
    var discountLabel: String? {
        guard let discount = productViewModel.discount else {
            return nil
        }
        return currencyFormatter.formatAmount(discount)
    }

    var hasDiscount: Bool {
        productViewModel.discount != nil
    }
}

private extension CollapsibleProductRowCardViewModel {
    /// Creates the label showing product details for an order item.
    /// Can include product type (if the row is configurable), variation attributes (if available), and stock status.
    ///
    static func createProductDetailsLabel(isConfigurable: Bool,
                                          productTypeDescription: String,
                                          attributes: [VariationAttributeViewModel] = [],
                                          stockStatus: ProductStockStatus,
                                          stockQuantity: Decimal?,
                                          manageStock: Bool) -> String {
        let productTypeLabel: String? = isConfigurable ? productTypeDescription : nil
        let attributesLabel: String? = attributes.isNotEmpty ? attributes.map { $0.nameOrValue }.joined(separator: ", ") : nil
        let stockLabel = createStockText(stockStatus: stockStatus, stockQuantity: stockQuantity, manageStock: manageStock)

        return [productTypeLabel, attributesLabel, stockLabel]
            .compactMap({ $0 })
            .filter { $0.isNotEmpty }
            .joined(separator: " • ")
    }

    /// Creates the stock text based on a product's stock status/quantity.
    ///
    static func createStockText(stockStatus: ProductStockStatus, stockQuantity: Decimal?, manageStock: Bool) -> String {
        switch (stockStatus, stockQuantity, manageStock) {
        case (.inStock, .some(let stockQuantity), true):
            let localizedStockQuantity = NumberFormatter.localizedString(from: stockQuantity as NSDecimalNumber, number: .decimal)
            return String.localizedStringWithFormat(Localization.stockFormat, localizedStockQuantity)
        default:
            return stockStatus.description
        }
    }
}

private extension CollapsibleProductRowCardViewModel {
    func observeProductQuantityFromStepperViewModel() {
        stepperViewModel.$quantity
            .assign(to: &productViewModel.$quantity)
    }
}

private extension CollapsibleProductRowCardViewModel {
    enum Localization {
        static let stockFormat = NSLocalizedString("CollapsibleProductRowCardViewModel.stockFormat",
                                                   value: "%1$@ in stock",
                                                   comment: "Label about product's inventory stock status shown during order creation")
    }
}
