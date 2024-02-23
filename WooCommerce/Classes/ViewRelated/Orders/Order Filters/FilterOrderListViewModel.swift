import UIKit
import Yosemite

/// `FilterListViewModel` for filtering a list of orders.
final class FilterOrderListViewModel: FilterListViewModel {
    typealias Criteria = Filters

    /// Aggregates the filter values that can be updated in the Filter Order UI.
    struct Filters: Equatable {
        let orderStatus: [OrderStatusEnum]?
        let dateRange: OrderDateRangeFilter?
        let product: FilterOrdersByProduct?

        let numberOfActiveFilters: Int

        init() {
            orderStatus = nil
            dateRange = nil
            product = nil
            numberOfActiveFilters = 0
        }

        init(orderStatus: [OrderStatusEnum]?,
             dateRange: OrderDateRangeFilter?,
             product: FilterOrdersByProduct?,
             numberOfActiveFilters: Int) {
            self.orderStatus = orderStatus
            self.dateRange = dateRange
            self.product = product
            self.numberOfActiveFilters = numberOfActiveFilters
        }

        var readableString: String {
            var readable: [String] = []
            if let orderStatus = orderStatus, orderStatus.count > 0 {
                readable = orderStatus.map { $0.rawValue.capitalized }
            }
            if let dateRange = dateRange {
                readable.append(dateRange.description)
            }
            if let product = product {
                readable.append(product.name)
            }
            return readable.joined(separator: ", ")
        }
    }

    let filterActionTitle = Localization.filterActionTitle

    let filterTypeViewModels: [FilterTypeViewModel]

    private let orderStatusFilterViewModel: FilterTypeViewModel
    private let dateRangeFilterViewModel: FilterTypeViewModel
    private let productFilterViewModel: FilterTypeViewModel

    /// - Parameters:
    ///   - filters: the filters to be applied initially.
    ///   - allowedStatuses: the statuses that will be shown in the filter list.
    ///   - siteID: current selected site ID
    init(filters: Filters, allowedStatuses: [OrderStatus], siteID: Int64) {
        orderStatusFilterViewModel = OrderListFilter.orderStatus.createViewModel(filters: filters, allowedStatuses: allowedStatuses)
        dateRangeFilterViewModel = OrderListFilter.dateRange.createViewModel(filters: filters, allowedStatuses: allowedStatuses)
        productFilterViewModel = OrderListFilter.product(siteID: siteID).createViewModel(filters: filters, allowedStatuses: allowedStatuses)

        filterTypeViewModels = [orderStatusFilterViewModel, dateRangeFilterViewModel, productFilterViewModel]
    }

    var criteria: Filters {
        let orderStatus = orderStatusFilterViewModel.selectedValue as? [OrderStatusEnum] ?? nil
        let dateRange = dateRangeFilterViewModel.selectedValue as? OrderDateRangeFilter ?? nil
        let product = productFilterViewModel.selectedValue as? FilterOrdersByProduct ?? nil
        let numberOfActiveFilters = filterTypeViewModels.numberOfActiveFilters
        return Filters(orderStatus: orderStatus,
                       dateRange: dateRange,
                       product: product,
                       numberOfActiveFilters: numberOfActiveFilters)
    }

    func clearAll() {
        let clearedOrderStatus: OrderStatusEnum? = nil
        orderStatusFilterViewModel.selectedValue = clearedOrderStatus

        let clearedDateRange: OrderDateRangeFilter? = nil
        dateRangeFilterViewModel.selectedValue = clearedDateRange

        let clearedProduct: FilterOrdersByProduct? = nil
        productFilterViewModel.selectedValue = clearedProduct
    }
}

extension FilterOrderListViewModel {
    /// Rows listed in the order they appear on screen
    ///
    enum OrderListFilter {
        case orderStatus
        case dateRange
        case product(siteID: Int64)
    }
}

private extension FilterOrderListViewModel.OrderListFilter {
    var title: String {
        switch self {
        case .orderStatus:
            return Localization.rowTitleOrderStatus
        case .dateRange:
            return Localization.rowTitleDateRange
        case .product:
            return Localization.rowTitleProduct
        }
    }
}

extension FilterOrderListViewModel.OrderListFilter {
    func createViewModel(filters: FilterOrderListViewModel.Filters, allowedStatuses: [OrderStatus]) -> FilterTypeViewModel {
        switch self {
        case .orderStatus:
            return FilterTypeViewModel(title: title,
                                       listSelectorConfig: .ordersStatuses(allowedStatuses: allowedStatuses),
                                       selectedValue: filters.orderStatus)
        case .dateRange:
            return FilterTypeViewModel(title: title,
                                       listSelectorConfig: .ordersDateRange,
                                       selectedValue: filters.dateRange)
        case .product(let siteID):
            return FilterTypeViewModel(title: title,
                                       listSelectorConfig: .products(siteID: siteID),
                                       selectedValue: filters.product)
        }
    }
}

// MARK: - FilterType conformance
extension OrderStatusEnum: FilterType {
    var isActive: Bool {
        return true
    }

    /// Returns the localized text version of the Enum
    ///
    var description: String {
        switch self {
        case .autoDraft:
            return NSLocalizedString("Draft", comment: "Display label for auto-draft order status.")
        case .pending:
            return NSLocalizedString("Pending", comment: "Display label for pending order status.")
        case .processing:
            return NSLocalizedString("Processing", comment: "Display label for processing order status.")
        case .onHold:
            return NSLocalizedString("On hold", comment: "Display label for on hold order status.")
        case .failed:
            return NSLocalizedString("Failed", comment: "Display label for failed order status.")
        case .cancelled:
            return NSLocalizedString("Cancelled", comment: "Display label for cancelled order status.")
        case .completed:
            return NSLocalizedString("Completed", comment: "Display label for completed order status.")
        case .refunded:
            return NSLocalizedString("Refunded", comment: "Display label for refunded order status.")
        case .custom(let payload):
            return payload // unable to localize at runtime.
        }
    }
}

extension Array: FilterType where Element == OrderStatusEnum {
    var isActive: Bool {
        return true
    }

    /// Returns the localized text version of the array
    ///
    var description: String {
        if self.count == 0 {
            return NSLocalizedString("Any", comment: "Display label for all order statuses selected in Order Filters")
        }
        else if self.count == 1 {
            return self.first?.description ?? ""
        }
        else {
            return "\(self.count)"
        }
    }
}

extension FilterOrdersByProduct: FilterType {
    /// The user-facing description of the filter value.
    var description: String { name }

    /// Whether the filter is set to a non-empty value.
    var isActive: Bool { true }
}

// MARK: - Constants
private extension FilterOrderListViewModel {
    enum Localization {
        static let filterActionTitle = NSLocalizedString("Show Orders", comment: "Button title for applying filters to a list of orders.")
    }
}

private extension FilterOrderListViewModel.OrderListFilter {
    enum Localization {
        static let rowTitleOrderStatus = NSLocalizedString("Order Status", comment: "Row title for filtering orders by order status.")
        static let rowTitleDateRange = NSLocalizedString("Date Range", comment: "Row title for filtering orders by date range.")
        static let rowTitleProduct = NSLocalizedString("filterOrderListViewModel.OrderListFilter.rowTitleProduct",
                                                       value: "Product",
                                                       comment: "Row title for filtering orders by Product.")
    }
}
