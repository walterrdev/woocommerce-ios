import XCTest
@testable import Yosemite

final class OrderStatsV4Interval_DateTests: XCTestCase {
    private let mockIntervalSubtotals = OrderStatsV4Totals(totalOrders: 0, totalItemsSold: 0, grossRevenue: 0, netRevenue: 0, averageOrderValue: 0)

    func testDateStartAndDateEnd() {
        let dateStringInSiteTimeZone = "2019-08-08 10:45:00"
        let interval = OrderStatsV4Interval(interval: "hour",
                                            dateStart: dateStringInSiteTimeZone,
                                            dateEnd: dateStringInSiteTimeZone,
                                            subtotals: mockIntervalSubtotals)
        // As long as the dates are parsed and formatted in the same time zone, they should be consistent.
        let timeZone = TimeZone(secondsFromGMT: 29302)!
        [interval.dateStart(timeZone: timeZone), interval.dateEnd(timeZone: timeZone)].forEach { date in
            let dateComponents = Calendar.current.dateComponents(in: timeZone, from: date)
            XCTAssertEqual(dateComponents.year, 2019)
            XCTAssertEqual(dateComponents.month, 8)
            XCTAssertEqual(dateComponents.day, 8)
            XCTAssertEqual(dateComponents.hour, 10)
            XCTAssertEqual(dateComponents.minute, 45)
            XCTAssertEqual(dateComponents.second, 0)
        }
    }

    func test_date_start_and_date_end_parsed_when_daylight_saving_time_begins() throws {
        // Given
        let dateString = "2023-03-26 01:00:00"
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let interval = OrderStatsV4Interval(interval: "hour",
                                            dateStart: dateString,
                                            dateEnd: dateString,
                                            subtotals: mockIntervalSubtotals)

        // When
        let dateStart = interval.dateStart(timeZone: timeZone)
        let dateEnd = interval.dateEnd(timeZone: timeZone)

        // Then
        XCTAssertNotNil(dateStart)
        XCTAssertNotNil(dateEnd)
    }
}
