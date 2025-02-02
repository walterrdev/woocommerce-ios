import XCTest
@testable import WooCommerce
@testable import Yosemite

@MainActor
final class BlazeBudgetSettingViewModelTests: XCTestCase {
    private var analyticsProvider: MockAnalyticsProvider!
    private var analytics: WooAnalytics!

    override func setUp() {
        super.setUp()
        analyticsProvider = MockAnalyticsProvider()
        analytics = WooAnalytics(analyticsProvider: analyticsProvider)
    }

    override func tearDown() {
        analyticsProvider = nil
        analytics = nil
        super.tearDown()
    }

    func test_confirmSettings_triggers_onCompletion_with_updated_details() {
        // Given
        let initialStartDate = Date(timeIntervalSinceNow: 0)
        let expectedStartDate = Date(timeIntervalSinceNow: 86400) // Next day
        var finalDailyBudget: Double?
        var finalDuration: Int?
        var finalStartDate: Date?
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 11,
                                                    duration: 3,
                                                    startDate: initialStartDate) { dailyBudget, duration, startDate in
            finalDuration = duration
            finalDailyBudget = dailyBudget
            finalStartDate = startDate
        }

        // When
        viewModel.dailyAmount = 80
        viewModel.didTapApplyDuration(dayCount: 7, since: expectedStartDate)
        viewModel.confirmSettings()

        // Then
        XCTAssertEqual(finalDailyBudget, 80)
        XCTAssertEqual(finalDuration, 7)
        XCTAssertEqual(finalStartDate, expectedStartDate)
    }

    func test_updateImpressions_updates_forecastedImpressionState_correctly_when_fetching_impression_succeeds() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 15,
                                                    duration: 3,
                                                    startDate: .now,
                                                    locale: Locale(identifier: "en_US"),
                                                    stores: stores,
                                                    onCompletion: { _, _, _ in })

        // When
        let expectedImpression = BlazeImpressions(totalImpressionsMin: 1000, totalImpressionsMax: 5000)
        stores.whenReceivingAction(ofType: BlazeAction.self) { action in
            switch action {
            case let .fetchForecastedImpressions(_, _, onCompletion):
                XCTAssertEqual(viewModel.forecastedImpressionState, .loading)
                onCompletion(.success(expectedImpression))
            default:
                break
            }
        }
        await viewModel.updateImpressions(startDate: .now, dayCount: 3, dailyBudget: 15)

        // Then
        XCTAssertEqual(viewModel.forecastedImpressionState, .result(formattedResult: "1,000 - 5,000"))
    }

    func test_updateImpressions_updates_forecastedImpressionState_correctly_when_fetching_impression_fails() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 15,
                                                    duration: 3,
                                                    startDate: .now,
                                                    stores: stores,
                                                    onCompletion: { _, _, _ in })

        // When
        let expectedError = NSError(domain: "Test", code: 500)
        stores.whenReceivingAction(ofType: BlazeAction.self) { action in
            switch action {
            case let .fetchForecastedImpressions(_, _, onCompletion):
                XCTAssertEqual(viewModel.forecastedImpressionState, .loading)
                onCompletion(.failure(expectedError))
            default:
                break
            }
        }
        await viewModel.updateImpressions(startDate: .now, dayCount: 3, dailyBudget: 15)

        // Then
        XCTAssertEqual(viewModel.forecastedImpressionState, .failure)
    }

    func test_retryFetchingImpressions_requests_fetching_impression_with_latest_settings() async throws {
        // Given
        var fetchInput: BlazeForecastedImpressionsInput?
        let expectedStartDate = Date(timeIntervalSinceNow: 86400) // Next day
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let targetOptions = BlazeTargetOptions(locations: [11, 22], languages: ["en", "vi"], devices: nil, pageTopics: ["Entertainment"])
        let stores = MockStoresManager(sessionManager: .makeForTesting())
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 15,
                                                    duration: 3,
                                                    startDate: .now,
                                                    timeZone: timeZone,
                                                    targetOptions: targetOptions,
                                                    stores: stores,
                                                    onCompletion: { _, _, _ in })

        // When
        stores.whenReceivingAction(ofType: BlazeAction.self) { action in
            switch action {
            case let .fetchForecastedImpressions(_, input, onCompletion):
                fetchInput = input
                onCompletion(.success(.fake()))
            default:
                break
            }
        }
        viewModel.dailyAmount = 20
        viewModel.didTapApplyDuration(dayCount: 7, since: expectedStartDate)
        await viewModel.retryFetchingImpressions()

        // Then
        XCTAssertEqual(fetchInput?.startDate, expectedStartDate)
        XCTAssertEqual(fetchInput?.endDate, Date(timeInterval: 7 * 86400, since: expectedStartDate))
        XCTAssertEqual(fetchInput?.totalBudget, 20 * 7)
        XCTAssertEqual(fetchInput?.timeZone, "Europe/London")
        XCTAssertEqual(fetchInput?.targeting, targetOptions)
    }

    // MARK: Analytics

    func test_confirmSettings_tracks_event_with_correct_properties() throws {
        // Given
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 15,
                                                    duration: 3,
                                                    startDate: .now,
                                                    analytics: analytics,
                                                    onCompletion: { _, _, _ in })


        // When
        viewModel.confirmSettings()

        // Then
        let index = try XCTUnwrap(analyticsProvider.receivedEvents.firstIndex(of: "blaze_creation_edit_budget_save_tapped"))
        let eventProperties = try XCTUnwrap(analyticsProvider.receivedProperties[index])
        XCTAssertEqual(eventProperties["duration"] as? Int, 3)
        XCTAssertEqual(eventProperties["total_budget"] as? Double, 45.0)
    }

    func test_changing_duration_tracks_event_with_correct_properties() throws {
        // Given
        let viewModel = BlazeBudgetSettingViewModel(siteID: 123,
                                                    dailyBudget: 15,
                                                    duration: 3,
                                                    startDate: .now,
                                                    analytics: analytics,
                                                    onCompletion: { _, _, _ in })


        // When
        viewModel.didTapApplyDuration(dayCount: 7, since: .now)

        // Then
        let index = try XCTUnwrap(analyticsProvider.receivedEvents.firstIndex(of: "blaze_creation_edit_budget_set_duration_applied"))
        let eventProperties = try XCTUnwrap(analyticsProvider.receivedProperties[index])
        XCTAssertEqual(eventProperties["duration"] as? Int, 7)
    }
}
