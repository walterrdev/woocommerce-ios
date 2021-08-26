import XCTest
import Fakes
import Yosemite
@testable import WooCommerce

class CardReaderConnectionControllerTests: XCTestCase {
    /// Dummy Site ID
    ///
    private let sampleSiteID: Int64 = 1234

    func test_cancelling_search_calls_completion_with_success_false() throws {
        // Given
        let expectation = self.expectation(description: #function)

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            sessionManager: SessionManager.testingInstance
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReadersProvider = MockKnownReadersProvider(knownReaders: [])
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelScanning)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            knownReadersProvider: mockKnownReadersProvider,
            alertsProvider: mockAlerts
        )

        // When
        controller.searchAndConnect(from: mockPresentingViewController) { result in
            XCTAssertTrue(result.isSuccess)
            if case .success(let connected) = result {
                XCTAssertFalse(connected)
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    func test_finding_an_unknown_reader_prompts_user_before_completing_with_success_true() {
        // Given
        let expectation = self.expectation(description: #function)

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReader: MockCardReader.bbposChipper2XBT(),
            sessionManager: SessionManager.testingInstance
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReadersProvider = MockKnownReadersProvider(knownReaders: [])
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .connectFoundReader)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            knownReadersProvider: mockKnownReadersProvider,
            alertsProvider: mockAlerts
        )

        // When
        controller.searchAndConnect(from: mockPresentingViewController) { result in
            XCTAssertTrue(result.isSuccess)
            if case .success(let connected) = result {
                XCTAssertTrue(connected)
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    func test_finding_an_known_reader_automatically_connects_and_completes_with_success_true() {
        // Given
        let expectation = self.expectation(description: #function)

        let knownReader = MockCardReader.bbposChipper2XBT()

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReader: knownReader,
            sessionManager: SessionManager.testingInstance
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReadersProvider = MockKnownReadersProvider(knownReaders: [knownReader.id])
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .connectFoundReader)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            knownReadersProvider: mockKnownReadersProvider,
            alertsProvider: mockAlerts
        )

        // When
        controller.searchAndConnect(from: mockPresentingViewController) { result in
            XCTAssertTrue(result.isSuccess)
            if case .success(let connected) = result {
                XCTAssertTrue(connected)
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    func test_searching_error_presents_error_to_user_and_completes_with_failure() {
        // Given
        let expectation = self.expectation(description: #function)

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            sessionManager: SessionManager.testingInstance,
            failDiscovery: true
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReadersProvider = MockKnownReadersProvider(knownReaders: [])
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .closeScanFailure)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            knownReadersProvider: mockKnownReadersProvider,
            alertsProvider: mockAlerts
        )

        // When
        controller.searchAndConnect(from: mockPresentingViewController) { result in
            XCTAssertTrue(result.isFailure)
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

}
