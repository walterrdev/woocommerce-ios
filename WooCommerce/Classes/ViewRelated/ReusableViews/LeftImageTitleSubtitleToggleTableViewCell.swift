import UIKit


/// Represents a regular UITableView Cell with subtitle: [Image | Text + Subtitle |  Disclosure]
///
class LeftImageTitleSubtitleToggleTableViewCell: UITableViewCell {


    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!

    /// Left Image
    ///
    var leftImage: UIImage? {
        get {
            return leftImageView?.image
        }
        set {
            leftImageView?.image = newValue
        }
    }

    /// Label's Text
    ///
    var labelText: String? {
        get {
            return titleLabel?.text
        }
        set {
            titleLabel?.text = newValue
        }
    }

    /// Subtitle's text
    ///
    var subtitleLabelText: String? {
        get {
            return subtitleLabel?.text
        }
        set {
            subtitleLabel?.text = newValue
        }
    }

    private var switchAction: ((Bool) -> Void)? = nil

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        switchAction?(sender.isOn)
    }
    // MARK: - Overridden Methods

    override func awakeFromNib() {
        super.awakeFromNib()
        configureBackground()
        leftImageView?.tintColor = .primary
        titleLabel?.applyBodyStyle()
        subtitleLabel?.applyFootnoteStyle()
        toggleSwitch?.onTintColor = .primary
    }

    private func configureBackground() {
        applyDefaultBackgroundStyle()
    }
}

// MARK: - Public Methods
//
extension LeftImageTitleSubtitleToggleTableViewCell {
    func configure(image: UIImage, text: String, subtitle: String, switchState: Bool, switchAction: @escaping (Bool) -> Void) {
        configure(image: image, text: text, subtitle: subtitle, attributedSubtitle: nil, switchState: switchState, switchAction: switchAction)
    }

    func configure(image: UIImage, text: String, subtitle: NSAttributedString, switchState: Bool, switchAction: @escaping (Bool) -> Void) {
        configure(image: image, text: text, subtitle: nil, attributedSubtitle: subtitle, switchState: switchState, switchAction: switchAction)
    }

    private func configure(image: UIImage,
                           text: String,
                           subtitle: String?,
                           attributedSubtitle: NSAttributedString?,
                           switchState: Bool,
                           switchAction: @escaping (Bool) -> Void) {
        leftImageView?.image = image
        titleLabel?.text = text
        subtitleLabel?.text = subtitle
        subtitleLabel.attributedText = attributedSubtitle
        toggleSwitch.isOn = switchState
        self.switchAction = switchAction
    }
}
