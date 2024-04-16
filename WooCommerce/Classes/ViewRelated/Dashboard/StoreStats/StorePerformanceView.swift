import SwiftUI
import enum Yosemite.StatsTimeRangeV4

/// View for store performance on Dashboard screen
///
struct StorePerformanceView: View {
    @ObservedObject private var viewModel: StorePerformanceViewModel
    @State private var showingCustomRangePicker = false

    var statsValueColor: Color {
        Color(viewModel.shouldHighlightStats ? .statsHighlighted : .text)
    }

    private let onCustomRangeRedactedViewTap: () -> Void
    private let onViewAllAnalytics: (_ siteID: Int64,
                                     _ timeZone: TimeZone,
                                     _ timeRange: StatsTimeRangeV4) -> Void

    init(viewModel: StorePerformanceViewModel,
         onCustomRangeRedactedViewTap: @escaping () -> Void,
         onViewAllAnalytics: @escaping (Int64, TimeZone, StatsTimeRangeV4) -> Void) {
        self.viewModel = viewModel
        self.onCustomRangeRedactedViewTap = onCustomRangeRedactedViewTap
        self.onViewAllAnalytics = onViewAllAnalytics
    }

    var body: some View {
        if viewModel.statsVersion == .v4 {
            VStack(alignment: .leading) {
                header
                    .padding(.horizontal, Layout.padding)
                    .redacted(reason: viewModel.syncingData ? [.placeholder] : [])
                    .shimmering(active: viewModel.syncingData)

                timeRangeBar
                    .padding(.horizontal, Layout.padding)
                    .redacted(reason: viewModel.syncingData ? [.placeholder] : [])
                    .shimmering(active: viewModel.syncingData)

                Divider()

                statsView
                    .padding(.vertical, Layout.padding)
                    .redacted(reason: viewModel.syncingData ? [.placeholder] : [])
                    .shimmering(active: viewModel.syncingData)

                chartView
                    .redacted(reason: viewModel.syncingData ? [.placeholder] : [])
                    .shimmering(active: viewModel.syncingData)

                Divider()

                viewAllAnalyticsButton
                    .padding([.top, .horizontal], Layout.padding)
                    .redacted(reason: viewModel.syncingData ? [.placeholder] : [])
                    .shimmering(active: viewModel.syncingData)

            }
            .padding(.vertical, Layout.padding)
            .background(Color(.listForeground(modal: false)))
            .clipShape(RoundedRectangle(cornerSize: Layout.cornerSize))
            .padding(.horizontal, Layout.padding)
            .sheet(isPresented: $showingCustomRangePicker) {
                RangedDatePicker(startDate: viewModel.startDateForCustomRange,
                                 endDate: viewModel.endDateForCustomRange,
                                 datesFormatter: DatesFormatter(),
                                 customApplyButtonTitle: viewModel.buttonTitleForCustomRange,
                                 datesSelected: { start, end in
                    viewModel.didSelectTimeRange(.custom(from: start, to: end))
                })
            }
        } else {
            ViewControllerContainer(DeprecatedDashboardStatsViewController())
        }
    }
}

private extension StorePerformanceView {
    var header: some View {
        HStack(alignment: .top) {
            Text(Localization.title)
                .headlineStyle()
            Spacer()
            Menu {
                Button(Localization.hideCard) {
                    // TODO
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    var timeRangeBar: some View {
        HStack(alignment: .top) {
            AdaptiveStack {
                Text(viewModel.timeRange.tabTitle)
                    .foregroundStyle(Color(.text))
                    .subheadlineStyle()
                if let selectedDateText = viewModel.selectedDateText {
                    Text(selectedDateText)
                        .subheadlineStyle()
                } else {
                    Text(viewModel.timeRangeText)
                        .subheadlineStyle()
                }
            }
            Spacer()
            StatsTimeRangePicker(currentTimeRange: viewModel.timeRange) { newTimeRange in
                if newTimeRange.isCustomTimeRange {
                    showingCustomRangePicker = true
                } else {
                    viewModel.didSelectTimeRange(newTimeRange)
                }
            }
        }
    }

    var statsView: some View {
        VStack(spacing: Layout.padding) {
            VStack(spacing: Layout.statValuePadding) {
                Text(viewModel.revenueStatsText)
                    .fontWeight(.semibold)
                    .foregroundStyle(statsValueColor)
                    .largeTitleStyle()

                Text(Localization.revenue)
                    .font(Font(StyleManager.statsTitleFont))
            }

            HStack(alignment: .bottom) {
                statsItemView(title: Localization.orders,
                              value: viewModel.orderStatsText,
                              redactMode: .none)
                    .frame(maxWidth: .infinity)

                statsItemView(title: Localization.visitors,
                              value: viewModel.visitorStatsText,
                              redactMode: .withIcon)
                    .frame(maxWidth: .infinity)

                statsItemView(title: Localization.conversion,
                              value: viewModel.conversionStatsText,
                              redactMode: .withoutIcon)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    func statsItemView(title: String, value: String, redactMode: RedactMode) -> some View {
        VStack(spacing: Layout.statValuePadding) {
            if redactMode == .none || viewModel.siteVisitStatMode == .default {
                Text(value)
                    .font(Font(StyleManager.statsFont))
                    .foregroundStyle(statsValueColor)
            } else {
                statValueRedactedView(withIcon: redactMode == .withIcon)
            }
            Text(title)
                .font(Font(StyleManager.statsTitleFont))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard redactMode != .none,
                viewModel.unavailableVisitStatsDueToCustomRange,
                viewModel.siteVisitStatMode == .redactedDueToCustomRange else {
                return
            }
            onCustomRangeRedactedViewTap()
        }
    }

    func statValueRedactedView(withIcon: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Group {
                if let image = viewModel.redactedViewIcon, withIcon {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(Color(viewModel.redactedViewIconColor))
                } else {
                    EmptyView()
                }
            }
            .frame(width: Layout.redactedViewIconSize, height: Layout.redactedViewIconSize)
            .offset(Layout.redactedViewIconOffset)

            Color(.systemColor(.secondarySystemBackground))
                .frame(width: Layout.redactedViewWidth, height: Layout.redactedViewHeight)
                .clipShape(RoundedRectangle(cornerSize: Layout.redactedViewCornerSize))
        }
    }

    var chartView: some View {
        VStack {
            StoreStatsChart(viewModel: viewModel.chartViewModel) { selectedIndex in
                viewModel.didSelectStatsInterval(at: selectedIndex)
            }
            .frame(height: Layout.chartViewHeight)

            if let granularityText = viewModel.granularityText {
                Text(granularityText)
                    .font(Font(StyleManager.statsTitleFont))
            }
        }
    }

    var viewAllAnalyticsButton: some View {
        Button {
            onViewAllAnalytics(viewModel.siteID, viewModel.siteTimezone, viewModel.timeRange)
        } label: {
            HStack {
                Text(Localization.viewAll)
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.secondary)
                    .fontWeight(.semibold)
            }
        }
    }
}

private extension StorePerformanceView {
    /// Redact modes for stat values.
    enum RedactMode {
        case none
        case withIcon
        case withoutIcon
    }

    enum Layout {
        static let padding: CGFloat = 16
        static let cornerSize = CGSize(width: 8.0, height: 8.0)
        static let strokeWidth: CGFloat = 0.5
        static let chartViewHeight: CGFloat = 176
        static let statValuePadding: CGFloat = 8
        static let redactedViewCornerSize = CGSize(width: 2.0, height: 2.0)
        static let redactedViewWidth: CGFloat = 32
        static let redactedViewHeight: CGFloat = 10
        static let redactedViewIconSize: CGFloat = 14
        static let redactedViewIconOffset = CGSize(width: 16, height: 0)
    }

    enum Localization {
        static let title = NSLocalizedString(
            "storePerformanceView.title",
            value: "Performance",
            comment: "Title of the store performance section on the Dashboard screen"
        )
        static let hideCard = NSLocalizedString(
            "storePerformanceView.hideCard",
            value: "Hide this card",
            comment: "Menu item to dismiss the store performance section on the Dashboard screen"
        )
        static let revenue = NSLocalizedString(
            "storePerformanceView.revenue",
            value: "Revenue",
            comment: "Revenue stat label on dashboard."
        )
        static let orders = NSLocalizedString(
            "storePerformanceView.orders",
            value: "Orders",
            comment: "Orders stat label on dashboard - should be plural."
        )
        static let visitors = NSLocalizedString(
            "storePerformanceView.visitors",
            value: "Visitors",
            comment: "Visitors stat label on dashboard - should be plural."
        )
        static let conversion = NSLocalizedString(
            "storePerformanceView.conversion",
            value: "Conversion",
            comment: "Conversion stat label on dashboard."
        )
        static let viewAll = NSLocalizedString(
            "storePerformanceView.viewAll",
            value: "View all store analytics",
            comment: "Button to navigate to Analytics Hub."
        )
    }

    /// Specific `DatesFormatter` for the `RangedDatePicker` when presented in the analytics hub module.
    ///
    struct DatesFormatter: RangedDateTextFormatter {
        func format(start: Date, end: Date) -> String {
            start.formatAsRange(with: end, timezone: .current, calendar: Locale.current.calendar)
        }
    }
}

#Preview {
    StorePerformanceView(viewModel: StorePerformanceViewModel(siteID: 123,
                                                              usageTracksEventEmitter: .init()),
                         onCustomRangeRedactedViewTap: {},
                         onViewAllAnalytics: { _, _, _ in })
}
