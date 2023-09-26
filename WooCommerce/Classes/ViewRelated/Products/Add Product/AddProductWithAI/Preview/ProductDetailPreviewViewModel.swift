import Combine
import Foundation
import Photos
import Yosemite
import WooFoundation

/// View model for `ProductDetailPreviewView`
///
final class ProductDetailPreviewViewModel: ObservableObject {

    @Published private(set) var isGeneratingDetails: Bool = false
    @Published private(set) var isSavingProduct: Bool = false
    @Published private var generatedProduct: Product?

    @Published private(set) var productName: String
    @Published private(set) var productDescription: String?
    @Published private(set) var productType: String?
    @Published private(set) var productPrice: String?
    @Published private(set) var productCategories: String?
    @Published private(set) var productTags: String?
    @Published private(set) var productShippingDetails: String?

    private let productFeatures: String?
    private let packagingImage: MediaPickerImage?

    private let siteID: Int64
    private let stores: StoresManager
    private let analytics: Analytics
    private let onProductCreated: (Product) -> Void

    private let currency: String
    private let currencyFormatter: CurrencyFormatter

    private let weightUnit: String?
    private let dimensionUnit: String?
    private let shippingValueLocalizer: ShippingValueLocalizer
    private let productImageUploader: ProductImageUploaderProtocol

    private var generatedProductSubscription: AnyCancellable?

    /// Local ID used for background image upload
    private let localProductID: Int64 = 0
    private var createdProductID: Int64?

    init(siteID: Int64,
         productName: String,
         productDescription: String?,
         productFeatures: String?,
         packagingImage: MediaPickerImage? = nil,
         currency: String = ServiceLocator.currencySettings.symbol(from: ServiceLocator.currencySettings.currencyCode),
         currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings),
         weightUnit: String? = ServiceLocator.shippingSettingsService.weightUnit,
         dimensionUnit: String? = ServiceLocator.shippingSettingsService.dimensionUnit,
         shippingValueLocalizer: ShippingValueLocalizer = DefaultShippingValueLocalizer(),
         productImageUploader: ProductImageUploaderProtocol = ServiceLocator.productImageUploader,
         stores: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics,
         onProductCreated: @escaping (Product) -> Void) {
        self.siteID = siteID
        self.stores = stores
        self.analytics = analytics
        self.onProductCreated = onProductCreated

        self.currency = currency
        self.currencyFormatter = currencyFormatter

        self.weightUnit = weightUnit
        self.dimensionUnit = dimensionUnit
        self.shippingValueLocalizer = shippingValueLocalizer

        self.productName = productName
        self.productDescription = productDescription
        self.productFeatures = productFeatures
        self.packagingImage = packagingImage
        self.productImageUploader = productImageUploader

        observeGeneratedProduct()
    }

    func onDisappear() {
        let id: ProductOrVariationID = .product(id: createdProductID ?? localProductID)
        productImageUploader.startEmittingErrors(key: .init(siteID: siteID,
                                                            productOrVariationID: id,
                                                            isLocalID: createdProductID == nil))
    }

    @MainActor
    func generateProductDetails() async {
        // TODO - update this with actual implementation
        isGeneratingDetails = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        #if canImport(SwiftUI) && DEBUG
        generatedProduct = Product.swiftUIPreviewSample().copy(siteID: siteID, productID: 0, name: productName)
        #endif
        isGeneratingDetails = false
    }

    @MainActor
    func saveProductAsDraft() async {
        guard let generatedProduct else {
            return
        }
        isSavingProduct = true
        uploadPackagingImageIfNeeded()
        do {
            let newProduct = try await saveProductRemotely(product: generatedProduct)
            createdProductID = newProduct.productID
            guard packagingImage != nil else {
                return onProductCreated(newProduct)
            }

            /// Updates local product with images
            replaceProductID(newID: newProduct.productID)
            let images = await updateProductWithUploadedImages(productID: newProduct.productID)
            let updatedProduct = newProduct.copy(images: images)
            onProductCreated(updatedProduct)
        } catch {
            // TODO: error handling
            DDLogError("⛔️ Error saving product with AI: \(error)")
        }
        isSavingProduct = false
    }

    func handleFeedback(_ vote: FeedbackView.Vote) {
        // TODO
    }
}

// MARK: - Product details for preview
//
private extension ProductDetailPreviewViewModel {
    func observeGeneratedProduct() {
        generatedProductSubscription = $generatedProduct
            .compactMap { $0 }
            .sink { [weak self] product in
                guard let self else { return }
                self.updateProductDetails(with: product)
            }
    }

    func updateProductDetails(with product: Product) {
        productName = product.name
        productDescription = product.fullDescription ?? product.shortDescription ?? self.productDescription
        productType = product.virtual ? Localization.virtualProductType : Localization.physicalProductType

        if let regularPrice = product.regularPrice, regularPrice.isNotEmpty {
            let formattedRegularPrice = currencyFormatter.formatAmount(regularPrice, with: currency) ?? ""
            productPrice = String.localizedStringWithFormat(Localization.regularPriceFormat, formattedRegularPrice)
        }

        productCategories = product.categoriesDescription()
        productTags = product.tagsDescription()
        updateShippingDetails(for: product)
    }

    func updateShippingDetails(for product: Product) {
        var shippingDetails = [String]()

        // Weight[unit]
        if let weight = product.weight, let weightUnit = weightUnit, !weight.isEmpty {
            let localizedWeight = shippingValueLocalizer.localized(shippingValue: weight) ?? weight
            shippingDetails.append(String.localizedStringWithFormat(Localization.weightFormat,
                                                                    localizedWeight, weightUnit))
        }

        // L x W x H[unit]
        let length = product.dimensions.length
        let width = product.dimensions.width
        let height = product.dimensions.height
        let dimensions = [length, width, height]
            .map({ shippingValueLocalizer.localized(shippingValue: $0) ?? $0 })
            .filter({ !$0.isEmpty })

        if let dimensionUnit = dimensionUnit,
           !dimensions.isEmpty {
            switch dimensions.count {
            case 1:
                let dimension = dimensions[0]
                shippingDetails.append(String.localizedStringWithFormat(Localization.oneDimensionFormat,
                                                                        dimension, dimensionUnit))
            case 2:
                let firstDimension = dimensions[0]
                let secondDimension = dimensions[1]
                shippingDetails.append(String.localizedStringWithFormat(Localization.twoDimensionsFormat,
                                                                        firstDimension, secondDimension, dimensionUnit))
            case 3:
                let firstDimension = dimensions[0]
                let secondDimension = dimensions[1]
                let thirdDimension = dimensions[2]
                shippingDetails.append(String.localizedStringWithFormat(Localization.fullDimensionsFormat,
                                                                        firstDimension, secondDimension, thirdDimension, dimensionUnit))
            default:
                break
            }
        }

        productShippingDetails = shippingDetails.isEmpty ? nil: shippingDetails.joined(separator: "\n")
    }
}

// MARK: - Uploading image and saving product
//
private extension ProductDetailPreviewViewModel {
    /// Sets up image uploader to upload packaging image if it's available.
    ///
    func uploadPackagingImageIfNeeded() {
        guard let packagingImage else {
            return
        }
        let productImageActionHandler = productImageUploader
            .actionHandler(key: .init(siteID: siteID,
                                      productOrVariationID: .product(id: localProductID),
                                      isLocalID: true),
                           originalStatuses: [])
        switch packagingImage.source {
        case let .asset(asset):
            productImageActionHandler.uploadMediaAssetToSiteMediaLibrary(asset: .phAsset(asset: asset))
        case let .media(media):
            productImageActionHandler.addSiteMediaLibraryImagesToProduct(mediaItems: [media])
        }
        productImageUploader.stopEmittingErrors(key: .init(siteID: siteID, productOrVariationID: .product(id: localProductID), isLocalID: true))
    }

    /// Saves the provided product remotely.
    ///
    @MainActor
    func saveProductRemotely(product: Product) async throws -> Product {
        try await withCheckedThrowingContinuation { continuation in
            let updateProductAction = ProductAction.addProduct(product: product) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let product):
                    continuation.resume(returning: product)
                }
            }
            stores.dispatch(updateProductAction)
        }
    }

    /// Replaces the actual product ID for pending images for background upload.
    ///
    func replaceProductID(newID: Int64) {
        productImageUploader.replaceLocalID(siteID: siteID,
                                            localID: .product(id: localProductID),
                                            remoteID: newID)
    }

    /// Updates the product with provided ID with uploaded images.
    /// Returns all the uploaded images.
    ///
    @MainActor
    func updateProductWithUploadedImages(productID: Int64) async -> [ProductImage] {
        await withCheckedContinuation { continuation in
            let key: ProductImageUploaderKey = .init(siteID: siteID,
                                                     productOrVariationID: .product(id: productID),
                                                     isLocalID: false)
            productImageUploader
                .saveProductImagesWhenNoneIsPendingUploadAnymore(key: key) { result in
                    switch result {
                    case .success(let images):
                        continuation.resume(returning: images)
                    case .failure(let error):
                        DDLogError("⛔️ Error saving images for new product: \(error)")
                    }
                }
        }
    }
}

private extension ProductDetailPreviewViewModel {
    enum Localization {
        static let virtualProductType = NSLocalizedString("Virtual", comment: "Display label for simple virtual product type.")
        static let physicalProductType = NSLocalizedString("Physical", comment: "Display label for simple physical product type.")
        static let regularPriceFormat = NSLocalizedString("Regular price: %@", comment: "Format of the regular price on the Price Settings row")

        // Shipping
        static let weightFormat = NSLocalizedString("Weight: %1$@%2$@",
                                                    comment: "Format of the weight on the Shipping Settings row - weight[unit]")
        static let oneDimensionFormat = NSLocalizedString("Dimensions: %1$@%2$@",
                                                          comment: "Format of one dimension on the Shipping Settings row - dimension[unit]")
        static let twoDimensionsFormat = NSLocalizedString("Dimensions: %1$@ x %2$@ %3$@",
                                                           comment: "Format of 2 dimensions on the Shipping Settings row - dimension x dimension[unit]")
        static let fullDimensionsFormat = NSLocalizedString("Dimensions: %1$@ x %2$@ x %3$@ %4$@",
                                                            comment: "Format of all 3 dimensions on the Shipping Settings row - L x W x H[unit]")
    }
}
