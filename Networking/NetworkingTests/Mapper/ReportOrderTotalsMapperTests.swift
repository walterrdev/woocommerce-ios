import XCTest
@testable import Networking

final class ReportOrderTotalsMapperTests: XCTestCase {

    /// Dummy Site ID.
    ///
    private let dummySiteID: Int64 = 123

    private let fileNameWithDataEnvelope = "report-orders-total"
    private let fileNameWithoutDataEnvelope = "report-orders-total-without-data"

    func test_order_statuses_is_mapped_from_response_with_data_envelope() {
        // Given
        let mapper = ReportOrderTotalsMapper(siteID: dummySiteID)
        guard let data = Loader.contentsOf(fileNameWithDataEnvelope) else {
            XCTFail(fileNameWithDataEnvelope + ".json not found")
            return
        }

        // When
        let statuses = try? mapper.map(response: data)

        // Then
        XCTAssertNotNil(mapper)
        XCTAssertEqual(statuses?.count, 8)
    }

    func test_order_statuses_is_mapped_from_response_without_data_envelope() {
        // Given
        let mapper = ReportOrderTotalsMapper(siteID: dummySiteID)
        guard let data = Loader.contentsOf(fileNameWithoutDataEnvelope) else {
            XCTFail(fileNameWithoutDataEnvelope + ".json not found")
            return
        }

        // When
        let statuses = try? mapper.map(response: data)

        // Then
        XCTAssertNotNil(mapper)
        XCTAssertEqual(statuses?.count, 8)
    }
}

private extension ReportOrderTotalsMapperTests {
    /// Returns the CustomerMapper output upon receiving `filename` (Data Encoded)
    ///
    func mapStatus(from filename: String) throws -> [OrderStatus] {
        guard let response = Loader.contentsOf(filename) else {
            return []
        }
        return try ReportOrderTotalsMapper(siteID: dummySiteID).map(response: response)
    }
}
