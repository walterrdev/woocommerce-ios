import SwiftUI

struct AnalyticsHubCustomizeView: View {
    @ObservedObject var viewModel: AnalyticsHubCustomizeViewModel

    @State private var selectedPromoURL: URL?

    /// Dismisses the view.
    ///
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            MultiSelectionReorderableList(contents: $viewModel.allCards,
                                          contentKeyPath: \.name,
                                          selectedItems: $viewModel.selectedCards,
                                          disabledItems: viewModel.excludedCards,
                                          disabledAccessoryView: { card in
                Button {
                    selectedPromoURL = viewModel.promoURL(for: card)
                } label: {
                    Text("Explore") // TODO-12161: Show localized label with background
                }
            })
                .toolbar(content: {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            viewModel.saveChanges()
                            dismiss()
                        } label: {
                            Text(Localization.saveButton)
                        }
                        .disabled(!viewModel.hasChanges)
                    }
                })
        }
        .navigationTitle(Localization.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .listBackground))
        .wooNavigationBarStyle()
        .closeButtonWithDiscardChangesPrompt(hasChanges: viewModel.hasChanges)
        .sheet(item: $selectedPromoURL) { url in
            WebViewSheet(viewModel: .init(url: url, navigationTitle: "", authenticated: false), done: {
                selectedPromoURL = nil
            })
        }
    }
}

// MARK: - Constants
private extension AnalyticsHubCustomizeView {
    enum Localization {
        static let title = NSLocalizedString("analyticsHub.customizeAnalytics.title",
                                             value: "Customize Analytics",
                                             comment: "Title for the screen to customize the analytics cards in the Analytics Hub")
        static let saveButton = NSLocalizedString("analyticsHub.customizeAnalytics.saveButton",
                                                  value: "Save",
                                                  comment: "Button to save changes on the Customize Analytics screen")
    }
}

#Preview {
    NavigationView {
        AnalyticsHubCustomizeView(viewModel: AnalyticsHubCustomizeViewModel(allCards: AnalyticsHubCustomizeViewModel.sampleCards))
    }
}
