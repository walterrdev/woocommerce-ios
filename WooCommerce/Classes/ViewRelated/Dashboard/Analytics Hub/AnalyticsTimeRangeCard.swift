import SwiftUI

/// Reusable Time Range card made for the Analytics Hub.
///
struct AnalyticsTimeRangeCard: View {

    let timeRangeTitle: String
    let currentRangeDescription: String
    let previousRangeDescription: String
    @Binding var selectionType: AnalyticsHubTimeRangeSelection.SelectionType

    @State private var showTimeRangeSelectionView: Bool = false

    init(viewModel: AnalyticsTimeRangeCardViewModel, selectionType: Binding<AnalyticsHubTimeRangeSelection.SelectionType>) {
        self.timeRangeTitle = viewModel.selectedRangeTitle
        self.currentRangeDescription = viewModel.currentRangeSubtitle
        self.previousRangeDescription = viewModel.previousRangeSubtitle
        self._selectionType = selectionType
    }

    var body: some View {
        createTimeRangeContent()
            .sheet(isPresented: $showTimeRangeSelectionView) {
                SelectionList(title: Localization.timeRangeSelectionTitle,
                              items: AnalyticsHubTimeRangeSelection.SelectionType.allCases,
                              contentKeyPath: \.description,
                              selected: $selectionType) { selection in
                    ServiceLocator.analytics.track(event: .AnalyticsHub.dateRangeOptionSelected(selection.rawValue))
                }
            }
    }

    private func createTimeRangeContent() -> some View {
        VStack(alignment: .leading, spacing: Layout.verticalSpacing) {
            Button(action: {
                ServiceLocator.analytics.track(event: .AnalyticsHub.dateRangeButtonTapped())
                showTimeRangeSelectionView.toggle()
            }, label: {
                HStack {
                    Image(uiImage: .calendar)
                        .padding()
                        .foregroundColor(Color(.text))
                        .background(Circle().foregroundColor(Color(.systemGray6)))

                    VStack(alignment: .leading, spacing: .zero) {
                        Text(timeRangeTitle)
                            .foregroundColor(Color(.text))
                            .subheadlineStyle()

                        Text(currentRangeDescription)
                            .foregroundColor(Color(.text))
                            .bold()
                    }
                    .padding(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(uiImage: .chevronDownImage)
                        .padding()
                        .foregroundColor(Color(.text))
                        .frame(alignment: .trailing)
                }
            })
            .buttonStyle(.borderless)
            .padding(.leading)
            .contentShape(Rectangle())

            Divider()

            BoldableTextView(Localization.comparisonHeaderTextWith(previousRangeDescription))
                .padding(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .calloutStyle()
        }
        .padding([.top, .bottom])
        .frame(maxWidth: .infinity)
    }
}

// MARK: Constants
private extension AnalyticsTimeRangeCard {
    enum Layout {
        static let verticalSpacing: CGFloat = 16
    }

    enum Localization {
        static let timeRangeSelectionTitle = NSLocalizedString(
            "Date Range",
            comment: "Title describing the possible date range selections of the Analytics Hub"
        )
        static let previousRangeComparisonContent = NSLocalizedString(
            "Compared to **%1$@**",
            comment: "Subtitle describing the previous analytics period under comparison. E.g. Compared to Oct 1 - 22, 2022"
        )

        static func comparisonHeaderTextWith(_ rangeDescription: String) -> String {
            return String.localizedStringWithFormat(Localization.previousRangeComparisonContent, rangeDescription)
        }
    }
}

// MARK: Previews
struct TimeRangeCard_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AnalyticsTimeRangeCardViewModel(selectedRangeTitle: "Month to Date",
                                                        currentRangeSubtitle: "Nov 1 - 23, 2022",
                                                        previousRangeSubtitle: "Oct 1 - 23, 2022")
        AnalyticsTimeRangeCard(viewModel: viewModel, selectionType: .constant(.monthToDate))
    }
}
