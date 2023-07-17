import XCTest
@testable import Networking


/// InAppPurchasesRemote Unit Tests
///
class InAppPurchasesRemoteTests: XCTestCase {

    /// Dummy Network Wrapper
    ///
    let network = MockNetwork()

    /// Dummy Site ID
    ///
    let sampleSiteID: Int64 = 1234

    /// Dummy Order ID
    ///
    let sampleOrderId: Int = 12345

    /// Repeat always!
    ///
    override func setUp() {
        network.removeAllSimulatedResponses()
    }


    /// Verifies that 'moderateComment' as spam properly parses the successful response
    ///
    func test_load_products_returns_list_of_products() throws {
        // Given
        let remote = InAppPurchasesRemote(network: network)

        network.simulateResponse(requestUrlSuffix: "iap/products", filename: "iap-products")

        // When
        var result: Result<[String], Error>?
        waitForExpectation { expectation in
            remote.loadProducts() { aResult in
                result = aResult
                expectation.fulfill()
            }
        }

        // Then
        let identifiers = try XCTUnwrap(result?.get())
        XCTAssert(identifiers.count == 1)
    }

    func test_purchase_product_returns_created_order() throws {
        // Given
        let remote = InAppPurchasesRemote(network: network)

        network.simulateResponse(requestUrlSuffix: "iap/orders", filename: "iap-order-create")

        // When
        var result: Result<Int, Error>?
        waitForExpectation { expectation in
            remote.createOrder(
                for: sampleSiteID,
                price: 2499,
                productIdentifier: "woocommerce_entry_monthly",
                appStoreCountryCode: "us",
                originalTransactionId: 1234,
                transactionId: 12345,
                subscriptionGroupId: "21032734") { aResult in
                    result = aResult
                    expectation.fulfill()
                }
        }

        // Then
        let orderId = try XCTUnwrap(result?.get())
        XCTAssertEqual(sampleOrderId, orderId)
    }

    func test_checkTransactionHandled_when_success_to_retrieve_response_and_transaction_is_handled_then_returns_siteID() throws {
        // Given
        let remote = InAppPurchasesRemote(network: network)
        let transactionID: UInt64 = 1234

        network.simulateResponse(requestUrlSuffix: "iap/transactions/\(transactionID)", filename: "iap-transaction-handled")

        // When
        var expectedResult: Result<Int64, Error>?
        waitForExpectation { expectation in
            remote.checkTransactionHandled(with: transactionID) { aResult in
                expectedResult = aResult
                expectation.fulfill()
            }
        }

        // Then
        let expectedSiteID = try XCTUnwrap(expectedResult?.get())
        XCTAssertEqual(expectedSiteID, sampleSiteID)
    }

    func test_checkTransactionHandled_when_success_to_retrieve_response_and_transaction_is_not_handled_then_returns_transactionNotHandled_error() throws {
        // Given
        let remote = InAppPurchasesRemote(network: network)
        let transactionID: UInt64 = 0

        network.simulateResponse(requestUrlSuffix: "iap/transactions/\(transactionID)", filename: "iap-transaction-not-handled")

        // When
        var expectedResult: Result<Int64, Error>?
        waitForExpectation { expectation in
            remote.checkTransactionHandled(with: transactionID) { aResult in
                expectedResult = aResult
                expectation.fulfill()
            }
        }

        // Then
        let expectedError = try XCTUnwrap(expectedResult?.failure)
        XCTAssertEqual(expectedError as? InAppPurchasesTransactionError, .transactionNotHandled)
    }

    func test_checkTransactionHandled_when_fails_to_retrieve_response_then_returns_network_error() throws {
        // Given
        let remote = InAppPurchasesRemote(network: network)
        let transactionID: UInt64 = 1234

        network.simulateResponse(requestUrlSuffix: "iap/transactions", filename: "")

        // When
        var expectedResult: Result<Int64, Error>?
        waitForExpectation { expectation in
            remote.checkTransactionHandled(with: transactionID) { result in
                switch result {
                case .success(let siteID):
                    XCTFail("Expected failure, but found existing handled transaction for associated site ID: \(siteID)")
                case .failure:
                    expectedResult = result
                    expectation.fulfill()
                }
            }
        }

        // Then
        let expectedError = try XCTUnwrap(expectedResult?.failure)
        XCTAssertEqual(expectedError as? NetworkError, Networking.NetworkError.notFound)
    }
}
