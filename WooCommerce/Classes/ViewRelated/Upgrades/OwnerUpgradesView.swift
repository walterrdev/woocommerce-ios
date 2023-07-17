import SwiftUI
import Yosemite
import WooFoundation

struct FullFeatureListGroups {
    public let title: String
    public let essentialFeatures: [String]
    public let performanceFeatures: [String]
}

struct FullFeatureListViewModel {
    static func hardcodedFullFeatureList() -> [FullFeatureListGroups] {
        return [
            FullFeatureListGroups(title: "Your Store",
                                  essentialFeatures: [
                                    "WooCommerce store",
                                    "WooCommerce mobile app",
                                    "WordPress CMS",
                                    "WordPress mobile app",
                                    "Free SSL certificate",
                                    "Generous storage",
                                    "Automated backup + quick restore",
                                    "Ad-free experience",
                                    "Unlimited admin accounts",
                                    "Live chat support",
                                    "Email support",
                                    "Premium themes included",
                                    "Sales reports",
                                    "Google Analytics"
                                  ],
                                  performanceFeatures: []
                                 ),
            FullFeatureListGroups(title: "Products",
                                  essentialFeatures: [
                                    "List unlimited products",
                                    "Gift cards",
                                  ],
                                  performanceFeatures: [
                                    "Min/Max order quantity",
                                    "Product Bundles",
                                    "Custom product kits",
                                    "List products by brand",
                                    "Product recommendations"
                                  ]),
            FullFeatureListGroups(title: "Payments",
                                  essentialFeatures: [
                                    "Integrated payments",
                                    "International payments'",
                                    "Automated sales taxes",
                                    "Accept local payments'",
                                    "Recurring payments'"
                                  ],
                                  performanceFeatures: []),

            FullFeatureListGroups(title: "Marketing & Email",
                                  essentialFeatures: [
                                  "Promote on TikTok",
                                  "Sync with Pinterest",
                                  "Connect with Facebook",
                                  "Advanced SEO tools",
                                  "Advertise on Google",
                                  "Custom order emails",
                                  ],
                                  performanceFeatures: [
                                    "Back in stock emails",
                                    "Marketing automation",
                                    "Abandoned cart recovery",
                                    "Referral programs",
                                    "Customer birthday emails",
                                    "Loyalty points programs"
                                  ]),

            FullFeatureListGroups(title: "Shipping",
                                  essentialFeatures: [
                                  "Shipment tracking",
                                  "Live shipping rates",
                                  "Discounted shipping²",
                                  "Print shipping labels²"],
                                  performanceFeatures: []),
        ]
    }
}

struct FullFeatureListView: View {
    var featureListGroups = FullFeatureListViewModel.hardcodedFullFeatureList()
    var body: some View {
        ScrollView() {
            VStack(alignment: .leading, spacing: 8.0) {
                ForEach(featureListGroups, id: \.title) { featureList in
                    Text(featureList.title)
                        .font(.title)
                        .bold()
                    ForEach(featureList.essentialFeatures, id: \.self) { feature in
                        Text(feature)
                            .font(.body)
                    }
                    ForEach(featureList.performanceFeatures, id: \.self) { feature in
                        Text(feature)
                            .font(.body)
                            .underline(color: .red)
                    }
                    Divider()
                }
                Text(Localization.disclaimer1)
                    .font(.caption)
                Text(Localization.disclaimer2)
                    .font(.caption)
            }
            .background(Color(.listBackground))
            .navigationTitle("Full Feature List")
        }
    }
}

private extension FullFeatureListView {
    struct Localization {
        static let disclaimer1 = NSLocalizedString(
            "1. Available as standard in WooCommerce Payments (restrictions apply)." +
            "Additional extensions may be required for other payment providers." ,
            comment: "")
        static let disclaimer2 = NSLocalizedString(
        "2. Only available in the U.S. – an additional extension will be required for other countries.",
        comment: "")
    }
}

struct OwnerUpgradesView: View {
    @State var upgradePlans: [WooWPComPlan]
    @State var isPurchasing: Bool
    let purchasePlanAction: (WooWPComPlan) -> Void
    @State var isLoading: Bool

    init(upgradePlans: [WooWPComPlan],
         isPurchasing: Bool = false,
         purchasePlanAction: @escaping ((WooWPComPlan) -> Void),
         isLoading: Bool = false) {
        _upgradePlans = .init(initialValue: upgradePlans)
        _isPurchasing = .init(initialValue: isPurchasing)
        self.purchasePlanAction = purchasePlanAction
        _isLoading = .init(initialValue: isLoading)
    }

    @State private var paymentFrequency: LegacyWooPlan.PlanFrequency = .year
    private var paymentFrequencies: [LegacyWooPlan.PlanFrequency] = [.year, .month]

    @State var selectedPlan: WooWPComPlan? = nil
    @State private var showingFullFeatureList = false

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $paymentFrequency, label: EmptyView()) {
                ForEach(paymentFrequencies) {
                    Text($0.paymentFrequencyLocalizedString)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isLoading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmering(active: isLoading)

            ScrollView {
                VStack {
                    ForEach(upgradePlans.filter { $0.wooPlan.planFrequency == paymentFrequency }) { upgradePlan in
                        WooPlanCardView(upgradePlan: upgradePlan, selectedPlan: $selectedPlan)
                        .accessibilityAddTraits(.isSummaryElement)
                        .listRowSeparator(.hidden)
                        .redacted(reason: isLoading ? .placeholder : [])
                        .shimmering(active: isLoading)
                        .padding(.bottom, 8)
                    }
                    Button(Localization.allFeaturesListText) {
                        showingFullFeatureList.toggle()
                    }.sheet(isPresented: $showingFullFeatureList) {
                        FullFeatureListView()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            VStack {
                if let selectedPlan {
                    let buttonText = String.localizedStringWithFormat(Localization.purchaseCTAButtonText, selectedPlan.wpComPlan.displayName)
                    Button(buttonText) {
                        purchasePlanAction(selectedPlan)
                    }
                    .buttonStyle(PrimaryLoadingButtonStyle(isLoading: isPurchasing))
                    .disabled(isLoading)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)
                } else {
                    Button(Localization.selectPlanButtonText) {
                        // no-op
                    }
                    .buttonStyle(PrimaryLoadingButtonStyle(isLoading: isPurchasing))
                    .disabled(true)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)
                }
            }
            .padding()
        }
    }
}

private extension OwnerUpgradesView {
    struct Localization {
        static let purchaseCTAButtonText = NSLocalizedString(
            "Purchase %1$@",
            comment: "The title of the button to purchase a Plan." +
            "Reads as 'Purchase Essential Monthly'")

        static let featuresHeaderTextFormat = NSLocalizedString(
            "Get the most out of %1$@",
            comment: "Title for the section header for the list of feature categories on the Upgrade plan screen. " +
            "Reads as 'Get the most out of Essential'. %1$@ must be included in the string and will be replaced with " +
            "the plan name.")

        static let featureDetailsUnavailableText = NSLocalizedString(
            "See plan details", comment: "Title for a link to view Woo Express plan details on the web, as a fallback.")

        static let selectPlanButtonText = NSLocalizedString(
            "Select a plan", comment: "The title of the button to purchase a Plan when no plan is selected yet.")

        static let allFeaturesListText = NSLocalizedString(
            "View Full Feature List",
            comment: "The title of the button to view a list of all features that plans offer.")
    }
}

private extension LegacyWooPlan.PlanFrequency {
    var paymentFrequencyLocalizedString: String {
        switch self {
        case .month:
            return Localization.payMonthly
        case .year:
            return Localization.payAnnually
        }
    }

    enum Localization {
        static let payMonthly = NSLocalizedString(
            "Monthly",
            comment: "Title of the selector option for paying monthly on the Upgrade view, when choosing a plan")

        static let payAnnually = NSLocalizedString(
            "Annually (Save 35%)",
            comment: "Title of the selector option for paying annually on the Upgrade view, when choosing a plan")
    }
}
