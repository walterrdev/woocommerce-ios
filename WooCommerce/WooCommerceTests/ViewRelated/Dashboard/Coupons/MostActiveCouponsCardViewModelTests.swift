import XCTest
import Yosemite
@testable import WooCommerce
import protocol Storage.StorageManagerType
import protocol Storage.StorageType

final class MostActiveCouponsCardViewModelTests: XCTestCase {
    private let sampleSiteID: Int64 = 134
    private var stores: MockStoresManager!
    private let sampleCouponReports: [CouponReport] = [.fake().copy(couponID: 1),
                                                       .fake().copy(couponID: 2),
                                                       .fake().copy(couponID: 3)]
    private let sampleCoupons = [Coupon.fake().copy(siteID: 134, couponID: 1),
                                 Coupon.fake().copy(siteID: 134, couponID: 2),
                                 Coupon.fake().copy(siteID: 134, couponID: 3)]

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
    func test_coupons_are_loaded_from_storage_when_available() async {
        // Given
        let viewModel = MostActiveCouponsCardViewModel(siteID: sampleSiteID,
                                                       stores: stores,
                                                       storageManager: storageManager)
        insertCoupons(sampleCoupons)

        // When
        stores.whenReceivingAction(ofType: CouponAction.self) { action in
            switch action {
            case let .loadMostActiveCoupons(_, _, _, completion):
                completion(.success(self.sampleCouponReports))
            case let .loadCoupons(_, _, completion):
                completion(.success([]))
            default:
                break
            }
        }
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.rows.map({ $0.id }), sampleCoupons.map({ $0.couponID }))
    }

    @MainActor
    func test_syncingData_is_updated_correctly_when_coupons_not_stored_locally() async {
        // Given
        let viewModel = MostActiveCouponsCardViewModel(siteID: sampleSiteID,
                                                       stores: stores,
                                                       storageManager: storageManager)
        XCTAssertFalse(viewModel.syncingData)

        // When
        stores.whenReceivingAction(ofType: CouponAction.self) { action in
            switch action {
            case let .loadMostActiveCoupons(_, _, _, completion):
                XCTAssertTrue(viewModel.syncingData)
                completion(.success(self.sampleCouponReports))
            case let .loadCoupons(_, _, completion):
                XCTAssertTrue(viewModel.syncingData)
                completion(.success(self.sampleCoupons))
            default:
                break
            }
        }
        await viewModel.reloadData()

        // Then
        XCTAssertFalse(viewModel.syncingData)
    }

    @MainActor
    func test_syncingData_is_updated_correctly_when_coupons_stored_locally() async {
        // Given
        let viewModel = MostActiveCouponsCardViewModel(siteID: sampleSiteID,
                                                       stores: stores,
                                                       storageManager: storageManager)
        insertCoupons(sampleCoupons)

        // When
        stores.whenReceivingAction(ofType: CouponAction.self) { action in
            switch action {
            case let .loadMostActiveCoupons(_, _, _, completion):
                XCTAssertTrue(viewModel.syncingData)
                completion(.success(self.sampleCouponReports))
            case let .loadCoupons(_, _, completion):
                XCTAssertFalse(viewModel.syncingData)
                completion(.success(self.sampleCoupons))
            default:
                break
            }
        }

        await viewModel.reloadData()

        // Then
        XCTAssertFalse(viewModel.syncingData)
    }

    @MainActor
    func test_syncingError_is_updated_correctly_when_loading_most_active_coupons_fails() async {
        // Given
        let viewModel = MostActiveCouponsCardViewModel(siteID: sampleSiteID, stores: stores)
        XCTAssertNil(viewModel.syncingError)
        let error = NSError(domain: "test", code: 500)

        // When
        stores.whenReceivingAction(ofType: CouponAction.self) { action in
            switch action {
            case let .loadMostActiveCoupons(_, _, _, completion):
                completion(.failure(error))
            case let .loadCoupons(_, _, completion):
                XCTAssertTrue(viewModel.syncingData)
                completion(.success([Coupon.fake()]))
            default:
                break
            }
        }
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.syncingError as? NSError, error)
    }

    @MainActor
    func test_syncingError_is_updated_correctly_when_loading_coupons_fails() async {
        // Given
        let viewModel = MostActiveCouponsCardViewModel(siteID: sampleSiteID, stores: stores)
        XCTAssertNil(viewModel.syncingError)
        let error = NSError(domain: "test", code: 500)

        // When
        stores.whenReceivingAction(ofType: CouponAction.self) { action in
            switch action {
            case let .loadMostActiveCoupons(_, _, _, completion):
                completion(.success([CouponReport.fake()]))
            case let .loadCoupons(_, _, completion):
                completion(.failure(error))
            default:
                break
            }
        }
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.syncingError as? NSError, error)
    }
}

extension MostActiveCouponsCardViewModelTests {
    func insertCoupons(_ readOnlyCoupons: [Coupon]) {
        readOnlyCoupons.forEach { coupon in
            let newCoupon = storage.insertNewObject(ofType: StorageCoupon.self)
            newCoupon.update(with: coupon)
        }
        storage.saveIfNeeded()
    }
}
