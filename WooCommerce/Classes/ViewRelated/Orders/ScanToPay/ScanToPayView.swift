import SwiftUI
import WooFoundation

struct ScanToPayView: View {
    let viewModel: ScanToPayViewModel
    let onSuccess: (() -> Void)

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(Layout.backgroundOpacity).edgesIgnoringSafeArea(.all)
            VStack {
                VStack(alignment: .center, spacing: Layout.scanToPayBoxSpacing) {
                    if let qrCodeImage = viewModel.generateQRCodeImage() {
                        Text(Localization.title)
                            .foregroundColor(.white)
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: Layout.qrCodeWidth, height: Layout.qrCodeHeight)
                        DoneButton() {
                            onSuccess()
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text(Localization.errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        DoneButton() {
                            dismiss()
                        }
                    }
                }
                .padding(Layout.scanToPayBoxSpacing)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color(.gray(.shade70)))
                .cornerRadius(Layout.scanToPayBoxCornerRadius)

            }
            .padding(Layout.scanToPayBoxOutterPadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private struct DoneButton: View {
        let onButtonTapped: (() -> Void)
        var body: some View {
            Button(Localization.doneButtontitle) {
                onButtonTapped()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

extension ScanToPayView {
    enum Localization {
        static let title = NSLocalizedString("Scan QR and follow instructions", comment: "Title text on the Scan to Pay screen")
        static let doneButtontitle = NSLocalizedString("Done", comment: "Button title to close the Scan to Pay screen")
        static let errorMessage = NSLocalizedString("Error generating QR Code. Please try again later",
                                                    comment: "Error message in the Scan to Pay screen when the code cannot be generated.")
    }

    enum Layout {
        static let backgroundOpacity: CGFloat = 0.5
        static let scanToPayBoxSpacing: CGFloat = 20
        static let qrCodeWidth: CGFloat = 270
        static let qrCodeHeight: CGFloat = 300
        static let scanToPayBoxCornerRadius: CGFloat = 8
        static let scanToPayBoxOutterPadding: CGFloat = 50
    }
}
