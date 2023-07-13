import Combine
import SwiftUI
import Vision
import Yosemite

/// View model for `AddProductFromImageView` to handle user actions from the view and provide data for the view.
@MainActor
final class AddProductFromImageViewModel: ObservableObject {
    /// View model for `AddProductFromImageScannedTextView`.
    final class ScannedTextViewModel: ObservableObject, Identifiable {
        let id: String = UUID().uuidString
        @Published var text: String
        @Published var isSelected: Bool

        init(text: String, isSelected: Bool) {
            self.text = text
            self.isSelected = isSelected
        }
    }

    typealias TextFieldViewModel = AddProductFromImageTextFieldView.ViewModel
    typealias ImageState = EditableImageViewState

    // MARK: - Product Details

    let nameViewModel: TextFieldViewModel
    let descriptionViewModel: TextFieldViewModel

    var name: String {
        nameViewModel.text
    }
    var description: String {
        descriptionViewModel.text
    }

    // MARK: - Product Image

    @Published private(set) var imageState: ImageState = .empty
    var image: MediaPickerImage? {
        imageState.image
    }

    private let onAddImage: (MediaPickingSource) async -> MediaPickerImage?
    private var selectedImageSubscription: AnyCancellable?

    // MARK: - Scanned Texts

    @Published var scannedTexts: [ScannedTextViewModel] = []
    @Published private(set) var isGeneratingDetails: Bool = false

    private var selectedScannedTexts: [String] {
        scannedTexts.filter { $0.isSelected && $0.text.isNotEmpty }.map { $0.text }
    }

    private let siteID: Int64
    private let stores: StoresManager

    init(siteID: Int64,
         stores: StoresManager = ServiceLocator.stores,
         onAddImage: @escaping (MediaPickingSource) async -> MediaPickerImage?) {
        self.siteID = siteID
        self.stores = stores
        self.onAddImage = onAddImage
        self.nameViewModel = .init(text: "", placeholder: Localization.nameFieldPlaceholder)
        self.descriptionViewModel = .init(text: "", placeholder: Localization.descriptionFieldPlaceholder)

        selectedImageSubscription = $imageState.compactMap { $0.image?.image }
        .sink { [weak self] image in
            self?.onSelectedImage(image)
        }
    }

    /// Invoked after the user selects a media source to add an image.
    /// - Parameter source: Source of the image.
    func addImage(from source: MediaPickingSource) {
        let previousState = imageState
        imageState = .loading
        Task { @MainActor in
            guard let image = await onAddImage(source) else {
                return imageState = previousState
            }
            imageState = .success(image)
        }
    }

    /// Generates product details with the currently selected scanned texts.
    func generateProductDetails() {
        Task { @MainActor in
            isGeneratingDetails = true
            await generateAndPopulateProductDetails(from: Array(selectedScannedTexts))
            isGeneratingDetails = false
        }
    }
}

private extension AddProductFromImageViewModel {
    func onSelectedImage(_ image: UIImage) {
        // Gets the CGImage on which to perform requests.
        guard let cgImage = image.cgImage else {
            return
        }

        // Creates a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)

        // Creates a new request to recognize text.
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.onScannedTextRequestCompletion(request: request, error: error)
        }

        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
            request.automaticallyDetectsLanguage = true
        }

        do {
            // Performs the text-recognition request.
            try requestHandler.perform([request])
        } catch {
            DDLogError("⛔️ Unable to perform image text generation request: \(error)")
        }
    }

    func onScannedTextRequestCompletion(request: VNRequest, error: Error?) {
        let texts = scannedTexts(from: request)
        scannedTexts = texts.map { .init(text: $0, isSelected: true) }
        Task { @MainActor in
            isGeneratingDetails = true
            await generateAndPopulateProductDetails(from: texts)
            isGeneratingDetails = false
        }
    }

    func scannedTexts(from request: VNRequest) -> [String] {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return []
        }
        let recognizedStrings = observations.compactMap { observation in
            // Returns the string of the top VNRecognizedText instance.
            observation.topCandidates(1).first?.string
        }
        return recognizedStrings
    }

    func generateAndPopulateProductDetails(from scannedTexts: [String]) async {
        switch await generateProductDetails(from: scannedTexts) {
            case .success(let details):
                nameViewModel.onSuggestion(details.name)
                descriptionViewModel.onSuggestion(details.description)
            case .failure(let error):
                DDLogError("⛔️ Error generating product details from scanned text: \(error)")
        }
    }

    func generateProductDetails(from scannedTexts: [String]) async -> Result<ProductDetailsFromScannedTexts, Error> {
        await withCheckedContinuation { continuation in
            stores.dispatch(ProductAction.generateProductDetails(siteID: siteID,
                                                                 scannedTexts: scannedTexts) { result in
                continuation.resume(returning: result)
            })
        }
    }
}

private extension AddProductFromImageViewModel {
    enum Localization {
        static let nameFieldPlaceholder = NSLocalizedString(
            "Name",
            comment: "Product name placeholder on the add product from image form."
        )
        static let descriptionFieldPlaceholder = NSLocalizedString(
            "Description",
            comment: "Product description placeholder on the add product from image form."
        )
    }
}
