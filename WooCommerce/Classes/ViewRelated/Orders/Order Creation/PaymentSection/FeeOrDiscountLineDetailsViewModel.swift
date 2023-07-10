import SwiftUI
import Yosemite
import WooFoundation

class FeeOrDiscountLineDetailsViewModel: ObservableObject {

    /// Closure to be invoked when the line is updated.
    ///
    var didSelectSave: ((String?) -> Void)

    /// Helper to format price field input.
    ///
    private let priceFieldFormatter: PriceFieldFormatter

    /// Stores the fixed amount entered by the merchant.
    ///
    @Published var amount: String = "" {
        didSet {
            guard amount != oldValue else { return }
            amount = priceFieldFormatter.formatAmount(amount)
        }
    }

    /// Stores the percentage entered by the merchant.
    ///
    @Published var percentage: String = "" {
        didSet {
            guard percentage != oldValue else { return }
            percentage = sanitizePercentageAmount(percentage)
        }
    }

    /// Decimal value of currently entered fee or discount. For percentage type it is calculated final amount.
    ///
    private var finalAmountDecimal: Decimal {
        let inputString = feeOrDiscountType == .fixed ? amount : percentage
        guard let decimalInput = currencyFormatter.convertToDecimal(inputString) else {
            return .zero
        }

        switch feeOrDiscountType {
        case .fixed:
            return decimalInput as Decimal
        case .percentage:
            return baseAmountForPercentage * (decimalInput as Decimal) * 0.01
        }
    }

    /// Formatted string value of currently entered fee or discount. For percentage type it is calculated final amount.
    ///
    var finalAmountString: String? {
        currencyFormatter.formatAmount(finalAmountDecimal)
    }

    /// The base amount to apply percentage fee or discount on.
    ///
    private let baseAmountForPercentage: Decimal

    /// The initial fee or discount amount.
    ///
    private let initialAmount: Decimal

    /// Returns true when existing line is edited.
    ///
    let isExistingLine: Bool

    /// Returns true when base amount for percentage > 0.
    ///
    var isPercentageOptionAvailable: Bool {
        !isExistingLine && baseAmountForPercentage > 0
    }

    /// Returns true when there are no valid pending changes.
    ///
    var shouldDisableDoneButton: Bool {
        guard finalAmountDecimal != .zero else {
            return true
        }

        return finalAmountDecimal == initialAmount
    }

    var navigationTitle: String {
        switch (lineType, isExistingLine) {
        case (.discount, false):
            return Localization.addDiscount
        case (.discount, true):
            return Localization.discount
        case (.fee, false):
            return Localization.addFee
        case (.fee, true):
            return Localization.fee
        }
    }

    /// Localized percent symbol.
    ///
    let percentSymbol: String

    /// Current store currency symbol.
    ///
    let currencySymbol: String

    /// Position for currency symbol, relative to amount text field.
    ///
    let currencyPosition: CurrencySettings.CurrencyPosition

    /// Currency formatter setup with store settings.
    ///
    private let currencyFormatter: CurrencyFormatter

    private let minusSign: String = NumberFormatter().minusSign

    /// Placeholder for amount text field.
    ///
    let amountPlaceholder: String

    enum LineType {
        case fee
        case discount
    }

    private let lineType: LineType

    enum FeeOrDiscountType {
        case fixed
        case percentage
    }

    @Published var feeOrDiscountType: FeeOrDiscountType = .fixed

    init(isExistingLine: Bool,
         baseAmountForPercentage: Decimal,
         total: String,
         lineType: LineType,
         locale: Locale = Locale.autoupdatingCurrent,
         storeCurrencySettings: CurrencySettings = ServiceLocator.currencySettings,
         didSelectSave: @escaping ((String?) -> Void)) {
        self.priceFieldFormatter = .init(locale: locale, storeCurrencySettings: storeCurrencySettings, allowNegativeNumber: true)
        self.percentSymbol = NumberFormatter().percentSymbol
        self.currencySymbol = storeCurrencySettings.symbol(from: storeCurrencySettings.currencyCode)
        self.currencyPosition = storeCurrencySettings.currencyPosition
        self.currencyFormatter = CurrencyFormatter(currencySettings: storeCurrencySettings)
        self.amountPlaceholder = priceFieldFormatter.formatAmount("0")

        self.isExistingLine = isExistingLine
        self.baseAmountForPercentage = baseAmountForPercentage

        if let initialAmount = currencyFormatter.convertToDecimal(total) {
            self.initialAmount = initialAmount as Decimal
        } else {
            self.initialAmount = .zero
        }

        if initialAmount != 0, let formattedInputAmount = currencyFormatter.formatAmount(initialAmount) {
            self.amount = priceFieldFormatter.formatAmount(formattedInputAmount)
            self.percentage = priceFieldFormatter.formatAmount("\(initialAmount / baseAmountForPercentage * 100)")
        }

        self.didSelectSave = didSelectSave
        self.lineType = lineType
    }

    func saveData() {
        guard let finalAmountString = finalAmountString else {
            return
        }

        didSelectSave(priceFieldFormatter.formatAmount(finalAmountString))
    }
}

private extension FeeOrDiscountLineDetailsViewModel {

    /// Formats a received value by sanitizing the input and trimming content to two decimal places.
    ///
    func sanitizePercentageAmount(_ amount: String) -> String {
        let deviceDecimalSeparator = Locale.autoupdatingCurrent.decimalSeparator ?? "."
        let numberOfDecimals = 2

        let negativePrefix = amount.hasPrefix(minusSign) ? minusSign : ""

        let sanitized = amount
            .filter { $0.isNumber || "\($0)" == deviceDecimalSeparator }

        // Trim to two decimals & remove any extra "."
        let components = sanitized.components(separatedBy: deviceDecimalSeparator)
        switch components.count {
        case 1 where sanitized.contains(deviceDecimalSeparator):
            return negativePrefix + components[0] + deviceDecimalSeparator
        case 1:
            return negativePrefix + components[0]
        case 2...Int.max:
            let number = components[0]
            let decimals = components[1]
            let trimmedDecimals = decimals.prefix(numberOfDecimals)
            return negativePrefix + number + deviceDecimalSeparator + trimmedDecimals
        default:
            fatalError("Should not happen, components can't be 0 or negative")
        }
    }
}

private extension FeeOrDiscountLineDetailsViewModel {
    enum Localization {
        static let addFee = NSLocalizedString("Add Fee", comment: "Title for the Fee screen during order creation")
        static let fee = NSLocalizedString("Fee", comment: "Title for the Fee Details screen during order creation")
        static let addDiscount = NSLocalizedString("Add Discount", comment: "Title for the Discount screen during order creation")
        static let discount = NSLocalizedString("Discount", comment: "Title for the Discount Details screen during order creation")
    }
}
