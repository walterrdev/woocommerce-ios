import XCTest
import WooFoundation
import Yosemite
@testable import WooCommerce

final class SessionsReportCardViewModelTests: XCTestCase {

    func test_it_inits_with_expected_values() {
        // Given
        let vm = SessionsReportCardViewModel(
            currentOrderStats: OrderStatsV4.fake().copy(totals: .fake().copy(totalOrders: 5)),
            siteStats: SiteSummaryStats.fake().copy(visitors: 10, views: 60),
            isRedacted: false
        )

        // Then
        assertEqual("60", vm.leadingValue)
        XCTAssertNil(vm.leadingDelta)
        assertEqual([], vm.leadingChartData)
        assertEqual("50%", vm.trailingValue)
        XCTAssertNil(vm.trailingDelta)
        assertEqual([], vm.trailingChartData)
        XCTAssertFalse(vm.isRedacted)
        XCTAssertFalse(vm.showSyncError)
        XCTAssertNil(vm.reportViewModel)
    }

    func test_it_shows_sync_error_when_current_stats_are_nil() {
        // Given
        let vm = SessionsReportCardViewModel(currentOrderStats: nil, siteStats: .fake())

        // Then
        XCTAssertTrue(vm.showSyncError)
    }

    func test_it_shows_sync_error_when_previous_stats_are_nil() {
        // Given
        let vm = SessionsReportCardViewModel(currentOrderStats: .fake(), siteStats: nil)

        // Then
        XCTAssertTrue(vm.showSyncError)
    }

    func test_redact_updates_properties_as_expected() {
        // Given
        var vm = SessionsReportCardViewModel(currentOrderStats: nil, siteStats: nil)

        // When
        vm.redact()

        // Then

        assertEqual("1000", vm.leadingValue)
        XCTAssertNil(vm.leadingDelta)
        assertEqual([], vm.leadingChartData)
        assertEqual("1000%", vm.trailingValue)
        XCTAssertNil(vm.trailingDelta)
        assertEqual([], vm.trailingChartData)
        XCTAssertTrue(vm.isRedacted)
        XCTAssertFalse(vm.showSyncError)
        XCTAssertNil(vm.reportViewModel)
    }

    func test_properties_updated_as_expected_after_stats_update() {
        // Given
        let vm = SessionsReportCardViewModel(currentOrderStats: nil, siteStats: nil)

        // When
        vm.update(currentOrderStats: OrderStatsV4.fake().copy(totals: .fake().copy(totalOrders: 5)),
                  siteStats: SiteSummaryStats.fake().copy(visitors: 10, views: 60))

        // Then
        assertEqual("60", vm.leadingValue)
        assertEqual("50%", vm.trailingValue)
        XCTAssertFalse(vm.isRedacted)
    }

}
