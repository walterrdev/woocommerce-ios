import XCTest
@testable import Networking


/// ProductBundleStatsRemote Unit Tests
///
class ProductBundleStatsRemoteTests: XCTestCase {

    /// Dummy Network Wrapper
    ///
    let network = MockNetwork()

    /// Dummy Site ID
    ///
    let sampleSiteID: Int64 = 1234

    /// Repeat always!
    ///
    override func setUp() {
        network.removeAllSimulatedResponses()
    }


    /// Verifies that loadProductBundleStats properly parses the `ProductBundleStats` sample response.
    ///
    func test_loadProductBundleStats_properly_returns_parsed_stats() throws {
        // Given
        let remote = ProductBundleStatsRemote(network: network)
        network.simulateResponse(requestUrlSuffix: "reports/bundles/stats", filename: "product-bundle-stats")

        // When
        let result: Result<ProductBundleStats, Error> = waitFor { promise in
            remote.loadProductBundleStats(for: self.sampleSiteID,
                                          unit: .daily,
                                          timeZone: .gmt,
                                          earliestDateToInclude: Date(),
                                          latestDateToInclude: Date(),
                                          quantity: 2,
                                          forceRefresh: false) { result in
                promise(result)
            }
        }

        // Then
        XCTAssertTrue(result.isSuccess)
        let productBundleStats = try result.get()
        XCTAssertEqual(productBundleStats.intervals.count, 2)
    }

    /// Verifies that loadProductBundleStats properly relays Networking Layer errors.
    ///
    func test_loadSiteVisitorStats_properly_relays_networking_errors() {
        // Given
        let remote = ProductBundleStatsRemote(network: network)

        // When
        let result: Result<ProductBundleStats, Error> = waitFor { promise in
            remote.loadProductBundleStats(for: self.sampleSiteID,
                                          unit: .daily,
                                          timeZone: .gmt,
                                          earliestDateToInclude: Date(),
                                          latestDateToInclude: Date(),
                                          quantity: 2,
                                          forceRefresh: false) { result in
                promise(result)
            }
        }

        // Then
        XCTAssertTrue(result.isFailure)
    }
}
