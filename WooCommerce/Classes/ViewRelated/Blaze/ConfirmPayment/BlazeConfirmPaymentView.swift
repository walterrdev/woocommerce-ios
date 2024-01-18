import SwiftUI

/// View to confirm the payment method before creating a Blaze campaign.
struct BlazeConfirmPaymentView: View {
    /// Scale of the view based on accessibility changes
    @ScaledMetric private var scale: CGFloat = 1.0
    @ObservedObject private var viewModel: BlazeConfirmPaymentViewModel

    @State private var externalURL: URL?

    private let agreementText: NSAttributedString = {
        let content = String.localizedStringWithFormat(Localization.agreement, Localization.termsOfService, Localization.adPolicy, Localization.learnMore)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let mutableAttributedText = NSMutableAttributedString(
            string: content,
            attributes: [.font: UIFont.caption1,
                         .foregroundColor: UIColor.secondaryLabel,
                         .paragraphStyle: paragraph]
        )

        mutableAttributedText.setAsLink(textToFind: Localization.termsOfService,
                                        linkURL: Constants.termsLink)
        mutableAttributedText.setAsLink(textToFind: Localization.adPolicy,
                                        linkURL: Constants.adPolicyLink)
        mutableAttributedText.setAsLink(textToFind: Localization.learnMore,
                                        linkURL: Constants.learnMoreLink)
        return mutableAttributedText
    }()

    init(viewModel: BlazeConfirmPaymentViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.contentPadding) {

                totalAmountView
                    .padding(.horizontal, Layout.contentPadding)

                Divider()

                if !viewModel.isFetchingPaymentInfo {
                    if viewModel.selectedPaymentMethod == nil {
                        addPaymentMethodButton
                            .padding(.horizontal, Layout.contentPadding)
                    } else {
                        cardDetailView
                            .padding(.horizontal, Layout.contentPadding)
                    }

                } else {
                    loadingView
                        .padding(.horizontal, Layout.contentPadding)
                }

                Divider()
            }
            .padding(.vertical, Layout.contentPadding)
        }
        .navigationTitle(Localization.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            footerView
        }
        .task {
            await viewModel.updatePaymentInfo()
        }
        .alert(Text(Localization.errorMessage), isPresented: $viewModel.shouldDisplayPaymentErrorAlert, actions: {
            Button(Localization.tryAgain) {
                Task {
                    await viewModel.updatePaymentInfo()
                }
            }
        })
        .sheet(isPresented: $viewModel.isCreatingCampaign) {
            BlazeCampaignCreationLoadingView()
                .interactiveDismissDisabled()
        }
    }
}

private extension BlazeConfirmPaymentView {
    var totalAmountView: some View {
        VStack(alignment: .leading, spacing: Layout.contentPadding) {
            Text(Localization.paymentTotals)
                .fontWeight(.semibold)
                .bodyStyle()

            HStack {
                Text(Localization.blazeCampaign)
                    .bodyStyle()

                Spacer()

                Text(viewModel.totalAmount)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text(Localization.total)
                    .bold()

                Spacer()

                Text(String.localizedStringWithFormat(Localization.totalAmount, viewModel.totalAmount))
                    .bold()
            }
            .bodyStyle()
        }
    }

    var cardDetailView: some View {
        Button {
            // TODO: show payment method list
        } label: {
            if let icon = viewModel.cardIcon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.cardIconWidth * scale)
            }

            VStack(alignment: .leading) {
                if let type = viewModel.cardTypeName {
                    Text(type)
                        .bodyStyle()
                }

                if let name = viewModel.cardName {
                    Text(name)
                        .foregroundColor(.secondary)
                        .captionStyle()
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .secondaryBodyStyle()
        }
    }

    var addPaymentMethodButton: some View {
        Button {
            // TODO: open payment method list
        } label: {
            HStack {
                Text(Localization.addPaymentMethod)
                Spacer()
                Image(systemName: "chevron.right")
                    .secondaryBodyStyle()
            }
        }
    }

    var loadingView: some View {
        HStack {
            Text(Localization.loading)
                .secondaryBodyStyle()
            Spacer()
            ActivityIndicator(isAnimating: .constant(true), style: .medium)
        }
    }

    var footerView: some View {
        VStack(spacing: Layout.contentPadding) {
            Divider()
            Button(Localization.submitButton) {
                Task {
                    await viewModel.submitCampaign()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.shouldDisableCampaignCreation)
            .padding(.horizontal, Layout.contentPadding)

            AttributedText(agreementText)
                .padding(.horizontal, Layout.contentPadding)
                .environment(\.openURL, OpenURLAction { url in
                    externalURL = url
                    return .handled
                })
                .safariSheet(url: $externalURL)
        }
        .padding(.vertical, Layout.contentPadding)
        .background(Color(.systemBackground))
    }
}

private extension BlazeConfirmPaymentView {

    enum Layout {
        static let contentPadding: CGFloat = 16
        static let cardIconWidth: CGFloat = 35
    }

    enum Constants {
        static let termsLink = "https://wordpress.com/tos/"
        static let adPolicyLink = "https://automattic.com/advertising-policy/"
        static let learnMoreLink = "https://wordpress.com/support/promote-a-post/"
    }

    enum Localization {
        static let title = NSLocalizedString(
            "blazeConfirmPaymentView.title",
            value: "Payment",
            comment: "Title of the Payment view in the Blaze campaign creation flow"
        )
        static let submitButton = NSLocalizedString(
            "blazeConfirmPaymentView.submitButton",
            value: "Submit Campaign",
            comment: "Action button on the Payment screen in the Blaze campaign creation flow"
        )
        static let paymentTotals = NSLocalizedString(
            "blazeConfirmPaymentView.paymentTotals",
            value: "Payment totals",
            comment: "Section title on the Payment screen in the Blaze campaign creation flow"
        )
        static let blazeCampaign = NSLocalizedString(
            "blazeConfirmPaymentView.blazeCampaign",
            value: "Blaze campaign",
            comment: "Item to be charged on the Payment screen in the Blaze campaign creation flow"
        )
        static let total = NSLocalizedString(
            "blazeConfirmPaymentView.total",
            value: "Total",
            comment: "Title of the total amount to be charged on the Payment screen in the Blaze campaign creation flow"
        )
        static let totalAmount = NSLocalizedString(
            "blazeConfirmPaymentView.totalAmount",
            value: "%1$@ USD",
            comment: "The formatted total amount for a Blaze campaign, fixed in USD. " +
            "Reads as $11 USD."
        )
        static let addPaymentMethod = NSLocalizedString(
            "blazeConfirmPaymentView.addPaymentMethod",
            value: "Add a payment method",
            comment: "Button for adding a payment method on the Payment screen in the Blaze campaign creation flow"
        )
        static let loading = NSLocalizedString(
            "blazeConfirmPaymentView.loading",
            value: "Loading payment methods...",
            comment: "Text for the loading state on the Payment screen in the Blaze campaign creation flow"
        )
        static let agreement = NSLocalizedString(
            "blazeConfirmPaymentView.agreement",
            value: "By clicking \"Submit Campaign\" you agree to the %1$@ and " +
            "%2$@, and authorize your payment method to be charged for " +
            "the budget and duration you chose. %3$@ about how budgets and payments for Promoted Posts work.",
            comment: "Content of the agreement at the end of the Payment screen in the Blaze campaign creation flow. Read likes: " +
            "By clicking \"Submit campaign\" you agree to the Terms of Service and " +
                 "Advertising Policy, and authorize your payment method to be charged for " +
                 "the budget and duration you chose. Learn more about how budgets and payments for Promoted Posts work."
        )
        static let termsOfService = NSLocalizedString(
            "blazeConfirmPaymentView.terms",
            value: "Terms of Service",
            comment: "The terms to be agreed upon on the Payment screen in the Blaze campaign creation flow."
        )
        static let adPolicy = NSLocalizedString(
            "blazeConfirmPaymentView.adPolicy",
            value: "Advertising Policy",
            comment: "The action to be agreed upon on the Payment screen in the Blaze campaign creation flow."
        )
        static let learnMore = NSLocalizedString(
            "blazeConfirmPaymentView.learnMore",
            value: "Learn more",
            comment: "Link to guide for promoted posts on the Payment screen in the Blaze campaign creation flow."
        )
        static let errorMessage = NSLocalizedString(
            "blazeConfirmPaymentView.errorMessage",
            value: "Error loading your payment methods",
            comment: "Error message displayed when fetching payment methods failed on the Payment screen in the Blaze campaign creation flow."
        )
        static let tryAgain = NSLocalizedString(
            "blazeConfirmPaymentView.tryAgain",
            value: "Try Again",
            comment: "Button to retry when fetching payment methods failed on the Payment screen in the Blaze campaign creation flow."
        )
    }
}

#Preview {
    BlazeConfirmPaymentView(viewModel: BlazeConfirmPaymentViewModel(
        siteID: 123,
        campaignInfo: .init(origin: "test",
                            originVersion: "1.0",
                            paymentMethodID: "pid",
                            startDate: Date(),
                            endDate: Date(),
                            timeZone: "US-NY",
                            totalBudget: 35,
                            siteName: "iPhone 15",
                            textSnippet: "Fancy new phone",
                            targetUrl: "https://example.com",
                            urlParams: "",
                            mainImage: .init(url: "https://example.com", mimeType: "png"),
                            targeting: nil,
                            targetUrn: "",
                            type: "product")) {})
}
