import SwiftUI
import struct Yosemite.Product

final class ProductSharingMessageGenerationHostingController: UIHostingController<ProductSharingMessageGenerationView> {
    init(productName: String,
         url: String,
         onShareMessage: @escaping (String) -> Void,
         onDismiss: @escaping () -> Void,
         onSkip: @escaping () -> Void) {
        let viewModel = ProductSharingMessageGenerationViewModel(productName: productName, url: url)
        super.init(rootView: ProductSharingMessageGenerationView(viewModel: viewModel,
                                                                 onShareMessage: onShareMessage,
                                                                 onDismiss: onDismiss,
                                                                 onSkip: onSkip))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// View for generating product sharing message with AI.
struct ProductSharingMessageGenerationView: View {
    @ObservedObject private var viewModel: ProductSharingMessageGenerationViewModel
    private let onShareMessage: (String) -> Void
    private let onDismiss: () -> Void
    private let onSkip: () -> Void

    init(viewModel: ProductSharingMessageGenerationViewModel,
         onShareMessage: @escaping (String) -> Void,
         onDismiss: @escaping () -> Void,
         onSkip: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onShareMessage = onShareMessage
        self.onDismiss = onDismiss
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(alignment: .center, spacing: Layout.defaultSpacing) {

            // Generated message text field
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.messageContent)
                    .bodyStyle()
                    .foregroundColor(.secondary)
                    .background(.clear)
                    .disabled(viewModel.generationInProgress)
                    .padding(insets: Layout.messageContentInsets)
                    .frame(minHeight: Layout.minimumEditorSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius).stroke(Color(.separator))
                    )

                // Loading state text
                Text(Localization.generating)
                    .foregroundColor(Color(.placeholderText))
                    .bodyStyle()
                    .padding(insets: Layout.placeholderInsets)
                    // Allows gestures to pass through to the `TextEditor`.
                    .allowsHitTesting(false)
                    .frame(alignment: .center)
                    .renderedIf(viewModel.generationInProgress)
            }

            Button(Localization.shareMessage) {
                onShareMessage(viewModel.messageContent)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(Localization.skip) {
                onSkip()
            }
            .buttonStyle(LinkButtonStyle())
        }
        .padding(insets: Layout.insets)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.viewTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Localization.dismiss, action: onDismiss)
                    .foregroundColor(Color(.accent))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    // TODO
                }, label: {
                    Image(systemName: "arrow.counterclockwise")
                })
                .foregroundColor(Color(.accent))
            }
        }
    }
}

private extension ProductSharingMessageGenerationView {
    enum Layout {
        static let defaultSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let insets: EdgeInsets = .init(top: 24, leading: 16, bottom: 16, trailing: 16)
        static let minimumEditorSize: CGFloat = 76
        static let messageContentInsets: EdgeInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
        static let placeholderInsets: EdgeInsets = .init(top: 18, leading: 16, bottom: 18, trailing: 16)
    }
    enum Localization {
        static let generating = NSLocalizedString(
            "🪄 Generating share message...",
            comment: "Text showing the loading state of the product sharing message generation screen"
        )
        static let shareMessage = NSLocalizedString(
            "Share message",
            comment: "Action button to share the generated message on the product sharing message generation screen"
        )
        static let skip = NSLocalizedString(
            "Skip to share link only",
            comment: "Action button to skip the generated message on the product sharing message generation screen"
        )
        static let dismiss = NSLocalizedString("Dismiss", comment: "Button to dismiss the product sharing message generation screen")
    }
}

struct ProductSharingMessageGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        ProductSharingMessageGenerationView(viewModel: .init(productName: "Test",
                                                             url: "https://example.com"),
                                            onShareMessage: { _ in },
                                            onDismiss: {},
                                            onSkip: {})
    }
}
