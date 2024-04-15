import SwiftUI

/// View for store performance on Dashboard screen
///
struct StorePerformanceView: View {
    @ObservedObject private var viewModel: StorePerformanceViewModel
    @State private var showingCustomRangePicker = false
    @State private var shouldHighlightStats = false

    var statsValueColor: Color {
        Color(shouldHighlightStats ? .statsHighlighted : .text)
    }

    init(viewModel: StorePerformanceViewModel) {
        self.viewModel = viewModel
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
        }
    }

    var statsView: some View {
        VStack(spacing: Layout.padding) {
            VStack {
                Text(viewModel.revenueStatsText)
                    .fontWeight(.semibold)
                    .foregroundStyle(statsValueColor)
                    .largeTitleStyle()

                Text(Localization.revenue)
                    .font(Font(StyleManager.statsTitleFont))
            }

            HStack {
                statsItemView(title: Localization.orders, value: viewModel.orderStatsText)
                    .frame(maxWidth: .infinity)

                statsItemView(title: Localization.visitors, value: viewModel.visitorStatsText)
                    .frame(maxWidth: .infinity)

                statsItemView(title: Localization.conversion, value: viewModel.conversionStatsText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    func statsItemView(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(Font(StyleManager.statsFont))
                .foregroundStyle(statsValueColor)
            Text(title)
                .font(Font(StyleManager.statsTitleFont))
        }
    }

    var chartView: some View {
        StoreStatsChart(viewModel: viewModel.chartViewModel) { selectedIndex in
            viewModel.didSelectStatsInterval(at: selectedIndex)
            shouldHighlightStats = selectedIndex != nil
        }
        .frame(height: Layout.chartViewHeight)
    }
}

private extension StorePerformanceView {
    enum Layout {
        static let padding: CGFloat = 16
        static let cornerSize = CGSize(width: 8.0, height: 8.0)
        static let strokeWidth: CGFloat = 0.5
        static let chartViewHeight: CGFloat = 176
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
    StorePerformanceView(viewModel: StorePerformanceViewModel(siteID: 123))
}
