import XCTest
@testable import Networking

final class CreateBlazeCampaignMapperTests: XCTestCase {

    /// Verifies that the response is parsed
    ///
    func test_CreateBlazeCampaignMapper_parses_response() throws {
        let id = try mapLoadCreateBlazeCampaignResponse()

        XCTAssertEqual(id, 12345)
    }
}

// MARK: - Test Helpers
//
private extension CreateBlazeCampaignMapperTests {

    /// Returns the CreateBlazeCampaignMapper output upon receiving `filename` (Data Encoded)
    ///
    func mapCreateBlazeCampaignResponse(from filename: String) throws -> Int64 {
        guard let response = Loader.contentsOf(filename) else {
            throw FileNotFoundError()
        }

        return try CreateBlazeCampaignMapper().map(response: response)
    }

    /// Returns the CreateBlazeCampaignMapper output from `blaze-create-campaign-success.json`
    ///
    func mapLoadCreateBlazeCampaignResponse() throws -> Int64 {
        return try mapCreateBlazeCampaignResponse(from: "blaze-create-campaign-success")
    }

    struct FileNotFoundError: Error {}
}
