import Foundation
import UIKit

struct RoleErrorViewModel {

    // MARK: Properties

    /// The name of the user on the store.
    private(set) var nameText: String

    /// Assigned roles text for the user.
    private var roles: [String] = [] {
        didSet {
            roleText = humanizedRolesText(from: roles)
        }
    }

    /// Presentable version of the user's roles.
    private(set) var roleText: String = ""

    /// An illustration accompanying the error.
    let image: UIImage = .incorrectRoleError

    /// Extended description of the error.
    let text: NSAttributedString = .init(string: .errorMessageText)

    /// Provides the title for an auxiliary button
    let auxiliaryButtonTitle: String = .linkButtonTitle

    /// Provides the title for a primary action button
    let primaryButtonTitle: String = .primaryButtonTitle

    /// Provides the title for a secondary action button
    let secondaryButtonTitle: String = .secondaryButtonTitle


    // MARK: Lifecycle

    init(displayName: String, roles: [String]) {
        self.nameText = displayName
        self.roles = roles

        // Note: assignment during initialization will not trigger didSet.
        roleText = humanizedRolesText(from: roles)
    }

    /// Executes action associated to a tap on the primary button
    func didTapPrimaryButton() {
        // TODO
    }

    /// Executes action associated to a tap on the primary button
    func didTapSecondaryButton() {
        // TODO
    }

    func didTapAuxiliaryButton() {
        // TODO
    }

    // MARK: Private Helpers

    /// try to "humanize" the roles. e.g., "shop_manager" to "Shop Manager".
    /// given multiple roles, it will all be joined with a comma separator.
    private func humanizedRolesText(from roles: [String]) -> String {
        return roles.map {
            guard $0.contains("_") else {
                return $0.capitalized
            }
            return $0.components(separatedBy: "_").map { $0.capitalized }.joined(separator: " ")
        }.joined(separator: ", ")
    }

}

// MARK: - Localization

private extension String {

    static let errorMessageText = NSLocalizedString("This app supports only Administrator and Shop Manager user roles. "
                                                        + "Please contact your store owner to upgrade your role.",
                                                    comment: "Message explaining more detail on why the user's role is incorrect.")

    static let linkButtonTitle = NSLocalizedString("Learn more about roles and permissions",
                                                   comment: "Link that points the user to learn more about roles. Clicking will open a web page."
                                                    + "Presented when the user has tries to switch to a store with incorrect permissions.")

    static let primaryButtonTitle = NSLocalizedString("Retry",
                                                      comment: "Action button that will recheck whether user has sufficient permissions to manage the store."
                                                        + "Presented when the user tries to switch to a store with incorrect permissions.")

    static let secondaryButtonTitle = NSLocalizedString("Log In With Another Account",
                                                        comment: "Action button that will restart the login flow."
                                                        + "Presented when logging in with a site address that does not have a valid Jetpack installation")
}
