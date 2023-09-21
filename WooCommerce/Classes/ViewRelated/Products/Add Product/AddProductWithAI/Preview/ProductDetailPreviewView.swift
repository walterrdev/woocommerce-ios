import SwiftUI

/// View for previewing product details generated with AI.
///
struct ProductDetailPreviewView: View {

    @ObservedObject private var viewModel: ProductDetailPreviewViewModel

    init(viewModel: ProductDetailPreviewViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.blockVerticalSpacing) {
                VStack(alignment: .leading, spacing: Layout.titleBlockSpacing) {
                    // Title label.
                    Text(Localization.title)
                        .fontWeight(.bold)
                        .titleStyle()

                    // Subtitle label.
                    Text(Localization.subtitle)
                        .foregroundColor(Color(.secondaryLabel))
                        .bodyStyle()
                }
            }
            .padding(insets: Layout.insets)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isGeneratingDetails {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    } else {
                        Button("Save as draft") {
                            viewModel.saveProductAsDraft()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.generateProductDetails()
            }
        }
    }
}

private extension ProductDetailPreviewView {
    enum Layout {
        static let insets: EdgeInsets = .init(top: 24, leading: 16, bottom: 16, trailing: 16)

        static let blockVerticalSpacing: CGFloat = 40
        static let titleBlockSpacing: CGFloat = 16
    }
    enum Localization {
        static let title = NSLocalizedString(
            "Preview",
            comment: "Title on the add product with AI Preview screen."
        )
        static let subtitle = NSLocalizedString(
            "Don't worry. You can always change those details later.",
            comment: "Subtitle on the add product with AI Preview screen."
        )
    }
}


struct ProductDetailPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetailPreviewView(viewModel: .init(siteID: 123))
    }
}
