import SwiftUI

/// Hosting controller for `BlazeCampaignCreationForm`
final class BlazeCampaignCreationFormHostingController: UIHostingController<BlazeCampaignCreationForm> {
    private let viewModel: BlazeCampaignCreationFormViewModel

    init(viewModel: BlazeCampaignCreationFormViewModel) {
        self.viewModel = viewModel
        super.init(rootView: .init(viewModel: viewModel))
        self.viewModel.onEditAd = { [weak self] in
            self?.navigateToEditAd()
        }
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localization.title
    }
}

private extension BlazeCampaignCreationFormHostingController {
    func navigateToEditAd() {
        let vc = BlazeEditAdHostingController(viewModel: viewModel.editAdViewModel)
        present(vc, animated: true)
    }
}

private extension BlazeCampaignCreationFormHostingController {
    enum Localization {
        static let title = NSLocalizedString(
            "blazeCampaignCreationForm.title",
            value: "Preview",
            comment: "Title of the Blaze campaign creation screen"
        )
    }
}

/// Form to enter details for creating a new Blaze campaign.
struct BlazeCampaignCreationForm: View {
    @ObservedObject private var viewModel: BlazeCampaignCreationFormViewModel

    @Environment(\.colorScheme) var colorScheme

    @State private var isShowingBudgetSetting = false
    @State private var isShowingLanguagePicker = false
    @State private var isShowingAdDestinationScreen = false
    @State private var isShowingDevicePicker = false
    @State private var isShowingTopicPicker = false
    @State private var isShowingLocationPicker = false
    @State private var isShowingAISuggestionsErrorAlert: Bool = false

    init(viewModel: BlazeCampaignCreationFormViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.contentPadding) {
                adPreview

                Text(Localization.details)
                    .subheadlineStyle()
                    .foregroundColor(.init(uiColor: .text))

                // Budget
                detailView(title: Localization.budget, content: viewModel.budgetDetailText) {
                    isShowingBudgetSetting = true
                }
                .background(Constants.cellColor)
                .overlay { roundedRectangleBorder }

                VStack(spacing: 0) {
                    // Language
                    detailView(title: Localization.language, content: viewModel.targetLanguageText) {
                        isShowingLanguagePicker = true
                    }

                    divider

                    // Devices
                    detailView(title: Localization.devices, content: viewModel.targetDeviceText) {
                        isShowingDevicePicker = true
                    }

                    divider

                    // Location
                    detailView(title: Localization.location, content: viewModel.targetLocationText) {
                        isShowingLocationPicker = true
                    }

                    divider

                    // Interests
                    detailView(title: Localization.interests, content: viewModel.targetTopicText) {
                        isShowingTopicPicker = true
                    }
                }
                .background(Constants.cellColor)
                .overlay { roundedRectangleBorder }

                // Ad destination
                if viewModel.adDestinationViewModel != nil {
                    detailView(title: Localization.adDestination,
                               content: viewModel.finalDestinationURL,
                               isContentSingleLine: true) {
                        isShowingAdDestinationScreen = true
                    }
                    .background(Constants.cellColor)
                    .overlay { roundedRectangleBorder }
                }
            }
            .padding(.horizontal, Layout.contentPadding)
        }
        .background(Constants.backgroundViewColor)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                Button {
                    viewModel.didTapConfirmDetails()
                } label: {
                    Text(Localization.confirmDetails)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(Layout.contentPadding)
                .disabled(!viewModel.canConfirmDetails)
            }
            .background(Constants.backgroundViewColor)
        }
        .sheet(isPresented: $isShowingBudgetSetting) {
            BlazeBudgetSettingView(viewModel: viewModel.budgetSettingViewModel)
        }
        .sheet(isPresented: $isShowingLanguagePicker) {
            BlazeTargetLanguagePickerView(viewModel: viewModel.targetLanguageViewModel) {
                isShowingLanguagePicker = false
            }
        }
        .sheet(isPresented: $isShowingAdDestinationScreen) {
            if let viewModel = viewModel.adDestinationViewModel {
                BlazeAdDestinationSettingView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $isShowingDevicePicker) {
            BlazeTargetDevicePickerView(viewModel: viewModel.targetDeviceViewModel) {
                isShowingDevicePicker = false
            }
        }
        .sheet(isPresented: $isShowingTopicPicker) {
            BlazeTargetTopicPickerView(viewModel: viewModel.targetTopicViewModel) {
                isShowingTopicPicker = false
            }
        }
        .sheet(isPresented: $isShowingLocationPicker) {
            BlazeTargetLocationPickerView(viewModel: viewModel.targetLocationViewModel) {
                isShowingLocationPicker = false
            }
        }
        .onChange(of: viewModel.error) { newValue in
            isShowingAISuggestionsErrorAlert = newValue == .failedToLoadAISuggestions
        }
        .alert(isPresented: $isShowingAISuggestionsErrorAlert, content: {
            Alert(title: Text(Localization.AISuggestionsErrorAlert.title),
                  message: Text(Localization.AISuggestionsErrorAlert.ErrorMessage.fetchingAISuggestions),
                  primaryButton: .default(Text(Localization.AISuggestionsErrorAlert.retry), action: {
                Task {
                    await viewModel.loadAISuggestions()
                }
            }),
                  secondaryButton: .cancel())
        })
        .alert(isPresented: $viewModel.isShowingMissingImageErrorAlert, content: {
            Alert(title: Text(Localization.NoImageErrorAlert.noImageFound),
                  dismissButton: .default(Text(Localization.NoImageErrorAlert.ok)))
        })
        LazyNavigationLink(destination: BlazeConfirmPaymentView(viewModel: viewModel.confirmPaymentViewModel),
                           isActive: $viewModel.isShowingPaymentInfo) {
            EmptyView()
        }
    }
}

private extension BlazeCampaignCreationForm {
    var adPreview: some View {
        VStack(spacing: Layout.contentPadding) {
            VStack(alignment: .leading, spacing: Layout.contentMargin) {
                // Image
                Image(uiImage: viewModel.image?.image ?? .blazeProductPlaceholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(Layout.cornerRadius)

                // Tagline
                Text(viewModel.isLoadingAISuggestions ? "Placeholder tagline" : viewModel.tagline)
                    .foregroundStyle(.secondary)
                    .captionStyle()
                    .redacted(reason: viewModel.isLoadingAISuggestions ? .placeholder : [])
                    .shimmering(active: viewModel.isLoadingAISuggestions)

                HStack(spacing: Layout.contentPadding) {
                    // Description
                    Text(viewModel.isLoadingAISuggestions ? "This is a placeholder description" : viewModel.description)
                        .fontWeight(.semibold)
                        .headlineStyle()
                        .multilineTextAlignment(.leading)
                        .redacted(reason: viewModel.isLoadingAISuggestions ? .placeholder : [])
                        .shimmering(active: viewModel.isLoadingAISuggestions)

                    Spacer()

                    // Simulate shop button
                    Text(Localization.shopNow)
                        .fontWeight(.semibold)
                        .captionStyle()
                        .padding(Layout.contentMargin)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(Layout.adButtonCornerRadius)
                }
            }
            .padding(Layout.contentPadding)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(Layout.cornerRadius)
            .shadow(color: .black.opacity(0.05),
                    radius: Layout.shadowRadius,
                    x: 0,
                    y: Layout.shadowYOffset)

            // Button to edit ad details
            Button(action: {
                viewModel.didTapEditAd()
            }, label: {
                Text(Localization.editAd)
                    .fontWeight(.semibold)
                    .font(.body)
                    .foregroundColor(.accentColor)
            })
            .buttonStyle(.plain)
            .disabled(!viewModel.canEditAd)
            .redacted(reason: !viewModel.canEditAd ? .placeholder : [])
            .shimmering(active: !viewModel.canEditAd)
        }
        .environment(\.colorScheme, .light)
        .padding(Layout.contentPadding)
        .background(Color(light: .init(uiColor: .systemGray6),
                          dark: .init(uiColor: .tertiarySystemBackground)))
        .cornerRadius(Layout.cornerRadius)
        .padding(.vertical, Layout.contentPadding)
    }

    func detailView(title: String, content: String, isContentSingleLine: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            HStack {
                VStack(alignment: .leading, spacing: Layout.detailContentSpacing) {
                    Text(title)
                        .bodyStyle()
                    Text(content)
                        .secondaryBodyStyle()
                        .multilineTextAlignment(.leading)
                        .lineLimit(isContentSingleLine ? 1 : nil)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .secondaryBodyStyle()
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.vertical, Layout.contentMargin)
        })
    }

    var divider: some View {
        Divider()
            .frame(height: Layout.strokeWidth)
            .foregroundColor(Color(uiColor: .separator))
    }

    var roundedRectangleBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .stroke(Color(uiColor: .separator), lineWidth: Layout.strokeWidth)
    }
}

private extension BlazeCampaignCreationForm {
    enum Layout {
        static let contentMargin: CGFloat = 8
        static let contentPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let adButtonCornerRadius: CGFloat = 4
        static let strokeWidth: CGFloat = 1
        static let detailContentSpacing: CGFloat = 4
        static let shadowRadius: CGFloat = 2
        static let shadowYOffset: CGFloat = 2
    }

    enum Constants {
        static let backgroundViewColor = Color(light: .init(uiColor: .systemBackground),
                                               dark: .init(uiColor: .secondarySystemBackground))
        static let cellColor = Color(light: .init(uiColor: .systemBackground),
                                     dark: .init(uiColor: .tertiarySystemBackground))
    }

    enum Localization {
        static let title = NSLocalizedString(
            "blazeCampaignCreationForm.title",
            value: "Preview",
            comment: "Title of the Blaze campaign creation screen"
        )
        static let shopNow = NSLocalizedString(
            "blazeCampaignCreationForm.shopNow",
            value: "Shop Now",
            comment: "Button to shop on the Blaze ad preview"
        )
        static let editAd = NSLocalizedString(
            "blazeCampaignCreationForm.editAd",
            value: "Edit ad",
            comment: "Button to edit ad details on the Blaze campaign creation screen"
        )
        static let details = NSLocalizedString(
            "blazeCampaignCreationForm.details",
            value: "Details",
            comment: "Section title on the Blaze campaign creation screen"
        )
        static let budget = NSLocalizedString(
            "blazeCampaignCreationForm.budget",
            value: "Budget",
            comment: "Title of the Budget field on the Blaze campaign creation screen"
        )
        static let language = NSLocalizedString(
            "blazeCampaignCreationForm.language",
            value: "Language",
            comment: "Title of the Language field on the Blaze campaign creation screen"
        )
        static let devices = NSLocalizedString(
            "blazeCampaignCreationForm.devices",
            value: "Devices",
            comment: "Title of the Devices field on the Blaze campaign creation screen"
        )
        static let location = NSLocalizedString(
            "blazeCampaignCreationForm.location",
            value: "Location",
            comment: "Title of the Location field on the Blaze campaign creation screen"
        )
        static let interests = NSLocalizedString(
            "blazeCampaignCreationForm.interests",
            value: "Interests",
            comment: "Title of the Interests field on the Blaze campaign creation screen"
        )
        static let adDestination = NSLocalizedString(
            "blazeCampaignCreationForm.adDestination",
            value: "Ad destination",
            comment: "Title of the Ad destination field on the Blaze campaign creation screen"
        )
        static let confirmDetails = NSLocalizedString(
            "blazeCampaignCreationForm.confirmDetails",
            value: "Confirm Details",
            comment: "Button to confirm ad details on the Blaze campaign creation screen"
        )
        enum AISuggestionsErrorAlert {
            enum ErrorMessage {
                static let fetchingAISuggestions = NSLocalizedString(
                    "blazeCampaignCreationForm.errorAlert.errorMessage.fetchingAISuggestions",
                    value: "Failed to load suggestions for tagline and description",
                    comment: "Error message indicating that loading suggestions for tagline and description failed"
                )
            }
            static let title = NSLocalizedString(
                "blazeCampaignCreationForm.errorAlert.title",
                value: "Oops! We've hit a snag",
                comment: "Title on the error alert displayed on the Blaze campaign creation screen"
            )
            static let retry = NSLocalizedString(
                "blazeCampaignCreationForm.errorAlert.retry",
                value: "Retry",
                comment: "Button on the error alert displayed on the Blaze campaign creation screen"
            )
        }
        enum NoImageErrorAlert {
            static let noImageFound = NSLocalizedString(
                "blazeCampaignCreationForm.noImageErrorAlert.noImageFound",
                value: "Please set an image for the Blaze campaign by tapping Edit ad",
                comment: "Message asking to select an image for the Blaze campaign"
            )
            static let ok = NSLocalizedString(
                "blazeCampaignCreationForm.noImageErrorAlert.ok",
                value: "OK",
                comment: "Dismiss button on the error alert asking to select a image for the Blaze campaign"
            )
        }
    }
}

struct BlazeCampaignCreationForm_Previews: PreviewProvider {
    static var previews: some View {
        BlazeCampaignCreationForm(viewModel: .init(siteID: 123, productID: 123, onCompletion: {}))
    }
}
