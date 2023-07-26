import SwiftUI

final class FreeTrialSurveyViewModel: ObservableObject {
    @Published private(set) var selectedAnswer: SurveyAnswer?
    @Published var otherReasonSpecified: String = ""

    private let analytics: Analytics
    private let source: FreeTrialSurveyCoordinator.Source

    init(source: FreeTrialSurveyCoordinator.Source,
         analytics: Analytics = ServiceLocator.analytics) {
        self.source = source
        self.analytics = analytics

        $otherReasonSpecified
            .filter { $0.isNotEmpty }
            .map { _ in nil }
            .assign(to: &$selectedAnswer)
    }

    var answers: [SurveyAnswer] {
        SurveyAnswer.allCases
    }

    var feedbackSelected: Bool {
        otherReasonSpecified.isNotEmpty || selectedAnswer != nil
    }

    func selectAnswer(_ answer: SurveyAnswer) {
        selectedAnswer = answer
    }

    func submitFeedback() {
        // TODO: 10266 Submit tracks
    }

    enum SurveyAnswer: String, Equatable, CaseIterable {
        case stillExploring = "still_exploring"
        case comparingWithOtherPlatforms = "comparing_with_other_platforms"
        case priceIsSignificantFactor = "price_is_significant_factor"
        case collectiveDecision = "collective_decision"
        case otherReasons = "other_reasons"

        var text: String {
            switch self {
            case .stillExploring:
                return Localization.stillExploring
            case .comparingWithOtherPlatforms:
                return Localization.comparingWithOtherPlatforms
            case .priceIsSignificantFactor:
                return Localization.priceIsSignificantFactor
            case .collectiveDecision:
                return Localization.collectiveDecision
            case .otherReasons:
                return Localization.otherReasons
            }
        }

        private enum Localization {
            static let stillExploring = NSLocalizedString(
                "I am still exploring and assessing the features and benefits of the app.",
                comment: "Text for Free trial survey answer."
            )
            static let comparingWithOtherPlatforms = NSLocalizedString(
                "I am evaluating and comparing your service with others on the market",
                comment: "Text for Free trial survey answer."
            )
            static let priceIsSignificantFactor = NSLocalizedString(
                "I find the price of the service to be a significant factor in my decision.",
                comment: "Text for Free trial survey answer."
            )
            static let collectiveDecision = NSLocalizedString(
                "I am part of a team, and we need to make the decision collectively.",
                comment: "Text for Free trial survey answer."
            )
            static let otherReasons = NSLocalizedString(
                "Other (please specify).",
                comment: "Placeholder text for Free trial survey."
            )
        }
    }
}
