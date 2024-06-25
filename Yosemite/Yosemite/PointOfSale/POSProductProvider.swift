import Foundation
import protocol Networking.Network
import class Networking.ProductsRemote
import class Networking.AlamofireNetwork
import protocol Storage.StorageManagerType
import class WooFoundation.CurrencyFormatter
import class WooFoundation.CurrencySettings

/// Product provider for the Point of Sale feature
///
public final class POSProductProvider: POSItemProvider {
    private let storageManager: StorageManagerType
    private var siteID: Int64
    private var currencySettings: CurrencySettings
    private let productsRemote: ProductsRemote

    public init(storageManager: StorageManagerType, siteID: Int64, currencySettings: CurrencySettings, network: Network) {
        self.storageManager = storageManager
        self.siteID = siteID
        self.currencySettings = currencySettings
        self.productsRemote = ProductsRemote(network: network)
    }

    public convenience init(storageManager: StorageManagerType,
                     siteID: Int64,
                     currencySettings: CurrencySettings,
                     credentials: Credentials?) {
        self.init(storageManager: storageManager,
                  siteID: siteID,
                  currencySettings: currencySettings,
                  network: AlamofireNetwork(credentials: credentials))
    }

    private lazy var productsResultsController: ResultsController<StorageProduct> = {
        let predicate = NSPredicate(format: "siteID == %lld", siteID)
        let descriptor = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        let resultsController = ResultsController<StorageProduct>(storageManager: storageManager,
                                                                  matching: predicate,
                                                                  sortedBy: [descriptor])
        return resultsController
    }()

    public func providePointOfSaleItems() async throws -> [POSItem] {
        do {
            let products = try await productsRemote.loadAllSimpleProductsForPointOfSale(for: siteID)
            return mapProductsToPOSItems(products: products)
        }
        // TODO:
        // - Handle case for empty product list, or not empty but no eligible products
        // https://github.com/woocommerce/woocommerce-ios/issues/12815
        // https://github.com/woocommerce/woocommerce-ios/issues/12816
        // - Handle case for error when fetching products
        // https://github.com/woocommerce/woocommerce-ios/issues/12846
        
    }

    // Maps result to POSProduct, and populate the output with:
    // - Formatted price based on store's currency settings.
    // - Product categories, if any.
    // - Product thumbnail, if any.
    private func mapProductsToPOSItems(products: [Product]) -> [POSItem] {
        let currencyFormatter = CurrencyFormatter(currencySettings: currencySettings)
        return products.map { product in
            let formattedPrice = currencyFormatter.formatAmount(product.price, with: currencySettings.currencyCode.rawValue) ?? "-"
            let thumbnailSource = product.images.first?.src
            let productCategories = product.categories.map { $0.name }

            return POSProduct(itemID: UUID(),
                              productID: product.productID,
                              name: product.name,
                              price: product.price,
                              formattedPrice: formattedPrice,
                              itemCategories: productCategories,
                              productImageSource: thumbnailSource,
                              productType: product.productType)
        }
    }

    // TODO: Mechanism to reload/sync product data.
    // https://github.com/woocommerce/woocommerce-ios/issues/12837
}
