import Foundation
import UIKit
import SwiftUI

/// Hosting Controller for the Privacy Banner View
///
final class PrivacyBannerViewController: UIHostingController<PrivacyBanner> {
    init() {
        super.init(rootView: PrivacyBanner())
    }

    /// Needed for protocol conformance.
    ///
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

/// Banner View for the privacy settings.
///
struct PrivacyBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.mainVerticalSpacing) {

            Text(Localization.bannerTitle)
                .headlineStyle()

            Text(Localization.bannerSubtitle)
                .foregroundColor(Color(.text))
                .subheadlineStyle()

            Toggle(Localization.analytics, isOn: .constant(true))
                .tint(Color(.primary))
                .bodyStyle()
                .padding(.vertical)

            Text(Localization.toggleSubtitle)
                .subheadlineStyle()

            HStack {
                Button(Localization.goToSettings) {
                    print("Tapped Settings")
                }
                .buttonStyle(SecondaryButtonStyle())


                Button(Localization.save) {
                    print("Tapped Save")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.vertical)
        }
        .padding()
    }
}

// MARK: Definitions
private extension PrivacyBanner {
    enum Localization {
        static let bannerTitle = NSLocalizedString("Manage Privacy", comment: "Title for the privacy banner")
        static let analytics = NSLocalizedString("Analytics", comment: "Title for the analytics toggle in the privacy banner")
        static let goToSettings = NSLocalizedString("Go to Settings", comment: "Title for the 'Go To Settings' button in the privacy banner")
        static let save = NSLocalizedString("Save", comment: "Title for the 'Save' button in the privacy banner")
        static let bannerSubtitle = NSLocalizedString(
            "We process your personal data to optimize our mobile apps and marketing activities based on your consent and our legitimate interest.",
            comment: "Title for the privacy banner"
        )
        static let toggleSubtitle = NSLocalizedString(
            "These cookies allow us to optimize performance by collecting information on how users interact with our mobile apps.",
            comment: "Description for the analytics toggle in the privacy banner"
        )
    }

    enum Layout {
        static let mainVerticalSpacing = CGFloat(8)
    }
}

struct PrivacyBanner_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyBanner()
            .previewLayout(.sizeThatFits)
    }
}
