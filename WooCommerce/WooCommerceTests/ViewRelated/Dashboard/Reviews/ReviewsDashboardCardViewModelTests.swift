import XCTest
import Yosemite
@testable import WooCommerce
import protocol Storage.StorageManagerType
import protocol Storage.StorageType

final class ReviewsDashboardCardViewModelTests: XCTestCase {
    private let sampleSiteID: Int64 = 1337
    private var stores: MockStoresManager!

    private let sampleReviews: [ProductReview] = [ProductReview.fake().copy(siteID: 1337, reviewID: 1),
                                 ProductReview.fake().copy(siteID: 1337, reviewID: 2),
                                 ProductReview.fake().copy(siteID: 1337, reviewID: 3)]

    /// Mock Storage: InMemory
    private var storageManager: StorageManagerType!

    /// View storage for tests
    private var storage: StorageType {
        storageManager.viewStorage
    }

    override func setUp() {
        super.setUp()
        storageManager = MockStorageManager()
        stores = MockStoresManager(sessionManager: SessionManager.makeForTesting())
    }

    override func tearDown() {
        stores = nil
        storageManager = nil
        super.tearDown()
    }

    @MainActor
    func test_reviews_are_loaded_from_storage_when_available() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        insertReviews(sampleReviews)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        let sortedExtractedReviews = viewModel.data
            .map { $0.review }
            .sorted { $0.reviewID < $1.reviewID }

        XCTAssertEqual(sortedExtractedReviews, self.sampleReviews)
    }

    @MainActor
    func test_showLoadingAnimation_is_updated_correctly_when_syncing() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertFalse(viewModel.showLoadingAnimation)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                XCTAssertTrue(viewModel.showLoadingAnimation)
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertFalse(viewModel.showLoadingAnimation)
    }

    /// If there is partial data, we want to show it right away even if partially, thus loading animation must be hidden.
    ///
    @MainActor
    func test_showLoadingAnimation_is_hidden_if_there_is_partial_data() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertFalse(viewModel.showLoadingAnimation)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                XCTAssertFalse(viewModel.showLoadingAnimation) // Loading animation should be off before syncing products
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                XCTAssertFalse(viewModel.showLoadingAnimation) // Loading animation should be off before syncing notifications
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertFalse(viewModel.showLoadingAnimation)
    }

    @MainActor
    func test_syncingError_is_updated_correctly_when_syncing_reviews_fails() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertNil(viewModel.syncingError)
        let error = NSError(domain: "test", code: 500)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                onCompletion(.failure(error))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.syncingError as? NSError, error)
    }

    @MainActor
    func test_syncingError_is_updated_correctly_when_syncing_products_fails() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertNil(viewModel.syncingError)
        let error = NSError(domain: "test", code: 500)
        insertReviews(sampleReviews)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.failure(error))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.syncingError as? NSError, error)
    }

    @MainActor
    func test_syncingError_is_updated_correctly_when_syncing_notifications_fails() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertNil(viewModel.syncingError)
        let error = NSError(domain: "test", code: 500)
        insertReviews(sampleReviews)

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(error)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.syncingError as? NSError, error)
    }

    @MainActor
    func test_switchingStatus_is_updated_correctly_during_review_filtering() async {
        // Given
        let viewModel = ReviewsDashboardCardViewModel(siteID: sampleSiteID,
                                                      stores: stores,
                                                      storageManager: storageManager)
        XCTAssertFalse(viewModel.switchingStatus)

        let newFilter = ReviewsDashboardCardViewModel.ReviewsFilter.hold

        // When
        stores.whenReceivingAction(ofType: ProductReviewAction.self) { action in
            switch action {
            case let .synchronizeProductReviews(_, _, _, _, _, onCompletion):
                XCTAssertTrue(viewModel.switchingStatus)
                onCompletion(.success(self.sampleReviews))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            switch action {
            case let .retrieveProducts(_, _, _, _, onCompletion):
                onCompletion(.success(([], true)))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        stores.whenReceivingAction(ofType: NotificationAction.self) { action in
            switch action {
            case let .synchronizeNotifications(onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        await viewModel.filterReviews(by: newFilter)

        // Then
        XCTAssertFalse(viewModel.switchingStatus)
    }
}

extension ReviewsDashboardCardViewModelTests {
    func insertReviews(_ readOnlyReviews: [ProductReview]) {
        readOnlyReviews.forEach { review in
            let newReview = storage.insertNewObject(ofType: StorageProductReview.self)
            newReview.update(with: review)
        }
        storage.saveIfNeeded()
    }
}
