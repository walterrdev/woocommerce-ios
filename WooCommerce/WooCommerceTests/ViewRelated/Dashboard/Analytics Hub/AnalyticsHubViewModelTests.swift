import XCTest
import Yosemite
import WooFoundation
@testable import WooCommerce
import enum Networking.DotcomError

final class AnalyticsHubViewModelTests: XCTestCase {

    private var stores: MockStoresManager!
    private var eventEmitter: StoreStatsUsageTracksEventEmitter!
    private var analyticsProvider: MockAnalyticsProvider!
    private var analytics: Analytics!
    private var noticePresenter: MockNoticePresenter!
    private var vm: AnalyticsHubViewModel!

    private let sampleAdminURL = "https://example.com/wp-admin/"

    override func setUp() {
        stores = MockStoresManager(sessionManager: .makeForTesting(authenticated: true, defaultSite: .fake().copy(adminURL: sampleAdminURL)))
        analyticsProvider = MockAnalyticsProvider()
        analytics = WooAnalytics(analyticsProvider: analyticsProvider)
        eventEmitter = StoreStatsUsageTracksEventEmitter(analytics: analytics)
        noticePresenter = MockNoticePresenter()
        ServiceLocator.setCurrencySettings(CurrencySettings()) // Default is US
        vm = createViewModel()
    }

    func test_cards_viewmodels_show_correct_data_after_updating_from_network() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                let stats = OrderStatsV4.fake().copy(totals: .fake().copy(totalOrders: 15, totalItemsSold: 5, grossRevenue: 62))
                completion(.success(stats))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                let topEarners = TopEarnerStats.fake().copy(items: [.fake()])
                completion(.success(topEarners))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                let siteStats = SiteSummaryStats.fake().copy(visitors: 30, views: 53)
                completion(.success(siteStats))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertFalse(vm.revenueCard.isRedacted)
        XCTAssertFalse(vm.ordersCard.isRedacted)
        XCTAssertFalse(vm.productsStatsCard.isRedacted)
        XCTAssertFalse(vm.itemsSoldCard.isRedacted)
        XCTAssertFalse(vm.sessionsCard.isRedacted)

        XCTAssertEqual(vm.revenueCard.leadingValue, "$62")
        XCTAssertEqual(vm.ordersCard.leadingValue, "15")
        XCTAssertEqual(vm.productsStatsCard.itemsSold, "5")
        XCTAssertEqual(vm.itemsSoldCard.itemsSoldData.count, 1)
        XCTAssertEqual(vm.sessionsCard.leadingValue, "53")
        XCTAssertEqual(vm.sessionsCard.trailingValue, "50%")
    }

    func test_cards_viewmodels_show_sync_error_after_getting_error_from_network() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertTrue(vm.ordersCard.showSyncError)
        XCTAssertTrue(vm.productsStatsCard.showStatsError)
        XCTAssertTrue(vm.itemsSoldCard.showItemsSoldError)
        XCTAssertTrue(vm.sessionsCard.showSyncError)
    }

    func test_cards_viewmodels_show_sync_error_only_if_underlying_request_fails() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                let topEarners = TopEarnerStats.fake().copy(items: [.fake()])
                completion(.success(topEarners))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertTrue(vm.ordersCard.showSyncError)
        XCTAssertTrue(vm.productsStatsCard.showStatsError)

        XCTAssertFalse(vm.itemsSoldCard.showItemsSoldError)
        XCTAssertEqual(vm.itemsSoldCard.itemsSoldData.count, 1)

        XCTAssertTrue(vm.sessionsCard.showSyncError)
    }

    func test_cards_viewmodels_redacted_while_updating_from_network() async {
        // Given
        var loadingRevenueCardRedacted: Bool = false
        var loadingOrdersCard: AnalyticsReportCardViewModel?
        var loadingProductsCard: AnalyticsProductsStatsCardViewModel?
        var loadingItemsSoldCard: AnalyticsItemsSoldViewModel?
        var loadingSessionsCard: AnalyticsReportCardCurrentPeriodViewModel?
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                let stats = OrderStatsV4.fake().copy(totals: .fake().copy(totalOrders: 15, totalItemsSold: 5, grossRevenue: 62))
                loadingRevenueCardRedacted = self.vm.revenueCard.isRedacted
                loadingOrdersCard = self.vm.ordersCard
                loadingProductsCard = self.vm.productsStatsCard
                loadingItemsSoldCard = self.vm.itemsSoldCard
                completion(.success(stats))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                let topEarners = TopEarnerStats.fake().copy(items: [.fake()])
                completion(.success(topEarners))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                let siteStats = SiteSummaryStats.fake()
                loadingSessionsCard = self.vm.sessionsCard
                completion(.success(siteStats))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertTrue(loadingRevenueCardRedacted)
        XCTAssertEqual(loadingOrdersCard?.isRedacted, true)
        XCTAssertEqual(loadingProductsCard?.isRedacted, true)
        XCTAssertEqual(loadingItemsSoldCard?.isRedacted, true)
        XCTAssertEqual(loadingSessionsCard?.isRedacted, true)
    }

    func test_session_card_is_hidden_for_custom_range() async {
        // Given
        XCTAssertTrue(vm.enabledCards.contains(.sessions))

        // When
        vm.timeRangeSelectionType = .custom(start: Date(), end: Date())

        // Then
        XCTAssertFalse(vm.enabledCards.contains(.sessions))

        // When
        vm.timeRangeSelectionType = .lastMonth

        // Then
        XCTAssertTrue(vm.enabledCards.contains(.sessions))
    }

    func test_session_card_is_hidden_for_sites_without_jetpack_plugin() {
        // Given
        let storesForNonJetpackSite = MockStoresManager(sessionManager: .makeForTesting(authenticated: true, defaultSite: .fake().copy(siteID: -1)))
        let vmNonJetpackSite = createViewModel(stores: storesForNonJetpackSite)

        let storesForJCPSite = MockStoresManager(sessionManager: .makeForTesting(authenticated: true,
                                                                              defaultSite: .fake().copy(isJetpackThePluginInstalled: false,
                                                                                                        isJetpackConnected: true)))
        let vmJCPSite = createViewModel(stores: storesForJCPSite)

        // Then
        XCTAssertFalse(vmNonJetpackSite.enabledCards.contains(.sessions))
        XCTAssertFalse(vmJCPSite.enabledCards.contains(.sessions))
    }

    @MainActor
    func test_session_card_and_stats_CTA_are_hidden_for_shop_manager_when_stats_module_disabled() async {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting(defaultRoles: [.shopManager]))
        let vm = createViewModel(stores: stores)
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(SiteStatsStoreError.statsModuleDisabled))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertFalse(vm.showJetpackStatsCTA)
        XCTAssertFalse(vm.enabledCards.contains(.sessions))
    }

    func test_time_range_card_tracks_expected_events() throws {
        // When
        vm.timeRangeCard.onTapped()
        vm.timeRangeCard.onSelected(.weekToDate)

        // Then
        assertEqual(["analytics_hub_date_range_button_tapped", "analytics_hub_date_range_option_selected"], analyticsProvider.receivedEvents)
        let optionSelectedEventProperty = try XCTUnwrap(analyticsProvider.receivedProperties.last?["option"] as? String)
        assertEqual("Week to Date", optionSelectedEventProperty)
    }

    func test_retrieving_stats_tracks_expected_waiting_time_event() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.success(.fake()))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssert(analyticsProvider.receivedEvents.contains(WooAnalyticsStat.analyticsHubWaitingTimeLoaded.rawValue))
    }

    @MainActor
    func test_showJetpackStatsCTA_true_for_admin_when_stats_module_disabled() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(SiteStatsStoreError.statsModuleDisabled))
            default:
                break
            }
        }
        XCTAssertFalse(vm.showJetpackStatsCTA)

        // When
        await vm.updateData()

        // Then
        XCTAssertTrue(vm.showJetpackStatsCTA)
    }

    @MainActor
    func test_showJetpackStatsCTA_false_for_admin_when_stats_request_fails_and_stats_module_enabled() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertFalse(vm.showJetpackStatsCTA)
    }

    @MainActor
    func test_enableJetpackStats_hides_call_to_action_after_successfully_enabling_stats() async {
        // Given
        stores.whenReceivingAction(ofType: JetpackSettingsAction.self) { action in
            switch action {
            case let .enableJetpackModule(_, _, completion):
                completion(.success(()))
            }
        }
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.success(.fake()))
            default:
                break
            }
        }

        // When
        await vm.enableJetpackStats()

        // Then
        XCTAssertFalse(vm.showJetpackStatsCTA)
    }

    @MainActor
    func test_enableJetpackStats_shows_error_and_call_to_action_after_failing_to_enable_stats() async {
        // Given
        stores.whenReceivingAction(ofType: JetpackSettingsAction.self) { action in
            switch action {
            case let .enableJetpackModule(_, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            }
        }

        // When
        await vm.enableJetpackStats()

        // Then
        XCTAssertEqual(noticePresenter.queuedNotices.count, 1)
        XCTAssertTrue(vm.showJetpackStatsCTA)
    }

    func test_it_tracks_expected_jetpack_stats_CTA_success_events() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(SiteStatsStoreError.statsModuleDisabled))
            default:
                break
            }
        }
        stores.whenReceivingAction(ofType: JetpackSettingsAction.self) { action in
            switch action {
            case let .enableJetpackModule(_, _, completion):
                completion(.success(()))
            }
        }

        // When
        await vm.updateData()
        await vm.enableJetpackStats()

        // Then
        let expectedEvents: [WooAnalyticsStat] = [
            .analyticsHubEnableJetpackStatsShown,
            .analyticsHubEnableJetpackStatsTapped,
            .analyticsHubEnableJetpackStatsSuccess
        ]
        for event in expectedEvents {
            XCTAssert(analyticsProvider.receivedEvents.contains(event.rawValue), "Did not receive expected event: \(event.rawValue)")
        }
    }

    func test_it_tracks_expected_jetpack_stats_CTA_failure_events() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(SiteStatsStoreError.statsModuleDisabled))
            default:
                break
            }
        }
        stores.whenReceivingAction(ofType: JetpackSettingsAction.self) { action in
            switch action {
            case let .enableJetpackModule(_, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            }
        }

        // When
        await vm.updateData()
        await vm.enableJetpackStats()

        // Then
        let expectedEvents: [WooAnalyticsStat] = [
            .analyticsHubEnableJetpackStatsShown,
            .analyticsHubEnableJetpackStatsTapped,
            .analyticsHubEnableJetpackStatsFailed
        ]
        for event in expectedEvents {
            XCTAssert(analyticsProvider.receivedEvents.contains(event.rawValue), "Did not receive expected event: \(event.rawValue)")
        }
    }

    @MainActor
    func test_cards_viewmodels_contain_expected_reportURL_elements() async throws {
        // When
        let ordersCardReportURL = try XCTUnwrap(vm.ordersCard.reportViewModel?.initialURL)
        let productsCardReportURL = try XCTUnwrap(vm.productsStatsCard.reportViewModel?.initialURL)

        let ordersCardURLQueryItems = try XCTUnwrap(URLComponents(url: ordersCardReportURL, resolvingAgainstBaseURL: false)?.queryItems)
        let productsCardURLQueryItems = try XCTUnwrap(URLComponents(url: productsCardReportURL, resolvingAgainstBaseURL: false)?.queryItems)

        // Then
        // Report URL contains expected admin URL
        XCTAssertTrue(ordersCardReportURL.relativeString.contains(sampleAdminURL))
        XCTAssertTrue(productsCardReportURL.relativeString.contains(sampleAdminURL))

        // Report URL contains expected report path
        XCTAssertTrue(ordersCardURLQueryItems.contains(URLQueryItem(name: "path", value: "/analytics/orders")))
        XCTAssertTrue(productsCardURLQueryItems.contains(URLQueryItem(name: "path", value: "/analytics/products")))

        // Report URL contains expected time range period
        let expectedPeriodQueryItem = URLQueryItem(name: "period", value: "month")
        XCTAssertTrue(ordersCardURLQueryItems.contains(expectedPeriodQueryItem))
        XCTAssertTrue(productsCardURLQueryItems.contains(expectedPeriodQueryItem))
    }

    @MainActor
    func test_cards_viewmodels_contain_expected_report_path_after_updating_from_network() async throws {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                let stats = OrderStatsV4.fake().copy(totals: .fake().copy(totalOrders: 15, totalItemsSold: 5, grossRevenue: 62))
                completion(.success(stats))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                let topEarners = TopEarnerStats.fake().copy(items: [.fake()])
                completion(.success(topEarners))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                let siteStats = SiteSummaryStats.fake().copy(visitors: 30, views: 53)
                completion(.success(siteStats))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        let ordersCardReportURL = try XCTUnwrap(vm.ordersCard.reportViewModel?.initialURL)
        let productsCardReportURL = try XCTUnwrap(vm.productsStatsCard.reportViewModel?.initialURL)

        let ordersCardURLQueryItems = try XCTUnwrap(URLComponents(url: ordersCardReportURL, resolvingAgainstBaseURL: false)?.queryItems)
        let productsCardURLQueryItems = try XCTUnwrap(URLComponents(url: productsCardReportURL, resolvingAgainstBaseURL: false)?.queryItems)

        // Report URL contains expected report path
        XCTAssertTrue(ordersCardURLQueryItems.contains(URLQueryItem(name: "path", value: "/analytics/orders")))
        XCTAssertTrue(productsCardURLQueryItems.contains(URLQueryItem(name: "path", value: "/analytics/products")))
    }

    @MainActor
    func test_cards_viewmodels_contain_non_nil_report_url_while_loading_and_after_error() async {
        // Given
        var loadingOrdersCard: AnalyticsReportCardViewModel?
        var loadingProductsCard: AnalyticsProductsStatsCardViewModel?
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                loadingOrdersCard = self.vm.ordersCard
                loadingProductsCard = self.vm.productsStatsCard
                completion(.failure(NSError(domain: "Test", code: 1)))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.failure(NSError(domain: "Test", code: 1)))
            default:
                break
            }
        }

        // When
        await vm.updateData()

        // Then
        XCTAssertNotNil(loadingOrdersCard?.reportViewModel?.initialURL)
        XCTAssertNotNil(loadingProductsCard?.reportViewModel?.initialURL)

        XCTAssertNotNil(vm.ordersCard.reportViewModel?.initialURL)
        XCTAssertNotNil(vm.productsStatsCard.reportViewModel?.initialURL)
    }

    @MainActor
    func test_card_report_URLs_contain_expected_period_after_new_timeRange_selection() async throws {
        // Given
        XCTAssertEqual(.monthToDate, vm.timeRangeSelectionType)

        // When
        vm.timeRangeSelectionType = .today

        // Then
        let revenueCardReportURL = try XCTUnwrap(vm.revenueCard.reportViewModel?.initialURL)

        let revenueCardURLQueryItems = try XCTUnwrap(URLComponents(url: revenueCardReportURL, resolvingAgainstBaseURL: false)?.queryItems)

        // Report URL contains expected time range period
        let expectedPeriodQueryItem = URLQueryItem(name: "period", value: "today")
        XCTAssertTrue(revenueCardURLQueryItems.contains(expectedPeriodQueryItem))
    }

    // MARK: Customized Analytics

    func test_enabledCards_shows_correct_data_after_loading_from_storage() async {
        // Given
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadAnalyticsHubCards(_, completion):
                completion([AnalyticsCard(type: .revenue, enabled: true),
                            AnalyticsCard(type: .orders, enabled: false),
                            AnalyticsCard(type: .products, enabled: false),
                            AnalyticsCard(type: .sessions, enabled: false)])
            default:
                break
            }
        }

        // When
        await vm.loadAnalyticsCardSettings()

        // Then
        assertEqual([.revenue], vm.enabledCards)
    }

    func test_it_updates_enabledCards_when_saved() async throws {
        // Given
        assertEqual([.revenue, .orders, .products, .sessions], vm.enabledCards)

        // When
        vm.customizeAnalytics()
        let customizeAnalytics = try XCTUnwrap(vm.customizeAnalyticsViewModel)
        customizeAnalytics.selectedCards = [AnalyticsCard(type: .revenue, enabled: true)]
        customizeAnalytics.saveChanges()

        // Then
        assertEqual([.revenue], vm.enabledCards)
    }

    func test_it_stores_updated_analytics_cards_when_saved() async throws {
        // When
        let storedAnalyticsCards = try waitFor { promise in
            self.stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
                switch action {
                case let .setAnalyticsHubCards(_, cards):
                    promise(cards)
                default:
                    break
                }
            }

            // Only revenue card is selected and changes are saved
            self.vm.customizeAnalytics()
            let customizeAnalytics = try XCTUnwrap(self.vm.customizeAnalyticsViewModel)
            customizeAnalytics.selectedCards = [AnalyticsCard(type: .revenue, enabled: true)]
            customizeAnalytics.saveChanges()
        }

        // Then
        // Stored cards contain updated selection
        let expectedCards = [AnalyticsCard(type: .revenue, enabled: true),
                             AnalyticsCard(type: .orders, enabled: false),
                             AnalyticsCard(type: .products, enabled: false),
                             AnalyticsCard(type: .sessions, enabled: false)]
        assertEqual(expectedCards, storedAnalyticsCards)
    }

    @MainActor
    func test_retrieving_stats_skips_summary_stats_request_when_sessions_card_is_hidden() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                XCTFail("Request to retrieve site summary stats should not be dispatched when sessions card is hidden")
                completion(.failure(DotcomError.unknown(code: "unknown_blog", message: "Unknown blog")))
            default:
                break
            }
        }
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadAnalyticsHubCards(_, completion):
                completion([AnalyticsCard(type: .revenue, enabled: true),
                            AnalyticsCard(type: .orders, enabled: true),
                            AnalyticsCard(type: .products, enabled: true),
                            AnalyticsCard(type: .sessions, enabled: false)])
            default:
                break
            }
        }

        // When
        await vm.loadAnalyticsCardSettings()
        await vm.updateData()
    }

    @MainActor
    func test_retrieving_stats_skips_top_earner_stats_request_when_products_card_is_hidden() async {
        // Given
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                XCTFail("Request to retrieve site summary stats should not be dispatched for sites without Jetpack")
                completion(.failure(DotcomError.unknown(code: "unknown_blog", message: "Unknown blog")))
            case let .retrieveSiteSummaryStats(_, _, _, _, _, _, completion):
                completion(.success(.fake()))
            default:
                break
            }
        }
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadAnalyticsHubCards(_, completion):
                completion([AnalyticsCard(type: .revenue, enabled: true),
                            AnalyticsCard(type: .orders, enabled: true),
                            AnalyticsCard(type: .products, enabled: false),
                            AnalyticsCard(type: .sessions, enabled: true)])
            default:
                break
            }
        }

        // When
        await vm.loadAnalyticsCardSettings()
        await vm.updateData()
    }

    func test_enabling_new_card_fetches_required_data() async throws {
        // Given it fetches order stats (current and previous) for initial cards
        stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
            switch action {
            case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                completion(.success(.fake()))
            default:
                break
            }
        }
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadAnalyticsHubCards(_, completion):
                completion([AnalyticsCard(type: .revenue, enabled: true),
                            AnalyticsCard(type: .orders, enabled: true),
                            AnalyticsCard(type: .products, enabled: false),
                            AnalyticsCard(type: .sessions, enabled: false)])
            default:
                break
            }
        }
        await vm.loadAnalyticsCardSettings()
        await vm.updateData()
        assertEqual(2, stores.receivedActions.filter { $0 is StatsActionV4 }.count)

        // When the products card is enabled
        let fetchedTopEarnerStats: Bool = try waitFor { promise in
            self.stores.whenReceivingAction(ofType: StatsActionV4.self) { action in
                switch action {
                case let .retrieveCustomStats(_, _, _, _, _, _, _, completion):
                    completion(.success(.fake()))
                case let .retrieveTopEarnerStats(_, _, _, _, _, _, _, _, completion):
                    completion(.success(.fake()))
                    promise(true)
                default:
                    break
                }
            }
            self.vm.customizeAnalytics()
            let customizeAnalytics = try XCTUnwrap(self.vm.customizeAnalyticsViewModel)
            customizeAnalytics.selectedCards.update(with: AnalyticsCard(type: .products, enabled: false))
            customizeAnalytics.saveChanges()
        }

        // Then it fetches order stats and top earner stats for products card
        XCTAssertTrue(fetchedTopEarnerStats)
        assertEqual(5, stores.receivedActions.filter { $0 is StatsActionV4 }.count)
    }

    func test_changing_card_settings_without_enabling_new_cards_does_not_update_data() async throws {
        // Given
        stores.whenReceivingAction(ofType: AppSettingsAction.self) { action in
            switch action {
            case let .loadAnalyticsHubCards(_, completion):
                completion([AnalyticsCard(type: .revenue, enabled: true),
                            AnalyticsCard(type: .orders, enabled: true),
                            AnalyticsCard(type: .products, enabled: false),
                            AnalyticsCard(type: .sessions, enabled: false)])
            default:
                break
            }
        }
        await vm.loadAnalyticsCardSettings()

        // When & Then
        stores.whenReceivingAction(ofType: StatsActionV4.self) { _ in
            XCTFail("No data should be requested if new cards aren't enabled")
        }

        // Orders card is deselected and changes are saved
        self.vm.customizeAnalytics()
        let customizeAnalytics = try XCTUnwrap(self.vm.customizeAnalyticsViewModel)
        customizeAnalytics.selectedCards = [AnalyticsCard(type: .revenue, enabled: true)]
        customizeAnalytics.saveChanges()
    }

    func test_customizeAnalytics_excludes_sessions_card_when_ineligible() throws {
        // Given
        let stores = MockStoresManager(sessionManager: .makeForTesting(authenticated: true, defaultSite: .fake().copy(siteID: -1)))
        let vm = createViewModel(stores: stores)

        // When
        vm.customizeAnalytics()

        // Then
        let customizeAnalyticsVM = try XCTUnwrap(vm.customizeAnalyticsViewModel)
        let expectedCards = [AnalyticsCard(type: .revenue, enabled: true),
                             AnalyticsCard(type: .orders, enabled: true),
                             AnalyticsCard(type: .products, enabled: true)]
        XCTAssertFalse(vm.enabledCards.contains(.sessions))
        assertEqual(expectedCards, customizeAnalyticsVM.allCards)
    }

    func test_customizeAnalytics_tracks_expected_event() {
        // When
        vm.customizeAnalytics()

        // Then
        XCTAssert(analyticsProvider.receivedEvents.contains(WooAnalyticsStat.analyticsHubSettingsOpened.rawValue))
    }
}

private extension AnalyticsHubViewModelTests {
    func createViewModel(stores: MockStoresManager? = nil) -> AnalyticsHubViewModel {
        AnalyticsHubViewModel(siteID: 123,
                              statsTimeRange: .thisMonth,
                              usageTracksEventEmitter: eventEmitter,
                              stores: stores ?? self.stores,
                              analytics: analytics,
                              noticePresenter: noticePresenter,
                              backendProcessingDelay: 0)
    }
}
