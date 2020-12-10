import UIKit
import WordPressAuthenticator
import SafariServices


/// UI presenting errors in the Unified Login flow.
/// This view controller can either be presented from within WooCommerce
/// or be injected into WordPressAuthenticator.
final class ULErrorViewController: UIViewController {
    /// The view model providing configuration for this view controller
    /// and support for user actions
    private let viewModel: ULErrorViewModel

    @IBOutlet private var primaryButton: NUXButton!
    @IBOutlet private var secondaryButton: NUXButton!
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private weak var errorMessage: UILabel!
    @IBOutlet private weak var extraInfoButton: UIButton!

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.isPad() ? .all : .portrait
    }

    init(viewModel: ULErrorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: Self.nibName, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureImageView()
        configureErrorMessage()
        configureExtraInfoButton()

        configurePrimaryButton()
        configureSecondaryButton()
    }
}


// MARK: - View configuration
private extension ULErrorViewController {
    func configureImageView() {
        imageView.image = viewModel.image
    }

    func configureErrorMessage() {
        errorMessage.applyBodyStyle()
        errorMessage.attributedText = viewModel.text
    }

    func configureExtraInfoButton() {
        guard viewModel.isAuxiliaryButtonHidden == false else {
            extraInfoButton.isHidden = true

            return
        }

        extraInfoButton.applyLinkButtonStyle()
        extraInfoButton.contentEdgeInsets = Constants.extraInfoCustomInsets
        extraInfoButton.setTitle(viewModel.auxiliaryButtonTitle, for: .normal)
        extraInfoButton.on(.touchUpInside) { [weak self] _ in
            self?.didTapAuxiliaryButton()
        }
    }

    func configurePrimaryButton() {
        primaryButton.isPrimary = true
        primaryButton.setTitle(viewModel.primaryButtonTitle, for: .normal)
        primaryButton.on(.touchUpInside) { [weak self] _ in
            self?.didTapPrimaryButton()
        }
    }

    func configureSecondaryButton() {
        secondaryButton.setTitle(viewModel.secondaryButtonTitle, for: .normal)
        secondaryButton.on(.touchUpInside) { [weak self] _ in
            self?.didTapSecondaryButton()
        }
    }
}


// MARK: - Actions
private extension ULErrorViewController {
    func didTapAuxiliaryButton() {
        viewModel.didTapAuxiliaryButton(in: self)
    }

    func didTapPrimaryButton() {
        viewModel.didTapPrimaryButton(in: self)
    }

    func didTapSecondaryButton() {
        viewModel.didTapSecondaryButton(in: self)
    }
}


// MARK: - Constants
private extension ULErrorViewController {
    enum Constants {
        static let extraInfoCustomInsets = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    }
}

// MARK: - Tests
extension ULErrorViewController {
    func getImageView() -> UIImageView {
        return imageView
    }

    func getLabel() -> UILabel {
        return errorMessage
    }

    func getAuxiliaryButton() -> UIButton {
        return extraInfoButton
    }

    func primaryActionButton() -> UIButton {
        return primaryButton
    }

    func secondaryActionButton() -> UIButton {
        return secondaryButton
    }
}
