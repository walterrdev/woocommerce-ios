import struct WooFoundation.WooAnalyticsEvent

extension WooAnalyticsEvent {
    enum Blaze {
        /// Event property keys.
        private enum Key {
            static let source = "source"
            static let step = "current_step"
            static let duration = "duration"
            static let totalBudget = "total_budget"
            static let isAISuggestedAdContent = "is_ai_suggested_ad_content"
        }

        /// Tracked when the Blaze entry point is shown to the user.
        static func blazeEntryPointDisplayed(source: BlazeSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeEntryPointDisplayed,
                              properties: [Key.source: source.analyticsValue])
        }

        /// Tracked when the Blaze entry point is tapped by the user.
        /// - Parameter source: Entry point to the Blaze flow.
        static func blazeEntryPointTapped(source: BlazeSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeEntryPointTapped,
                              properties: [Key.source: source.analyticsValue])
        }

        /// Tracked when the Blaze webview is first loaded.
        static func blazeFlowStarted(source: BlazeSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeFlowStarted,
                              properties: [Key.source: source.analyticsValue])
        }

        /// Tracked when the Blaze webview is dismissed without completing the flow.
        static func blazeFlowCanceled(source: BlazeSource, step: Step) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeFlowCanceled,
                              properties: [Key.source: source.analyticsValue,
                                           Key.step: step.analyticsValue])
        }

        /// Tracked when the Blaze webview flow completes.
        static func blazeFlowCompleted(source: BlazeSource, step: Step) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeFlowCompleted,
                              properties: [Key.source: source.analyticsValue,
                                           Key.step: step.analyticsValue])
        }

        /// Tracked when the Blaze webview returns an error.
        static func blazeFlowError(source: BlazeSource, step: Step, error: Error) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeFlowError,
                              properties: [Key.source: source.analyticsValue,
                                           Key.step: step.analyticsValue],
                              error: error)
        }

        /// Tracked when the Blaze campaign list entry point is selected.
        static func blazeCampaignListEntryPointSelected(source: BlazeCampaignListSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeCampaignListEntryPointSelected,
                              properties: [Key.source: source.rawValue])
        }

        /// Tracked when a Blaze campaign detail is selected.
        static func blazeCampaignDetailSelected(source: BlazeCampaignDetailSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeCampaignDetailSelected,
                              properties: [Key.source: source.rawValue])
        }

        /// Tracked when an entry point to Blaze is dismissed.
        static func blazeViewDismissed(source: BlazeSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeViewDismissed, properties: [Key.source: source.analyticsValue])
        }

        /// Tracked when the intro screen for Blaze is displayed.
        static func introDisplayed() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeIntroDisplayed, properties: [:])
        }

        /// Tracked upon tapping "Learn how Blaze works" in Intro screen
        static func introLearnMoreTapped() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .blazeIntroLearnMoreTapped, properties: [:])
        }

        enum CreationForm {
            /// Tracked when Blaze creation form is displayed
            static func creationFormDisplayed() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeCreationFormDisplayed, properties: [:])
            }

            /// Tracked upon tapping "Edit ad" in Blaze creation form
            static func editAdTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditAdTapped, properties: [:])
            }

            /// Tracked upon tapping "Confirm Details" in Blaze creation form
            static func confirmDetailsTapped(isAISuggestedAdContent: Bool) -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeCreationConfirmDetailsTapped,
                                  properties: [Key.isAISuggestedAdContent: isAISuggestedAdContent])
            }
        }

        enum EditAd {
            /// Tracked upon selecting AI suggestion in Edit Ad screen
            static func aiSuggestionTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditAdAISuggestionTapped, properties: [:])
            }

            /// Tracked upon tapping "Save" in Edit Ad screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditAdSaveTapped, properties: [:])
            }
        }

        enum Budget {
            /// Tracked upon tapping "Update" in Blaze set budget screen
            static func updateTapped(duration: Int, totalBudget: Double) -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditBudgetSaveTapped,
                                  properties: [Key.duration: duration,
                                               Key.totalBudget: totalBudget])
            }

            /// Tracked upon changing duration in Blaze set budget screen
            static func changedDuration(_ duration: Int) -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditBudgetDurationApplied,
                                  properties: [Key.duration: duration])
            }
        }

        enum Language {
            /// Tracked upon tapping "Save" in Blaze language selection screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditLanguageSaveTapped, properties: [:])
            }
        }

        enum Device {
            /// Tracked upon tapping "Save" in Blaze device selection screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditDeviceSaveTapped, properties: [:])
            }
        }

        enum Location {
            /// Tracked upon tapping "Save" in Blaze location selection screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditLocationSaveTapped, properties: [:])
            }
        }

        enum Interest {
            /// Tracked upon tapping "Save" in Blaze interests selection screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditInterestSaveTapped, properties: [:])
            }
        }

        enum AdDestination {
            /// Tracked upon tapping "Save" in Blaze ad destination selection screen
            static func saveTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeEditDestinationSaveTapped, properties: [:])
            }
        }

        enum Payment {
            /// Tracked upon tapping "Submit Campaign" in confirm payment screen
            static func submitCampaignTapped() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeSubmitCampaignTapped, properties: [:])
            }

            /// Tracked upon displaying "Add payment method" web view screen
            static func addPaymentMethodWebViewDisplayed() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeAddPaymentMethodWebViewDisplayed, properties: [:])
            }

            /// Tracked upon adding a payment method
            static func addPaymentMethodSuccess() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeAddPaymentMethodSuccess, properties: [:])
            }

            /// Tracked when campaign creation is successful
            static func campaignCreationSuccess() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeCampaignCreationSuccess, properties: [:])
            }

            /// Tracked when campaign creation fails
            static func campaignCreationFailed() -> WooAnalyticsEvent {
                WooAnalyticsEvent(statName: .blazeCampaignCreationFailed, properties: [:])
            }
        }
    }
}

extension WooAnalyticsEvent.Blaze {
    enum Step: Equatable {
        case unspecified
        case productList
        case campaignList
        case step1
        case custom(step: String)
    }
}

private extension WooAnalyticsEvent.Blaze.Step {
    var analyticsValue: String {
        switch self {
        case .unspecified:
            return "unspecified"
        case .productList:
            return "products-list"
        case .campaignList:
            return "campaigns-list"
        case .step1:
            return "step-1"
        case .custom(let step):
            return step
        }
    }
}

extension BlazeSource {
    var analyticsValue: String {
        switch self {
        case .campaignList:
            return "campaign_list"
        case .myStoreSection:
            return "my_store_section"
        case .introView:
            return "intro_view"
        case .productDetailPromoteButton:
            return "product_detail_promote_button"
        }
    }
}
