import Foundation
import UIKit
import Yosemite

/// Type to encapsulate the options presented when generating variations.
///
final class GenerateVariationsOptionsPresenter {
    /// Options available when generating variations
    ///
    enum Option {
        case single
        case all
    }

    /// Base view controller where the loading indicators and notices will be presented.
    ///
    private let baseViewController: UIViewController

    init(baseViewController: UIViewController) {
        self.baseViewController = baseViewController
    }

    /// Displays a bottom sheet allowing the merchant to choose whether to generate one variation or to generate all variations.
    ///
    func presentGenerationOptions(sourceView: UIView, onCompletion: @escaping (_ selectedOption: Option) -> Void) {
        guard ServiceLocator.featureFlagService.isFeatureFlagEnabled(.generateAllVariations) else {
            return onCompletion(.single)
        }

        let viewProperties = BottomSheetListSelectorViewProperties(title: Localization.addVariationAction)
        let command = GenerateVariationsSelectorCommand(selected: nil) { [weak self] option in
            guard let self else { return }
            self.baseViewController.dismiss(animated: true)
            switch option {
            case .single:
                onCompletion(.single)
            case .all:
                onCompletion(.all)
            }
        }
        let bottomSheetPresenter = BottomSheetListSelectorPresenter(viewProperties: viewProperties, command: command)
        bottomSheetPresenter.show(from: baseViewController, sourceView: sourceView)
    }
}

// MARK: Localization
//
private extension GenerateVariationsOptionsPresenter {
    enum Localization {
        static let addVariationAction = NSLocalizedString("Add Variation",
                                                          comment: "Title on empty state button when the product has attributes but no variations")
    }
}
