import SwiftUI

final class ThemeSettingHostingController: UIHostingController<ThemeSettingView> {
    init(siteID: Int64) {
        let viewModel = ThemeSettingViewModel(siteID: siteID)
        super.init(rootView: ThemeSettingView(viewModel: viewModel))

        rootView.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// View for selecting a new theme for the current site.
///
struct ThemeSettingView: View {

    @ObservedObject private var viewModel: ThemeSettingViewModel

    /// Triggered when the Cancel button is tapped.
    /// To be update from the hosting controller.
    var onDismiss: () -> Void = {}

    init(viewModel: ThemeSettingViewModel) {
        self.viewModel = viewModel
        Task {
            await viewModel.updateCurrentThemeName()
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(Localization.currentSection) {
                    AdaptiveStack(horizontalAlignment: .leading) {
                        Text(Localization.themeRow)
                            .bodyStyle()
                        Spacer()
                        if viewModel.loadingCurrentTheme {
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)
                        } else {
                            Text(viewModel.currentThemeName)
                                .secondaryBodyStyle()
                        }
                    }
                }

                Section(Localization.tryOtherLook) {
                    VStack {
                        Spacer()
                        ThemesCarouselView(
                            lastMessageHeading: Localization.lastMessageHeading,
                            lastMessageContent: Localization.lastMessageContent
                        )
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.cancelButton, action: onDismiss)
                }
            }
            .navigationTitle(Localization.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension ThemeSettingView {
    enum Localization {
        static let title = NSLocalizedString(
            "themeSettingView.title",
            value: "Themes",
            comment: "Title for the theme settings screen"
        )

        static let currentSection = NSLocalizedString(
            "themeSettingView.currentSection",
            value: "Current",
            comment: "Title for the Current section on the theme settings screen"
        )

        static let themeRow = NSLocalizedString(
            "themeSettingView.themeRow",
            value: "Theme",
            comment: "Title for the Theme row on the theme settings screen"
        )

        static let tryOtherLook = NSLocalizedString(
            "themeSettingView.tryOtherLookLabel",
            value: "Try other new look",
            comment: "Label for the suggested theme section on the theme settings screen"
        )

        static let cancelButton = NSLocalizedString(
            "themeSettingView.cancelButton",
            value: "Cancel",
            comment: "Button to dismiss the theme settings screen"
        )

        static let lastMessageHeading = NSLocalizedString(
            "themeSettingView.lastMessageHeading",
            value: "Looking for more?",
            comment: "The heading of the message shown at the end of the carousel on the theme settings screen"
        )

        static let lastMessageContent = NSLocalizedString(
            "themeSettingView.lastMessageContent",
            value: "Find your perfect theme in the WooCommerce Theme Store.",
            comment: "The content of the message shown at the end of the carousel on the theme settings screen"
        )
    }
}

struct ThemeSettingView_Previews: PreviewProvider {

    static var previews: some View {
        ThemeSettingView(viewModel: .init(siteID: 123))
    }
}
