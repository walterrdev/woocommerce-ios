import XCTest
import Yosemite
import enum Storage.StatsVersion
import enum Networking.DotcomError
@testable import WooCommerce

@MainActor
final class StorePerformanceViewModelTests: XCTestCase {

    func test_dates_for_custom_range_are_correct_for_non_custom_time_range() throws {
        // Given
        let viewModel = StorePerformanceViewModel(siteID: 123, usageTracksEventEmitter: .init())

        // When
        viewModel.didSelectTimeRange(.thisWeek)

        // Then
        let now = Date()
        let startDateForCustomRange = viewModel.startDateForCustomRange
        let endDateForCustomRange = viewModel.endDateForCustomRange
        XCTAssertTrue(now.isSameDay(as: endDateForCustomRange))
        XCTAssertTrue(try XCTUnwrap(now.adding(days: -30)).isSameDay(as: startDateForCustomRange))
    }

    func test_dates_for_custom_range_are_correct_for_custom_time_range() throws {
        // Given
        let viewModel = StorePerformanceViewModel(siteID: 123, usageTracksEventEmitter: .init())

        // When
        let startDate = try XCTUnwrap(Date().adding(days: -100))
        let endDate = try XCTUnwrap(Date().adding(days: -10))
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))

        // Then
        XCTAssertEqual(viewModel.startDateForCustomRange, startDate)
        XCTAssertEqual(viewModel.endDateForCustomRange, endDate)
    }

    func test_granularityText_is_nil_for_non_custom_time_range() {
        // Given
        let viewModel = StorePerformanceViewModel(siteID: 123, usageTracksEventEmitter: .init())

        // When
        viewModel.didSelectTimeRange(.thisWeek)

        // Then
        XCTAssertNil(viewModel.granularityText)
    }

    func test_granularityText_is_not_nil_for_custom_time_range() throws {
        // Given
        let viewModel = StorePerformanceViewModel(siteID: 123, usageTracksEventEmitter: .init())

        // When
        let startDate = try XCTUnwrap(Date().adding(days: -100))
        let endDate = try XCTUnwrap(Date().adding(days: -10))
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))

        // Then
        XCTAssertNotNil(viewModel.granularityText)
    }

    func test_loadLastTimeRange_is_fetched_upon_initialization() {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadLastSelectedStatsTimeRange(_, onCompletion):
                onCompletion(StatsTimeRangeV4.thisWeek)
            default:
                break
            }
        }

        // When
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())

        // Then
        XCTAssertEqual(viewModel.timeRange, .today) // initial value
        waitUntil {
            viewModel.timeRange == .thisWeek
        }
    }

    func test_saveLastTimeRange_is_triggered_when_updating_time_range() {
        // Given
        var savedTimeRange: StatsTimeRangeV4?
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .setLastSelectedStatsTimeRange(_, timeRange):
                savedTimeRange = timeRange
            default:
                break
            }
        }
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())

        // When
        viewModel.didSelectTimeRange(.thisYear)

        // Then
        XCTAssertEqual(savedTimeRange, .thisYear)
    }

    func test_statsVersion_is_updated_correctly_when_sync_stats_failed_with_noRestRoute_error() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores, toReturn: .v3)
        XCTAssertEqual(viewModel.statsVersion, .v4) // Initial value

        // When
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.statsVersion, .v3)
    }

    func test_siteVisitStatMode_is_default_if_syncing_stats_succeeds_for_non_custom_time_range() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores)

        // When
        viewModel.didSelectTimeRange(.thisMonth)
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .default)
    }

    func test_siteVisitStatMode_is_default_if_syncing_stats_succeeds_with_custom_time_range_of_same_day_for_jetpack_site() async throws {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: true,
                                           isJetpackConnected: true)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores)

        // When
        let endDate = Date().endOfDay(timezone: .current)
        let startDate = Date().startOfDay(timezone: .current)
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .default)
    }

    func test_siteVisitStatMode_is_redactedDueToCustomRange_if_syncing_stats_succeeds_with_custom_time_range_longer_than_1_day_for_jetpack_site() async throws {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: true,
                                           isJetpackConnected: true)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores)

        // When
        let endDate = Date()
        let startDate = try XCTUnwrap(endDate.adding(days: -10))
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .redactedDueToCustomRange)
    }

    func test_siteVisitStatMode_is_redactedDueToJetpack_if_syncing_stats_succeeds_with_custom_time_range_for_jcp_site() async throws {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: false,
                                           isJetpackConnected: true)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores)

        // When
        let endDate = Date()
        let startDate = try XCTUnwrap(endDate.adding(days: -10))
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .redactedDueToJetpack)
    }

    func test_siteVisitStatMode_is_hidden_if_syncing_stats_succeeds_with_custom_time_range_for_non_jetpack_site() async throws {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: false,
                                           isJetpackConnected: false)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores)

        // When
        let endDate = Date()
        let startDate = try XCTUnwrap(endDate.adding(days: -10))
        viewModel.didSelectTimeRange(.custom(from: startDate, to: endDate))
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .hidden)
    }

    func test_siteVisitStatMode_is_hidden_if_syncing_stats_failed_with_noPermission_error() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores, visitorStatsError: SiteStatsStoreError.noPermission)

        // When
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .hidden)
    }

    func test_siteVisitStatMode_is_hidden_if_syncing_stats_failed_with_statsModuleDisabled_error_for_non_JCP_site() async {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: false,
                                           isJetpackConnected: false)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores, visitorStatsError: SiteStatsStoreError.statsModuleDisabled)

        // When
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .hidden)
    }

    func test_siteVisitStatMode_is_redactedDueToJetpack_if_syncing_stats_failed_with_statsModuleDisabled_error_for_JCP_site() async {
        // Given
        let defaultSite = Site.fake().copy(isJetpackThePluginInstalled: false,
                                           isJetpackConnected: true)
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultSite: defaultSite))
        let viewModel = StorePerformanceViewModel(siteID: 123, stores: stores, usageTracksEventEmitter: .init())
        mockSyncAllStats(with: stores, visitorStatsError: SiteStatsStoreError.statsModuleDisabled)

        // When
        await viewModel.reloadData()

        // Then
        XCTAssertEqual(viewModel.siteVisitStatMode, .redactedDueToJetpack)
    }
}

// MARK: - Private helpers
//
private extension StorePerformanceViewModelTests {
    func mockSyncAllStats(with stores: MockStoresManager,
                          toReturn statsVersion: StatsVersion = .v4,
                          visitorStatsError: Error? = nil,
                          siteSummaryStatsError: Error? = nil) {
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveStats(_, _, _, _, _, _, _, onCompletion):
                if statsVersion == .v4 {
                    onCompletion(.success(()))
                } else {
                    onCompletion(.failure(DotcomError.noRestRoute))
                }
            case let .retrieveSiteVisitStats(_, _, _, _, onCompletion):
                if let visitorStatsError {
                    onCompletion(.failure(visitorStatsError))
                } else {
                    onCompletion(.success(()))
                }
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, onCompletion):
                if let siteSummaryStatsError {
                    onCompletion(.failure(siteSummaryStatsError))
                } else {
                    onCompletion(.success(.fake()))
                }
            default:
                break
            }
        }
    }
}
