import SwiftUI
import enum Yosemite.StatsTimeRangeV4

/// SwiftUI view for the Top Performers dashboard card.
///
struct TopPerformersDashboardView: View {
    @ObservedObject private var viewModel: TopPerformersDashboardViewModel
    @State private var showingCustomRangePicker = false

    private let onViewAllAnalytics: (_ siteID: Int64,
                                     _ timeZone: TimeZone,
                                     _ timeRange: StatsTimeRangeV4) -> Void

    init(viewModel: TopPerformersDashboardViewModel,
         onViewAllAnalytics: @escaping (Int64, TimeZone, StatsTimeRangeV4) -> Void) {
        self.viewModel = viewModel
        self.onViewAllAnalytics = onViewAllAnalytics
    }

    var body: some View {
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

            // TODO

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
    }
}

private extension TopPerformersDashboardView {
    var header: some View {
        HStack {
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
                    .padding(.leading, Layout.padding)
                    .padding(.vertical, Layout.hideIconVerticalPadding)
            }
            .disabled(viewModel.syncingData)
        }
    }

    var timeRangeBar: some View {
        HStack {
            AdaptiveStack(horizontalAlignment: .leading) {
                Text(viewModel.timeRange.tabTitle)
                    .foregroundStyle(Color(.text))
                    .subheadlineStyle()

                Text(viewModel.timeRangeText)
                    .subheadlineStyle()
            }
            Spacer()
            StatsTimeRangePicker(currentTimeRange: viewModel.timeRange) { newTimeRange in
                if newTimeRange.isCustomTimeRange {
                    showingCustomRangePicker = true
                } else {
                    viewModel.didSelectTimeRange(newTimeRange)
                }
            }
            .disabled(viewModel.syncingData)
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

private extension TopPerformersDashboardView {
    enum Layout {
        static let padding: CGFloat = 16
        static let cornerSize = CGSize(width: 8.0, height: 8.0)
        static let hideIconVerticalPadding: CGFloat = 8
    }

    enum Localization {
        static let title = NSLocalizedString(
            "topPerformersDashboardView.title",
            value: "Top Performers",
            comment: "Title of the Top Performers section on the Dashboard screen"
        )
        static let hideCard = NSLocalizedString(
            "topPerformersDashboardView.hideCard",
            value: "Hide Performance",
            comment: "Menu item to dismiss the Top Performers section on the Dashboard screen"
        )
        static let viewAll = NSLocalizedString(
            "topPerformersDashboardView.viewAll",
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
    TopPerformersDashboardView(viewModel: .init(siteID: 123, usageTracksEventEmitter: .init()),
                               onViewAllAnalytics: { _, _, _ in })
}
