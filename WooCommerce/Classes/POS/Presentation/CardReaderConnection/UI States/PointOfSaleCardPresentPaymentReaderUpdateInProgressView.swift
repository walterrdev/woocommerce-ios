import SwiftUI

struct PointOfSaleCardPresentPaymentReaderUpdateInProgressView: View {
    private let viewModel: PointOfSaleCardPresentPaymentUpdatingReaderAlertViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PointOfSaleCardPresentPaymentUpdatingReaderAlertViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Text(viewModel.title)

            viewModel.image

            Text(viewModel.progressTitle)
            if let progressSubtitle = viewModel.progressSubtitle {
                Text(progressSubtitle)
            }

            Button(viewModel.cancelButtonTitle,
                   action: {
                if let cancelReaderUpdate = viewModel.cancelReaderUpdate {
                    cancelReaderUpdate()
                } else {
                    dismiss()
                }
            })
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

#if DEBUG

struct CardPresentPaymentReaderUpdateInProgressPreviewView: View {
    @State var showsSheet = false

    var body: some View {
        VStack {
            Button("Open view") {
                showsSheet = true
            }
        }
        .sheet(isPresented: $showsSheet) {
            PointOfSaleCardPresentPaymentReaderUpdateInProgressView(viewModel: PointOfSaleCardPresentPaymentUpdatingReaderAlertViewModel(
                requiredUpdate: true, progress: 0.6, cancel: nil
            ))
        }
    }
}

#Preview {
    CardPresentPaymentReaderUpdateInProgressPreviewView()
}

#endif
