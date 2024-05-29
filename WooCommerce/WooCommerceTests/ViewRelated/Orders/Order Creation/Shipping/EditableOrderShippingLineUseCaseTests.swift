import XCTest
import WooFoundation
import Yosemite
@testable import WooCommerce

final class EditableOrderShippingLineUseCaseTests: XCTestCase {
    var useCase: EditableOrderShippingLineUseCase!
    var stores: MockStoresManager!
    var storageManager: MockStorageManager!
    var analytics: MockAnalyticsProvider!
    var orderSynchronizer: RemoteOrderSynchronizer!

    let sampleSiteID: Int64 = 123
    let sampleOrderID: Int64 = 1234
    let sampleProductID: Int64 = 5
    let currencySettings = CurrencySettings()

    override func setUp() {
        super.setUp()
        stores = MockStoresManager(sessionManager: .testingInstance)
        storageManager = MockStorageManager()
        analytics = MockAnalyticsProvider()
        orderSynchronizer = RemoteOrderSynchronizer(siteID: sampleSiteID, flow: .creation, stores: stores, currencySettings: currencySettings)
        useCase = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                                   flow: .creation,
                                                   orderSynchronizer: orderSynchronizer,
                                                   analytics: WooAnalytics(analyticsProvider: analytics),
                                                   storageManager: storageManager,
                                                   stores: stores,
                                                   currencySettings: currencySettings,
                                                   featureFlagService: MockFeatureFlagService(isMultipleShippingLinesEnabled: true))
    }

    // MARK: Initialization

    func test_init_syncs_available_shipping_methods() {
        // Given
        var shippingMethodsSynced = false
        stores.whenReceivingAction(ofType: ShippingMethodAction.self) { action in
            switch action {
            case let .synchronizeShippingMethods(_, completion):
                shippingMethodsSynced = true
                completion(.success(()))
            }
        }

        // When
        _ = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                             flow: .creation,
                                             orderSynchronizer: orderSynchronizer,
                                             stores: stores)

        // Then
        XCTAssertTrue(shippingMethodsSynced)
    }

    func test_use_case_inits_with_expected_shipping_line_row_from_order_shipping_line_and_stored_shipping_method() throws {
        // Given
        let shippingMethod = ShippingMethod(siteID: sampleSiteID, methodID: "flat_rate", title: "Flat Rate")
        storageManager.insert(shippingMethod)
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Package 1", methodID: "flat_rate")
        let order = Order.fake().copy(siteID: sampleSiteID, shippingLines: [shippingLine])

        // When
        let useCase = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                                       flow: .editing(initialOrder: order),
                                                       orderSynchronizer: RemoteOrderSynchronizer(siteID: sampleSiteID,
                                                                                                  flow: .editing(initialOrder: order),
                                                                                                  stores: stores),
                                                       storageManager: storageManager,
                                                       featureFlagService: MockFeatureFlagService(isMultipleShippingLinesEnabled: true))

        // Then
        assertEqual(1, useCase.shippingLineRows.count)
        let shippingLineRow = try XCTUnwrap(useCase.shippingLineRows.first)
        assertEqual(shippingLine.methodTitle, shippingLineRow.shippingTitle)
        assertEqual(shippingMethod.title, shippingLineRow.shippingMethod)
    }

    // MARK: Payment data

    func test_payment_data_is_initialized_with_expected_values() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)

        // When
        let paymentData = EditableOrderShippingLineUseCase.ShippingPaymentData(shippingTotal: "3.00",
                                                                               shippingTax: "0.30",
                                                                               currencyFormatter: CurrencyFormatter(currencySettings: currencySettings))

        // Then
        XCTAssertEqual(paymentData.shippingTotal, "£3.00")
        XCTAssertEqual(paymentData.shippingTax, "£0.30")
        XCTAssertTrue(paymentData.shouldShowShippingTax)
    }

    func test_payment_data_is_initialized_with_expected_default_values_for_new_order() {
        // Given
        let paymentData = useCase.paymentData

        // Then
        XCTAssertEqual(paymentData.shippingTotal, "$0.00")
        XCTAssertEqual(paymentData.shippingTax, "$0.00")
        XCTAssertFalse(paymentData.shouldShowShippingTax)
    }

    func test_payment_data_is_updated_when_shipping_line_updated() throws {
        // When
        let shippingLine = ShippingLine(shippingID: 0,
                                        methodTitle: "Flat Rate",
                                        methodID: "other",
                                        total: "10",
                                        totalTax: "",
                                        taxes: [])
        useCase.saveShippingLine(shippingLine)

        // Then
        XCTAssertTrue(useCase.paymentData.shouldShowShippingTotal)
        XCTAssertEqual(useCase.paymentData.shippingTotal, "$10.00")

        // When
        useCase.saveShippingLine(nil)

        // Then
        XCTAssertFalse(useCase.paymentData.shouldShowShippingTotal)
        XCTAssertEqual(useCase.paymentData.shippingTotal, "$0.00")
    }

    func test_payment_data_values_correct_when_shipping_line_is_negative() throws {
        // When
        let shippingLine = ShippingLine(shippingID: 0,
                                        methodTitle: "Flat Rate",
                                        methodID: "other",
                                        total: "-5",
                                        totalTax: "",
                                        taxes: [])
        useCase.saveShippingLine(shippingLine)

        // Then
        XCTAssertTrue(useCase.paymentData.shouldShowShippingTotal)
        XCTAssertEqual(useCase.paymentData.shippingTotal, "-$5.00")

        // When
        useCase.saveShippingLine(nil)

        // Then
        XCTAssertFalse(useCase.paymentData.shouldShowShippingTotal)
        XCTAssertEqual(useCase.paymentData.shippingTotal, "$0.00")
    }

    // MARK: Add shipping line

    func test_addShippingLineViewModel_returns_view_model_for_new_shipping_line() {
        // When
        let newShippingLineViewModel = useCase.addShippingLineViewModel()

        // Then
        XCTAssertFalse(newShippingLineViewModel.isExistingShippingLine)
    }

    // MARK: Shipping line rows

    func test_saveShippingLine_updates_shipping_line_rows() {
        // Given
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")

        // When
        useCase.saveShippingLine(shippingLine)

        // Then
        assertEqual(1, useCase.shippingLineRows.count)
        assertEqual(shippingLine.methodTitle, useCase.shippingLineRows.first?.shippingTitle)
    }

    func test_selectedShippingLine_set_when_shipping_line_row_is_edited() {
        // Given
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")
        let order = Order.fake().copy(siteID: sampleSiteID, shippingLines: [shippingLine])
        let useCase = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                                       flow: .editing(initialOrder: order),
                                                       orderSynchronizer: RemoteOrderSynchronizer(siteID: sampleSiteID,
                                                                                                  flow: .editing(initialOrder: order),
                                                                                                  stores: stores),
                                                       featureFlagService: MockFeatureFlagService(isMultipleShippingLinesEnabled: true))

        // When
        useCase.shippingLineRows.first?.editShippingLine()

        // Then
        assertEqual(shippingLine.methodTitle, useCase.selectedShippingLine?.methodTitle)
    }

    func test_shipping_line_row_is_editable_for_new_order() throws {
        // Given
        XCTAssertFalse(useCase.shouldShowNonEditableIndicators)
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")

        // When
        useCase.saveShippingLine(shippingLine)

        // Then
        let shippingLineRow = try XCTUnwrap(useCase.shippingLineRows.first)
        XCTAssertTrue(shippingLineRow.editable)
    }

    func test_shipping_line_row_is_not_editable_for_a_non_editable_order() throws {
        // Given
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")
        let order = Order.fake().copy(siteID: sampleSiteID, isEditable: false, shippingLines: [shippingLine])

        // When
        let useCase = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                                       flow: .editing(initialOrder: order),
                                                       orderSynchronizer: RemoteOrderSynchronizer(siteID: sampleSiteID,
                                                                                                  flow: .editing(initialOrder: order),
                                                                                                  stores: stores))

        // Then
        let shippingLineRow = try XCTUnwrap(useCase.shippingLineRows.first)
        XCTAssertFalse(shippingLineRow.editable)
    }

    func test_shipping_line_row_is_editable_for_an_editable_order() throws {
        // Given
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")
        let order = Order.fake().copy(siteID: sampleSiteID, isEditable: true, shippingLines: [shippingLine])

        // When
        let useCase = EditableOrderShippingLineUseCase(siteID: sampleSiteID,
                                                       flow: .editing(initialOrder: order),
                                                       orderSynchronizer: RemoteOrderSynchronizer(siteID: sampleSiteID,
                                                                                                  flow: .editing(initialOrder: order),
                                                                                                  stores: stores))

        // Then
        let shippingLineRow = try XCTUnwrap(useCase.shippingLineRows.first)
        XCTAssertTrue(shippingLineRow.editable)
    }

    func test_shipping_line_row_is_not_editable_for_order() throws {
        // Given
        XCTAssertFalse(useCase.shouldShowNonEditableIndicators)
        let shippingLine = ShippingLine.fake().copy(methodTitle: "Flat Rate")

        // When
        useCase.saveShippingLine(shippingLine)

        // Then
        let shippingLineRow = try XCTUnwrap(useCase.shippingLineRows.first)
        XCTAssertTrue(shippingLineRow.editable)
    }

    // MARK: Analytics

    func test_trackAddShippingTapped_tracks_expected_event() {
        // When
        useCase.trackAddShippingTapped()

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderAddShippingTapped.rawValue])
    }

    func test_shipping_method_tracked_when_added() throws {
        // Given
        let shippingLine = ShippingLine.fake().copy(methodID: "flat_rate")

        // When
        useCase.saveShippingLine(shippingLine)

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderShippingMethodAdd.rawValue])
        assertEqual("creation", analytics.receivedProperties.first?["flow"] as? String)
        assertEqual("flat_rate", analytics.receivedProperties.first?["shipping_method"] as? String)
    }

    func test_shipping_method_tracked_when_removed() throws {
        // When
        useCase.saveShippingLine(nil)

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderShippingMethodRemove.rawValue])

        let properties = try XCTUnwrap(analytics.receivedProperties.first?["flow"] as? String)
        XCTAssertEqual(properties, "creation")
    }
}

private extension MockStorageManager {
    func insert(_ readOnlyShippingMethod: ShippingMethod) {
        let shippingMethod = viewStorage.insertNewObject(ofType: StorageShippingMethod.self)
        shippingMethod.update(with: readOnlyShippingMethod)
        viewStorage.saveIfNeeded()
    }
}
