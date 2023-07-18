import Foundation
import SwiftUI

struct FullFeatureListView: View {
    @Environment(\.presentationMode) var presentationMode

    var featureListGroups = FullFeatureListViewModel.hardcodedFullFeatureList()

    var body: some View {
        ScrollView() {
            VStack(alignment: .leading, spacing: FullFeatureListView.Layout.featureListSpacing) {
                ForEach(featureListGroups, id: \.title) { featureList in
                    Text(featureList.title)
                        .font(.title)
                        .bold()
                        .padding(.top)
                        .padding(.bottom)
                    ForEach(featureList.essentialFeatures, id: \.self) { feature in
                        Text(feature)
                            .font(.body)
                    }
                    ForEach(featureList.performanceFeatures, id: \.self) { feature in
                        HStack {
                            Text(feature)
                                .font(.body)
                            Image(systemName: "star.fill")
                                .foregroundColor(.withColorStudio(name: .wooCommercePurple, shade: .shade50))
                                .font(.footnote)
                        }
                    }
                    Divider()
                        .padding(.top)
                        .padding(.bottom)
                    HStack {
                        Image(systemName: "star.fill")
                        Text(Localization.performanceOnlyText)
                    }
                    .font(.footnote)
                    .foregroundColor(.withColorStudio(name: .wooCommercePurple, shade: .shade50))
                    .padding(.bottom)
                    .renderedIf(featureList.performanceFeatures.isNotEmpty)
                }
            }
            .padding(.horizontal)
            .background(Color(.white))
            .cornerRadius(Layout.featureListCornerRadius)
            VStack(alignment: .leading, spacing: Layout.featureListSpacing) {
                Text(Localization.paymentsDisclaimerText)
                    .font(.caption)
                Text(Localization.pluginsDisclaimerText)
                    .font(.caption)
            }
            .background(Color(.secondarySystemBackground))
        }
        .padding()
        .navigationTitle(Localization.featureListTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
        })
        .background(Color(.secondarySystemBackground))
    }
}

private extension FullFeatureListView {
    struct Localization {
        static let featureListTitleText = NSLocalizedString(
            "Full Feature List",
            comment: "")

        static let performanceOnlyText = NSLocalizedString(
            "Performance plan only",
            comment: "")

        static let paymentsDisclaimerText = NSLocalizedString(
            "1. Available as standard in WooCommerce Payments (restrictions apply)." +
            "Additional extensions may be required for other payment providers." ,
            comment: "")

        static let pluginsDisclaimerText = NSLocalizedString(
            "2. Only available in the U.S. – an additional extension will be required for other countries.",
            comment: "")
    }

    struct Layout {
        static let featureListSpacing: CGFloat = 16.0
        static let featureListCornerRadius: CGFloat = 10.0
    }
}
