import SwiftUI

struct CardPresentPaymentBluetoothRequiredAlertView: View {
    private let viewModel: CardPresentPaymentBluetoothRequiredAlertViewModel
    @Environment(\.dismiss) var dismiss

    init(viewModel: CardPresentPaymentBluetoothRequiredAlertViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Text(viewModel.title)

            viewModel.image

            Text(viewModel.errorDetails)

            Button(viewModel.openSettingsButtonViewModel.title,
                   action: viewModel.openSettingsButtonViewModel.actionHandler)
            .buttonStyle(PrimaryButtonStyle())

            Button(viewModel.dismissButtonViewModel.title) {
                dismiss()
                viewModel.dismissButtonViewModel.actionHandler()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
