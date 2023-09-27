import SwiftUI

/// Allows the user to enter a gift card code.
struct GiftCardInputView: View {
    @StateObject private var viewModel: GiftCardInputViewModel
    @State private var showsScanner: Bool = false

    init(viewModel: GiftCardInputViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(Localization.header)
                        .foregroundColor(.init(uiColor: .text))
                        .subheadlineStyle()
                    HStack {
                        TextField(Localization.placeholder, text: $viewModel.code)
                            .focused()
                            .textFieldStyle(RoundedBorderTextFieldStyle(focused: true))
                        Spacer()
                        Button {
                            showsScanner = true
                        } label: {
                            Image(uiImage: .scanImage.withRenderingMode(.alwaysTemplate))
                                .foregroundColor(Color(.accent))
                        }
                        .sheet(isPresented: $showsScanner) {
                            GiftCardCodeScannerNavigationView(onCodeScanned: { code in
                                viewModel.code = code
                                showsScanner = false
                            }, onClose: {
                                showsScanner = false
                            })
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(Color(.error))
                    }
                }
            }
            .padding(Constants.insets)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.cancel, action: {
                        viewModel.cancel()
                    })
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(Localization.apply, action: {
                        viewModel.apply()
                    })
                }
            }
            .navigationTitle(Localization.title)
            .navigationBarTitleDisplayMode(.inline)
            .wooNavigationBarStyle()
        }
    }
}

private extension GiftCardInputView {
    enum Localization {
        static let title = NSLocalizedString("Add Gift Card", comment: "Title of the add gift card screen in the order form.")
        static let header = NSLocalizedString("Gift card code", comment: "Header of the gift card code text field in the order form.")
        static let placeholder = NSLocalizedString("XXXX-XXXX-XXXX-XXXX", comment: "Placeholder of the gift card code text field in the order form.")
        static let apply = NSLocalizedString("Apply", comment: "Button to apply the gift card code to the order form.")
        static let cancel = NSLocalizedString("Cancel", comment: "Button to cancel entering the gift card code from the order form.")
    }

    enum Constants {
        static let insets: EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    }
}

struct GiftCardInputView_Previews: PreviewProvider {
    static var previews: some View {
        GiftCardInputView(viewModel: .init(code: "", addGiftCard: { _ in }, dismiss: {}))
    }
}
