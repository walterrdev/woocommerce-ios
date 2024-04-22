import Combine
import WidgetKit
import WooFoundation
import Yosemite
import protocol Storage.StorageManagerType
import enum Storage.StatsVersion
import enum Networking.DotcomError

/// View model for `StorePerformanceView`.
///
final class StorePerformanceViewModel: ObservableObject {
    @Published private(set) var timeRange = StatsTimeRangeV4.today
    @Published private(set) var statsIntervalData: [StoreStatsChartData] = []

    @Published private(set) var timeRangeText = ""
    @Published private(set) var revenueStatsText = ""
    @Published private(set) var orderStatsText = ""
    @Published private(set) var visitorStatsText = ""
    @Published private(set) var conversionStatsText = ""

    @Published private(set) var selectedDateText: String?
    @Published private(set) var shouldHighlightStats = false

    @Published private(set) var syncingData = false
    @Published private(set) var siteVisitStatMode = SiteVisitStatsMode.hidden
    @Published private(set) var statsVersion: StatsVersion = .v4

    let siteID: Int64
    let siteTimezone: TimeZone
    private let stores: StoresManager
    private let storageManager: StorageManagerType
    private let currencyFormatter: CurrencyFormatter
    private let currencySettings: CurrencySettings
    private let usageTracksEventEmitter: StoreStatsUsageTracksEventEmitter
    private let analytics: Analytics

    private var periodViewModel: StoreStatsPeriodViewModel?

    // Set externally to trigger callback when data is being synced.
    var onDataReload: () -> Void = {}

    // Set externally to trigger callback when syncing fails.
    var onSyncingError: (Error) -> Void = { _ in }

    // Set externally to trigger callback when hiding the card.
    var onDismiss: (() -> Void)?

    private var subscriptions: Set<AnyCancellable> = []
    private var currentDate = Date()
    private let chartValueSelectedEventsSubject = PassthroughSubject<Int?, Never>()

    // To check whether the tab is showing the visitors and conversion views as redacted for custom range.
    // This redaction is only shown on Custom Range tab with WordPress.com or Jetpack connected sites,
    // while Jetpack CP sites has its own redacted for Jetpack state, and non-Jetpack sites simply has them empty.
    var unavailableVisitStatsDueToCustomRange: Bool {
        guard timeRange.isCustomTimeRange,
              let site = stores.sessionManager.defaultSite,
              site.isJetpackConnected,
              site.isJetpackThePluginInstalled else {
            return false
        }
        return true
    }

    init(siteID: Int64,
         siteTimezone: TimeZone = .siteTimezone,
         stores: StoresManager = ServiceLocator.stores,
         storageManager: StorageManagerType = ServiceLocator.storageManager,
         currencyFormatter: CurrencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings),
         currencySettings: CurrencySettings = ServiceLocator.currencySettings,
         usageTracksEventEmitter: StoreStatsUsageTracksEventEmitter,
         analytics: Analytics = ServiceLocator.analytics) {
        self.siteID = siteID
        self.stores = stores
        self.siteTimezone = siteTimezone
        self.storageManager = storageManager
        self.currencyFormatter = currencyFormatter
        self.currencySettings = currencySettings
        self.usageTracksEventEmitter = usageTracksEventEmitter
        self.analytics = analytics

        observeTimeRange()
        observeChartValueSelectedEvents()

        Task { @MainActor in
            self.timeRange = await loadLastTimeRange() ?? .today
        }
    }

    func didSelectTimeRange(_ newTimeRange: StatsTimeRangeV4) {
        timeRange = newTimeRange
        saveLastTimeRange(timeRange)
        shouldHighlightStats = false
        usageTracksEventEmitter.interacted()
        analytics.track(event: .Dashboard.dashboardMainStatsDate(timeRange: timeRange))
    }

    func didSelectStatsInterval(at index: Int?) {
        chartValueSelectedEventsSubject.send(index)
        periodViewModel?.selectedIntervalIndex = index
        shouldHighlightStats = index != nil

        if unavailableVisitStatsDueToCustomRange {
            // If time range is less than 2 days, redact data when selected and show when deselected.
            // Otherwise, show data when selected and redact when deselected.
            guard case let .custom(from, to) = timeRange,
                  let differenceInDays = StatsTimeRangeV4.differenceInDays(startDate: from, endDate: to) else {
                return
            }

            if differenceInDays == .sameDay {
                siteVisitStatMode = index != nil ? .hidden : .default
            } else {
                siteVisitStatMode = index != nil ? .default : .redactedDueToCustomRange
            }
        }
    }

    @MainActor
    func reloadData() async {
        onDataReload()
        syncingData = true
        let waitingTracker = WaitingTimeTracker(trackScenario: .dashboardMainStats)
        do {
            try await syncAllStats()
            trackDashboardStatsSyncComplete()
            statsVersion = .v4
            switch timeRange {
            case .custom:
                updateSiteVisitStatModeForCustomRange()
            case .today:
                // Reload the Store Info Widget after syncing the today's stats.
                WidgetCenter.shared.reloadTimelines(ofKind: WooConstants.storeInfoWidgetKind)
                fallthrough
            case .thisWeek, .thisMonth, .thisYear:
                siteVisitStatMode = .default
            }
        } catch DotcomError.noRestRoute {
            statsVersion = .v3
        } catch {
            statsVersion = .v4
            DDLogError("⛔️ Error loading store stats: \(error)")
            handleSyncError(error: error)
        }
        syncingData = false
        waitingTracker.end()
    }

    func hideStorePerformance() {
        // TODO: add tracking
        onDismiss?()
    }
}

// MARK: - Data for `StorePerformanceView`
//
extension StorePerformanceViewModel {
    var startDateForCustomRange: Date {
        if case let .custom(startDate, _) = timeRange {
            return startDate
        }
        return Date(timeInterval: -Constants.thirtyDaysInSeconds, since: endDateForCustomRange) // 30 days before end date
    }

    var endDateForCustomRange: Date {
        if case let .custom(_, endDate) = timeRange {
            return endDate
        }
        return Date()
    }

    var buttonTitleForCustomRange: String? {
        if case .custom = timeRange {
            return nil
        }
        return Localization.addCustomRange
    }

    var chartViewModel: StoreStatsChartViewModel {
        StoreStatsChartViewModel(intervals: statsIntervalData,
                                 timeRange: timeRange,
                                 currencySettings: currencySettings,
                                 currencyFormatter: currencyFormatter)
    }

    var granularityText: String? {
        guard case .custom = timeRange else {
            return nil
        }
        return timeRange.intervalGranularity.displayText
    }

    var redactedViewIcon: UIImage? {
        switch siteVisitStatMode {
        case .redactedDueToJetpack:
            UIImage.jetpackLogoImage.withRenderingMode(.alwaysTemplate)
        case .redactedDueToCustomRange:
            UIImage.infoOutlineImage.withRenderingMode(.alwaysTemplate)
        case .default, .hidden:
            nil
        }
    }

    var redactedViewIconColor: UIColor {
        siteVisitStatMode == .redactedDueToJetpack ? .jetpackGreen : .accent
    }
}

// MARK: - Private helpers
//
private extension StorePerformanceViewModel {
    func observeTimeRange() {
        $timeRange
            .compactMap { [weak self] timeRange -> StoreStatsPeriodViewModel? in
                guard let self else {
                    return nil
                }
                return StoreStatsPeriodViewModel(siteID: siteID,
                                                 timeRange: timeRange,
                                                 siteTimezone: siteTimezone,
                                                 currentDate: currentDate,
                                                 currencyFormatter: currencyFormatter,
                                                 currencySettings: currencySettings,
                                                 storageManager: storageManager)
            }
            .sink { [weak self] viewModel in
                guard let self else { return }
                periodViewModel = viewModel
                observePeriodViewModel()
                Task { [weak self] in
                    await self?.reloadData()
                }
            }
            .store(in: &subscriptions)
    }

    func observePeriodViewModel() {
        guard let periodViewModel else {
            return
        }

        periodViewModel.timeRangeBarViewModel
            .map { $0.timeRangeText }
            .assign(to: &$timeRangeText)

        periodViewModel.timeRangeBarViewModel
            .map { $0.selectedDateText }
            .assign(to: &$selectedDateText)

        periodViewModel.revenueStatsText
            .assign(to: &$revenueStatsText)

        periodViewModel.orderStatsText
            .assign(to: &$orderStatsText)

        periodViewModel.visitorStatsText
            .assign(to: &$visitorStatsText)

        periodViewModel.conversionStatsText
            .assign(to: &$conversionStatsText)

        periodViewModel.orderStatsIntervals
            .map { [weak self] intervals in
                guard let self else {
                    return []
                }
                return createOrderStatsIntervalData(orderStatsIntervals: intervals)
            }
            .assign(to: &$statsIntervalData)
    }

    func createOrderStatsIntervalData(orderStatsIntervals: [OrderStatsV4Interval]) -> [StoreStatsChartData] {
            let intervalDates = orderStatsIntervals.map { $0.dateStart(timeZone: siteTimezone) }
            let revenues = orderStatsIntervals.map { ($0.revenueValue as NSDecimalNumber).doubleValue }
            return zip(intervalDates, revenues)
                .map { x, y -> StoreStatsChartData in
                    .init(date: x, revenue: y)
                }
        }

    @MainActor
    func loadLastTimeRange() async -> StatsTimeRangeV4? {
        await withCheckedContinuation { continuation in
            let action = AppSettingsAction.loadLastSelectedPerformanceTimeRange(siteID: siteID) { timeRange in
                continuation.resume(returning: timeRange)
            }
            stores.dispatch(action)
        }
    }

    func saveLastTimeRange(_ timeRange: StatsTimeRangeV4) {
        let action = AppSettingsAction.setLastSelectedPerformanceTimeRange(siteID: siteID, timeRange: timeRange)
        stores.dispatch(action)
    }

    /// Initial redaction state logic for site visit stats.
    /// If a) Site is WordPress.com site or self-hosted site with Jetpack:
    ///       - if date range is < 2 days, we can show the visit stats (because the data will be correct)
    ///       - else, set as `.redactedDueToCustomRange`
    ///    b). Site is Jetpack CP, set as `.redactedDueToJetpack`
    ///    c). Site is a non-Jetpack site: set as `.hidden`
    func updateSiteVisitStatModeForCustomRange() {
        guard let site = stores.sessionManager.defaultSite,
              case let .custom(startDate, endDate) = timeRange else { return }

        if site.isJetpackConnected && site.isJetpackThePluginInstalled {
            let differenceInDay = StatsTimeRangeV4.differenceInDays(startDate: startDate, endDate: endDate)
            siteVisitStatMode = differenceInDay == .sameDay ? .default : .redactedDueToCustomRange
        } else if site.isJetpackCPConnected {
            siteVisitStatMode = .redactedDueToJetpack
        } else {
            siteVisitStatMode = .hidden
        }
    }

    /// Observe `chartValueSelected` events and call `StoreStatsUsageTracksEventEmitter.interacted()` when
    /// no similar events have been received after some time.
    ///
    /// We debounce it because there are just too many events received from `chartValueSelected()` when
    /// the user holds and drags on the chart. Having too many events might skew the
    /// `StoreStatsUsageTracksEventEmitter` algorithm.
    func observeChartValueSelectedEvents() {
        chartValueSelectedEventsSubject
            .debounce(for: .seconds(Constants.chartValueSelectedEventsDebounce), scheduler: DispatchQueue.main)
            .sink { [weak self] index in
                self?.handleSelectedChartValue(at: index)
            }
            .store(in: &subscriptions)
    }

    func handleSelectedChartValue(at index: Int?) {
        if timeRange.isCustomTimeRange {
            analytics.track(event: .DashboardCustomRange.interacted())
        }
        usageTracksEventEmitter.interacted()
    }
}

// MARK: - Syncing data
//
private extension StorePerformanceViewModel {
    @MainActor
    func syncAllStats() async throws {
        currentDate = Date()
        let latestDateToInclude = timeRange.latestDate(currentDate: currentDate, siteTimezone: siteTimezone)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.syncStats(latestDateToInclude: latestDateToInclude)
            }

            group.addTask { [weak self] in
                try await self?.syncSiteVisitStats(latestDateToInclude: latestDateToInclude)
            }

            group.addTask { [weak self] in
                try await self?.syncSiteSummaryStats(latestDateToInclude: latestDateToInclude)
            }

            while !group.isEmpty {
                // rethrow any failure.
                try await group.next()
            }
        }
    }

    /// Syncs store stats for dashboard UI.
    @MainActor
    func syncStats(latestDateToInclude: Date) async throws {
        let earliestDateToInclude = timeRange.earliestDate(latestDate: latestDateToInclude, siteTimezone: siteTimezone)
        try await withCheckedThrowingContinuation { continuation in
            stores.dispatch(StatsActionV4.retrieveStats(siteID: siteID,
                                                        timeRange: timeRange,
                                                        timeZone: siteTimezone,
                                                        earliestDateToInclude: earliestDateToInclude,
                                                        latestDateToInclude: latestDateToInclude,
                                                        quantity: timeRange.maxNumberOfIntervals,
                                                        forceRefresh: true,
                                                        onCompletion: { result in
                continuation.resume(with: result)
            }))
        }
    }

    /// Syncs visitor stats for dashboard UI.
    @MainActor
    func syncSiteVisitStats(latestDateToInclude: Date) async throws {
        guard stores.isAuthenticatedWithoutWPCom == false else { // Visit stats are only available for stores connected to WPCom
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            stores.dispatch(StatsActionV4.retrieveSiteVisitStats(siteID: siteID,
                                                                 siteTimezone: siteTimezone,
                                                                 timeRange: timeRange,
                                                                 latestDateToInclude: latestDateToInclude,
                                                                 onCompletion: { result in
                if case let .failure(error) = result {
                    DDLogError("⛔️ Error synchronizing visitor stats: \(error)")
                }
                continuation.resume(with: result)
            }))
        }
    }

    /// Syncs summary stats for dashboard UI.
    @MainActor
    func syncSiteSummaryStats(latestDateToInclude: Date) async throws {
        guard stores.isAuthenticatedWithoutWPCom == false else { // Summary stats are only available for stores connected to WPCom
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            stores.dispatch(StatsActionV4.retrieveSiteSummaryStats(siteID: siteID,
                                                                   siteTimezone: siteTimezone,
                                                                   period: timeRange.summaryStatsGranularity,
                                                                   quantity: 1,
                                                                   latestDateToInclude: latestDateToInclude,
                                                                   saveInStorage: true) { result in
                   if case let .failure(error) = result {
                       DDLogError("⛔️ Error synchronizing summary stats: \(error)")
                   }

                   let voidResult = result.map { _ in () } // Caller expects no entity in the result.
                continuation.resume(with: voidResult)
               })
        }
    }

    private func handleSyncError(error: Error) {
        switch error {
        case let siteStatsStoreError as SiteStatsStoreError:
            handleSiteStatsStoreError(error: siteStatsStoreError)
        default:
            onSyncingError(error)
            trackDashboardStatsSyncComplete(withError: error)
        }
    }

    func handleSiteStatsStoreError(error: SiteStatsStoreError) {
        switch error {
        case .noPermission:
            siteVisitStatMode = .hidden
            trackDashboardStatsSyncComplete()
        case .statsModuleDisabled:
            let defaultSite = stores.sessionManager.defaultSite
            if defaultSite?.isJetpackCPConnected == true {
                siteVisitStatMode = .redactedDueToJetpack
            } else {
                siteVisitStatMode = .hidden
            }
            trackDashboardStatsSyncComplete()
        default:
            onSyncingError(error)
            trackDashboardStatsSyncComplete(withError: error)
        }
    }

    /// Notifies `AppStartupWaitingTimeTracker` when dashboard sync is complete.
    ///
    func trackDashboardStatsSyncComplete(withError error: Error? = nil) {
        guard error == nil else { // Stop the tracker if there is an error.
            ServiceLocator.startupWaitingTimeTracker.end()
            return
        }
        ServiceLocator.startupWaitingTimeTracker.end(action: .syncDashboardStats)
    }
}

// MARK: Constants
//
private extension StorePerformanceViewModel {
    enum Constants {
        static let thirtyDaysInSeconds: TimeInterval = 86400*30

        /// The wait time before the `StoreStatsUsageTracksEventEmitter.interacted()` is called.
        static let chartValueSelectedEventsDebounce: TimeInterval = 0.5
    }
    enum Localization {
        static let addCustomRange = NSLocalizedString(
            "storePerformanceViewModel.addCustomRange",
            value: "Add",
            comment: "Button in date range picker to add a Custom Range tab"
        )
    }
}
