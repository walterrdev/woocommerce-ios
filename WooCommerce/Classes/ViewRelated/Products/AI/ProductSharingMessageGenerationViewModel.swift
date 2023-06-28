import Foundation
import Yosemite

/// View model for `ProductSharingMessageGenerationView`
final class ProductSharingMessageGenerationViewModel: ObservableObject {
    @Published var isSharePopoverPresented = false
    @Published var isShareSheetPresented = false

    /// Whether feedback banner for the generated text should be displayed.
    @Published var shouldShowFeedbackView = false

    let viewTitle: String

    var generateButtonTitle: String {
        hasGeneratedMessage ? Localization.regenerate : Localization.generate
    }

    var generateButtonImage: UIImage {
        hasGeneratedMessage ? UIImage(systemName: "arrow.counterclockwise")! : .sparklesImage
    }

    var shareSheet: ShareSheet {
        let activityItems: [Any]
        if let url = URL(string: url) {
            activityItems = [messageContent, url]
        } else {
            activityItems = [messageContent]
        }
        return ShareSheet(activityItems: activityItems)
    }

    @Published var messageContent: String = ""
    @Published private(set) var generationInProgress: Bool = false
    @Published private(set) var errorMessage: String?

    private let siteID: Int64
    private let url: String
    private let productName: String
    private let productDescription: String
    private let stores: StoresManager
    private let isPad: Bool
    private let analytics: Analytics

    /// Whether a message has been successfully generated.
    /// This is needed to identify whether the next request is a retry.
    private var hasGeneratedMessage = false

    init(siteID: Int64,
         url: String,
         productName: String,
         productDescription: String,
         isPad: Bool = UIDevice.isPad(),
         stores: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics) {
        self.siteID = siteID
        self.url = url
        self.productName = productName
        self.productDescription = productDescription
        self.isPad = isPad
        self.stores = stores
        self.analytics = analytics
        self.viewTitle = String.localizedStringWithFormat(Localization.title, productName)
    }

    @MainActor
    func generateShareMessage() async {
        shouldShowFeedbackView = false
        analytics.track(event: .ProductSharingAI.generateButtonTapped(isRetry: hasGeneratedMessage))
        errorMessage = nil
        generationInProgress = true
        do {
            messageContent = try await requestMessageFromAI()
            hasGeneratedMessage = true
            analytics.track(event: .ProductSharingAI.messageGenerated())
            shouldShowFeedbackView = true
        } catch {
            DDLogError("⛔️ Error generating product sharing message: \(error)")
            errorMessage = error.localizedDescription
            analytics.track(event: .ProductSharingAI.messageGenerationFailed(error: error))
        }
        generationInProgress = false
    }

    func didTapShare() {
        if isPad {
            isSharePopoverPresented = true
        } else {
            isShareSheetPresented = true
        }
        analytics.track(event: .ProductSharingAI.shareButtonTapped(withMessage: messageContent.isNotEmpty))
    }

    /// Handles when a feedback is sent.
    func handleFeedback(_ vote: FeedbackView.Vote) {
        // TODO: analytics?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.shouldShowFeedbackView = false
        }
    }
}

private extension ProductSharingMessageGenerationViewModel {
    @MainActor
    func requestMessageFromAI() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            stores.dispatch(ProductAction.generateProductSharingMessage(siteID: siteID,
                                                                        url: url,
                                                                        name: productName,
                                                                        description: productDescription,
                                                                        completion: { result in
                continuation.resume(with: result)
            }))
        }
    }
}

extension ProductSharingMessageGenerationViewModel {
    enum Localization {
        static let title = NSLocalizedString(
            "Share %1$@",
            comment: "Title of the product sharing message generation screen. " +
            "The placeholder is the name of the product"
        )
        static let generate = NSLocalizedString(
            "Write with AI",
            comment: "Action button to generate message on the product sharing message generation screen"
        )
        static let regenerate = NSLocalizedString(
            "Regenerate",
            comment: "Action button to regenerate message on the product sharing message generation screen"
        )
    }
}
