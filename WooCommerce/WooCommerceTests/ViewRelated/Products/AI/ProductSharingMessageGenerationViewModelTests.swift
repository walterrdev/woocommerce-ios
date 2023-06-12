import XCTest
@testable import WooCommerce
@testable import Yosemite

@MainActor
final class ProductSharingMessageGenerationViewModelTests: XCTestCase {

    private var analyticsProvider: MockAnalyticsProvider!
    private var analytics: WooAnalytics!

    override func setUp() {
        super.setUp()

        analyticsProvider = MockAnalyticsProvider()
        analytics = WooAnalytics(analyticsProvider: analyticsProvider)
    }

    override func tearDown() {
        analytics = nil
        analyticsProvider = nil
        super.tearDown()
    }

    func test_viewTitle_is_correct() {
        // Given
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description")
        let expectedTitle = String.localizedStringWithFormat(ProductSharingMessageGenerationViewModel.Localization.title, "Test")

        // Then
        assertEqual(expectedTitle, viewModel.viewTitle)
    }

    func test_generateShareMessage_updates_generationInProgress_correctly() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description")
        XCTAssertFalse(viewModel.generationInProgress)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                XCTAssertTrue(viewModel.generationInProgress)
                completion(.success("Check this out!"))
            default:
                return
            }
        }

        // When
        await viewModel.generateShareMessage()

        // Then
        XCTAssertFalse(viewModel.generationInProgress)
    }

    func test_generateShareMessage_updates_messageContent_upon_success() async {
        // Given
        let expectedString = "Check out this product!"
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 stores: stores)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                completion(.success(expectedString))
            default:
                return
            }
        }
        assertEqual("", viewModel.messageContent)

        // When
        await viewModel.generateShareMessage()

        // Then
        assertEqual(expectedString, viewModel.messageContent)
    }

    func test_generateShareMessage_updates_errorMessage_on_failure() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 stores: stores)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 500)))
            default:
                return
            }
        }
        XCTAssertNil(viewModel.errorMessage)

        // When
        await viewModel.generateShareMessage()

        // Then
        assertEqual(ProductSharingMessageGenerationViewModel.Localization.errorMessage, viewModel.errorMessage)
    }

    // MARK: - Analytics
    func test_generate_button_tapped_is_tracked_correctly() async throws {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 stores: stores,
                                                                 analytics: analytics)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                completion(.success("Test"))
            default:
                return
            }
        }

        // When
        await viewModel.generateShareMessage()

        // Then
        XCTAssertEqual(analyticsProvider.receivedEvents, ["product_sharing_ai_generate_tapped", "product_sharing_ai_message_generated"])
        let firstEventIndex = try XCTUnwrap(analyticsProvider.receivedEvents.firstIndex(where: { $0 == "product_sharing_ai_generate_tapped"}))
        let firstEventProperties = analyticsProvider.receivedProperties[firstEventIndex]
        XCTAssertEqual(firstEventProperties["is_retry"] as? Bool, false)

        // When
        await viewModel.generateShareMessage() // retry

        // Then
        XCTAssertEqual(analyticsProvider.receivedEvents, [
            "product_sharing_ai_generate_tapped",
            "product_sharing_ai_message_generated",
            "product_sharing_ai_generate_tapped",
            "product_sharing_ai_message_generated"
        ])
        let retryEventIndex = try XCTUnwrap(analyticsProvider.receivedEvents.lastIndex(where: { $0 == "product_sharing_ai_generate_tapped"}))
        let retryEventProperties = analyticsProvider.receivedProperties[retryEventIndex]
        XCTAssertEqual(retryEventProperties["is_retry"] as? Bool, true)
    }

    func test_generation_failure_event_is_tracked() async throws {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 stores: stores,
                                                                 analytics: analytics)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 500)))
            default:
                return
            }
        }

        // When
        await viewModel.generateShareMessage()

        // Then
        XCTAssertEqual(analyticsProvider.receivedEvents, ["product_sharing_ai_generate_tapped", "product_sharing_ai_message_generation_failed"])
        let failureEventIndex = try XCTUnwrap(analyticsProvider.receivedEvents.lastIndex(where: { $0 == "product_sharing_ai_message_generation_failed"}))
        let failureEventProperties = analyticsProvider.receivedProperties[failureEventIndex]
        XCTAssertEqual(failureEventProperties["error_code"] as? String, "500")
        XCTAssertEqual(failureEventProperties["error_domain"] as? String, "Test")
    }

    // MARK: `shareSheet`
    func test_shareSheet_has_expected_activityItems() async throws {
        // Given
        let expectedString = "Check out this product!"
        let expectedURLString = "https://example.com"
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: expectedURLString,
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 stores: stores)
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .generateProductSharingMessage(_, _, _, _, _, completion):
                completion(.success(expectedString))
            default:
                return
            }
        }

        // When
        await viewModel.generateShareMessage()

        // Then
        let message = try XCTUnwrap(viewModel.shareSheet.activityItems[0] as? String)
        assertEqual(expectedString, message)

        let url = try XCTUnwrap(viewModel.shareSheet.activityItems[1] as? URL)
        let expectedURL = try XCTUnwrap(URL(string: expectedURLString))
        assertEqual(expectedURL, url)
    }

    // MARK: `isSharePopoverPresented`
    func test_didTapShare_presents_popover_when_on_ipad() throws {
        // Given
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 isPad: true)
        XCTAssertFalse(viewModel.isSharePopoverPresented)

        // When
        viewModel.didTapShare()

        // Then
        XCTAssertTrue(viewModel.isSharePopoverPresented)
    }

    func test_didTapShare_does_not_present_popover_when_not_on_ipad() throws {
        // Given
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 isPad: false)
        XCTAssertFalse(viewModel.isSharePopoverPresented)

        // When
        viewModel.didTapShare()

        // Then
        XCTAssertFalse(viewModel.isSharePopoverPresented)
    }

    // MARK: `isShareSheetPresented`
    func test_didTapShare_presents_sheet_when_not_on_ipad() throws {
        // Given
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 isPad: false)
        XCTAssertFalse(viewModel.isShareSheetPresented)

        // When
        viewModel.didTapShare()

        // Then
        XCTAssertTrue(viewModel.isShareSheetPresented)
    }

    func test_didTapShare_does_not_present_sheet_when_on_ipad() throws {
        // Given
        let viewModel = ProductSharingMessageGenerationViewModel(siteID: 123,
                                                                 url: "https://example.com",
                                                                 productName: "Test",
                                                                 productDescription: "Test description",
                                                                 isPad: true)
        XCTAssertFalse(viewModel.isShareSheetPresented)

        // When
        viewModel.didTapShare()

        // Then
        XCTAssertFalse(viewModel.isShareSheetPresented)
    }
}
