import Foundation
import UIKit
import Yosemite


// MARK: - NotificationDetailsViewController
//
class NotificationDetailsViewController: UIViewController {

    /// Main TableView
    ///
    @IBOutlet private var tableView: UITableView!

    /// EntityListener: Update / Deletion Notifications.
    ///
    private lazy var entityListener: EntityListener<Note> = {
        return EntityListener(storageManager: AppDelegate.shared.storageManager, readOnlyEntity: note)
    }()

    /// Pull To Refresh Support.
    ///
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(pullToRefresh(sender:)), for: .valueChanged)
        return refreshControl
    }()

    /// Note to be displayed!
    ///
    private var note: Note! {
        didSet {
            reloadInterface()
        }
    }

    /// DetailsRow(s): Each Row is mapped to a single UI Entity!
    ///
    private var rows = [NoteDetailsRow]()



    /// Designated Initializer
    ///
    init(note: Note) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }

    /// Required!
    ///
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        assert(note != nil, "Please use the designated initializer!")
    }


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationItem()
        configureMainView()
        configureTableView()
        configureEntityListener()

        registerTableViewCells()
        reloadInterface()
    }
}


// MARK: - User Interface Initialization
//
private extension NotificationDetailsViewController {

    /// Setup: Navigation
    ///
    func configureNavigationItem() {
        // Don't show the Notifications title in the next-view's back button
        navigationItem.backBarButtonItem = UIBarButtonItem(title: String(), style: .plain, target: nil, action: nil)
    }

    /// Setup: Main View
    ///
    func configureMainView() {
        view.backgroundColor = StyleManager.tableViewBackgroundColor
    }

    /// Setup: TableView
    ///
    func configureTableView() {
        // Hide "Empty Rows"
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = StyleManager.tableViewBackgroundColor
        tableView.refreshControl = refreshControl
    }

    /// Setup: EntityListener
    ///
    func configureEntityListener() {
        entityListener.onUpsert = { [weak self] note in
            self?.note = note
        }

        entityListener.onDelete = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
            self?.displayNoteDeletedNotice()
        }
    }

    /// Registers all of the available TableViewCells.
    ///
    func registerTableViewCells() {
        let cells = [NoteDetailsHeaderTableViewCell.self, NoteDetailsCommentTableViewCell.self]

        for cell in cells {
            tableView.register(cell.loadNib(), forCellReuseIdentifier: cell.reuseIdentifier)
        }
    }
}


// MARK: - Sync
//
private extension NotificationDetailsViewController {

    /// Refresh Control's Callback.
    ///
    @IBAction func pullToRefresh(sender: UIRefreshControl) {
        WooAnalytics.shared.track(.notificationsListPulledToRefresh)

        synchronizeNotification(noteId: note.noteId) {
            sender.endRefreshing()
        }
    }

    /// Synchronizes the Notifications associated to the active WordPress.com account.
    ///
    func synchronizeNotification(noteId: Int64, onCompletion: @escaping () -> Void) {
        let action = NotificationAction.synchronizeNotification(noteId: noteId) { error in
            if let error = error {
                DDLogError("⛔️ Error synchronizing notification [\(noteId)]: \(error)")
            }

            onCompletion()
        }

        StoresManager.shared.dispatch(action)
    }
}


// MARK: - Private Methods
//
private extension NotificationDetailsViewController {

    /// Reloads all of the Details Interface
    ///
    func reloadInterface() {
        title = note.title
        rows = NoteDetailsRow.details(from: note)
        tableView.reloadData()
    }


    /// Displays a Notice onScreen, indicating that the current Note has been deleted from the Store.
    ///
    func displayNoteDeletedNotice() {
        let title = NSLocalizedString("Deleted Notification!", comment: "Deleted Notification's Title")
        let message = NSLocalizedString("The notification has been removed!", comment: "Displayed whenever a Notification that was onscreen got deleted.")
        let notice = Notice(title: title, message: message, feedbackType: .error)

        AppDelegate.shared.noticePresenter.enqueue(notice: notice)
    }


    /// Returns the DetailsRow at a given IndexPath.
    ///
    func detailsForRow(at indexPath: IndexPath) -> NoteDetailsRow {
        return rows[indexPath.row]
    }
}


// MARK: UITableViewDataSource Conformance
//
extension NotificationDetailsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = detailsForRow(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)

        setup(cell: cell, at: row)

        return cell
    }
}


// MARK: UITableViewDelegate Conformance
//
extension NotificationDetailsViewController: UITableViewDelegate {

}


// MARK: - Cell Setup
//
private extension NotificationDetailsViewController {

    /// Main Cell Setup Method
    ///
    func setup(cell: UITableViewCell, at row: NoteDetailsRow) {
        switch row {
        case .header:
            setupHeaderCell(cell, at: row)
        case .comment:
            setupCommentCell(cell, at: row)
        }
    }


    /// Setup: Header Cell
    ///
    func setupHeaderCell(_ cell: UITableViewCell, at row: NoteDetailsRow) {
        guard let headerCell = cell as? NoteDetailsHeaderTableViewCell,
            case let .header(gravatarBlock, _) = row else {
                return
        }

        let formatter = StringFormatter()
        headerCell.textLabel?.attributedText = formatter.format(block: gravatarBlock, with: .header)
    }


    /// Setup: Comment Cell
    ///
    func setupCommentCell(_ cell: UITableViewCell, at row: NoteDetailsRow) {
        guard let commentCell = cell as? NoteDetailsCommentTableViewCell,
            case let .comment(commentBlock, userBlock, _) = row else {
                return
        }

        // Setup: Properties
        let formatter = StringFormatter()
        commentCell.titleText = userBlock.text
        commentCell.detailsText = note.timestampAsDate.mediumString()
        commentCell.commentAttributedText = formatter.format(block: commentBlock, with: .body)

        let gravatarURL = userBlock.media.first?.url
        commentCell.downloadGravatar(with: gravatarURL)

        commentCell.isApproveEnabled  = commentBlock.isActionEnabled(.approve)
        commentCell.isTrashEnabled    = commentBlock.isActionEnabled(.trash)
        commentCell.isSpamEnabled     = commentBlock.isActionEnabled(.spam)
        commentCell.isApproveSelected = commentBlock.isActionOn(.approve)

        // Setup: Callbacks
        if let commentID = commentBlock.meta.identifier(forKey: .comment),
            let siteID = commentBlock.meta.identifier(forKey: .site) {

            commentCell.onSpam = { [weak self] in
                WooAnalytics.shared.track(.notificationReviewSpamTapped)
                WooAnalytics.shared.track(.notificationReviewAction, withProperties: ["type": CommentStatus.spam.rawValue])
                self?.moderateComment(siteID: siteID, commentID: commentID, doneStatus: .spam, undoStatus: .unspam)
            }

            commentCell.onTrash = { [weak self] in
                WooAnalytics.shared.track(.notificationReviewTrashTapped)
                WooAnalytics.shared.track(.notificationReviewAction, withProperties: ["type": CommentStatus.trash.rawValue])
                self?.moderateComment(siteID: siteID, commentID: commentID, doneStatus: .trash, undoStatus: .untrash)
            }

            commentCell.onApprove = { [weak self] in
                WooAnalytics.shared.track(.notificationReviewApprovedTapped)
                WooAnalytics.shared.track(.notificationReviewAction, withProperties: ["type": CommentStatus.approved.rawValue])
                self?.moderateComment(siteID: siteID, commentID: commentID, doneStatus: .approved, undoStatus: .unapproved)
            }

            commentCell.onUnapprove = { [weak self] in
                WooAnalytics.shared.track(.notificationReviewApprovedTapped)
                WooAnalytics.shared.track(.notificationReviewAction, withProperties: ["type": CommentStatus.unapproved.rawValue])
                self?.moderateComment(siteID: siteID, commentID: commentID, doneStatus: .unapproved, undoStatus: .approved)
            }
        }
    }
}


// MARK: - Comment Moderation
//
private extension NotificationDetailsViewController {

    /// Whenever the Fulfillment Action is pressed, we'll mark the order as Completed, and pull back to the previous screen.
    ///
    func moderateComment(siteID: Int, commentID: Int, doneStatus: CommentStatus, undoStatus: CommentStatus) {
        guard let done = moderateCommentAction(siteID: siteID, commentID: commentID, status: doneStatus) else {
            return
        }
        guard let undo = moderateCommentAction(siteID: siteID, commentID: commentID, status: undoStatus) else {
            return
        }

        StoresManager.shared.dispatch(done)

        displayModerationCompleteNotice(newStatus: doneStatus, onUndoAction: {
            WooAnalytics.shared.track(.notificationReviewActionUndo)
            StoresManager.shared.dispatch(undo)
        })

        navigationController?.popViewController(animated: true)
    }

    /// Displays the `Comment moderated` Notice. Whenever the `Undo` button gets pressed, we'll execute the `onUndoAction` closure.
    ///
    func displayModerationCompleteNotice(newStatus: CommentStatus, onUndoAction: @escaping () -> Void) {
        guard newStatus != .unknown else {
            return
        }

        var title = ""

        switch newStatus {
        case .approved:
            title = NSLocalizedString("Review marked as approved.", comment: "Review moderation notice message for an approved review")
        case .unapproved:
            title = NSLocalizedString("Review marked as unapproved.", comment: "Review moderation notice message for an un-approved review")
        case .spam:
            title = NSLocalizedString("Review marked as spam.", comment: "Review moderation notice message for a spam review")
        case .unspam:
            title = NSLocalizedString("Review marked as not spam.", comment: "Review moderation notice message for a not-spam review")
        case .trash:
            title = NSLocalizedString("Review moved to trash.", comment: "Review moderation notice message for a trashed review")
        case .untrash:
            title = NSLocalizedString("Review removed from trash.", comment: "Review moderation notice message for a not-trashed review")
        case .unknown:
            title = ""
        }

        let actionTitle = NSLocalizedString("Undo", comment: "Undo Action")
        let notice = Notice(title: title, message: nil, feedbackType: .success, actionTitle: actionTitle, actionHandler: onUndoAction)
        AppDelegate.shared.noticePresenter.enqueue(notice: notice)
    }

    /// Returns an comment moderation action that will result in the specified comment being updated accordingly.
    ///
    func moderateCommentAction(siteID: Int, commentID: Int, status: CommentStatus) -> Action? {
        switch status {
        case .approved:
            return CommentAction.updateApprovalStatus(siteID: siteID, commentID: commentID, isApproved: true) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Approved status. Error: \(error)")
            }

        case .unapproved:
            return CommentAction.updateApprovalStatus(siteID: siteID, commentID: commentID, isApproved: false) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Unapproved status. Error: \(error)")
            }
        case .spam:
            return CommentAction.updateSpamStatus(siteID: siteID, commentID: commentID, isSpam: true) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Spam status. Error: \(error)")
            }
        case .unspam:
            return CommentAction.updateSpamStatus(siteID: siteID, commentID: commentID, isSpam: false) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Unspam status. Error: \(error)")
            }
        case .trash:
            return CommentAction.updateTrashStatus(siteID: siteID, commentID: commentID, isTrash: true) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Trash status. Error: \(error)")
            }
        case .untrash:
            return CommentAction.updateTrashStatus(siteID: siteID, commentID: commentID, isTrash: false) { (_, error) in
                guard let error = error else {
                    WooAnalytics.shared.track(.notificationReviewActionSuccess)
                    return
                }
                WooAnalytics.shared.track(.notificationReviewActionFailed, withError: error)
                DDLogError("⛔️ Comment moderation failure for Untrash status. Error: \(error)")
            }
        case .unknown:
            DDLogError("⛔️ Comment moderation failure: attempted to update comment with unknown status.")
            return nil
        }
    }
}
