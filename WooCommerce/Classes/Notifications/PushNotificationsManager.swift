import Combine
import Experiments
import Foundation
import UserNotifications
import AutomatticTracks
import Yosemite



/// PushNotificationsManager: Encapsulates all the tasks related to Push Notifications Auth + Registration + Handling.
///
final class PushNotificationsManager: PushNotesManager {

    /// PushNotifications Configuration
    ///
    let configuration: PushNotificationsConfiguration

    /// An observable that emits values when the Remote Notifications are received while the app is
    /// in the foreground.
    ///
    var foregroundNotifications: AnyPublisher<PushNotification, Never> {
        foregroundNotificationsSubject.eraseToAnyPublisher()
    }

    /// Mutable reference to `foregroundNotifications`.
    private let foregroundNotificationsSubject = PassthroughSubject<PushNotification, Never>()

    /// An observable that emits values when the user taps to view the in-app notification while the app is
    /// in the foreground.
    ///
    var foregroundNotificationsToView: AnyPublisher<PushNotification, Never> {
        foregroundNotificationsToViewSubject.eraseToAnyPublisher()
    }

    /// Mutable reference to `foregroundNotificationsToView`.
    private let foregroundNotificationsToViewSubject = PassthroughSubject<PushNotification, Never>()

    /// An observable that emits values when a Remote Notification is received while the app is
    /// in inactive.
    ///
    var inactiveNotifications: AnyPublisher<PushNotification, Never> {
        inactiveNotificationsSubject.eraseToAnyPublisher()
    }

    /// Mutable reference to `inactiveNotifications`
    private let inactiveNotificationsSubject = PassthroughSubject<PushNotification, Never>()

    /// Returns the current Application's State
    ///
    private var applicationState: UIApplication.State {
        return configuration.application.applicationState
    }

    /// Apple's Push Notifications DeviceToken
    ///
    private var deviceToken: String? {
        get {
            return configuration.defaults.object(forKey: .deviceToken)
        }
        set {
            configuration.defaults.set(newValue, forKey: .deviceToken)
        }
    }

    /// WordPress.com Device Identifier
    ///
    private var deviceID: String? {
        get {
            return configuration.defaults.object(forKey: .deviceID)
        }
        set {
            configuration.defaults.set(newValue, forKey: .deviceID)
        }
    }

    private var siteID: Int64? {
        stores.sessionManager.defaultStoreID
    }

    private var stores: StoresManager {
        configuration.storesManager
    }

    /// Initializes the PushNotificationsManager.
    ///
    /// - Parameter configuration: PushNotificationsConfiguration Instance that should be used.
    ///
    init(configuration: PushNotificationsConfiguration = .default) {
        self.configuration = configuration
    }
}


// MARK: - Public Methods
//
extension PushNotificationsManager {

    /// Requests Authorization to receive Push Notifications, *only* when the current Status is not determined.
    ///
    /// - Parameter onCompletion: Closure to be executed on completion. Receives a Boolean indicating if we've got Push Permission.
    ///
    func ensureAuthorizationIsRequested(onCompletion: ((Bool) -> Void)? = nil) {
        let nc = configuration.userNotificationsCenter

        nc.loadAuthorizationStatus(queue: .main) { status in
            guard status == .notDetermined else {
                onCompletion?(status == .authorized)
                return
            }

            nc.requestAuthorization(queue: .main) { allowed in
                let stat: WooAnalyticsStat = allowed ? .pushNotificationOSAlertAllowed : .pushNotificationOSAlertDenied
                ServiceLocator.analytics.track(stat)

                onCompletion?(allowed)
            }

            ServiceLocator.analytics.track(.pushNotificationOSAlertShown)
        }
    }


    /// Registers the Application for Remote Notifications.
    ///
    func registerForRemoteNotifications() {
        DDLogInfo("📱 Registering for Remote Notifications...")
        configuration.application.registerForRemoteNotifications()
    }


    /// Unregisters the Application from WordPress.com Push Notifications Service.
    ///
    func unregisterForRemoteNotifications() {
        DDLogInfo("📱 Unregistering For Remote Notifications...")

        unregisterSupportDevice()

        unregisterDotcomDeviceIfPossible() { error in
            if let error = error {
                DDLogError("⛔️ Unable to unregister from WordPress.com Push Notifications: \(error)")
                return
            }

            DDLogInfo("📱 Successfully unregistered from WordPress.com Push Notifications!")
            self.deviceID = nil
            self.deviceToken = nil
        }
    }


    /// Resets the Badge Count.
    ///
    func resetBadgeCount(type: Note.Kind) {
        guard let siteID = siteID else {
            return
        }
        let action = NotificationCountAction.reset(siteID: siteID, type: type) { [weak self] in
            self?.loadNotificationCountAndUpdateApplicationBadgeNumberAndPostNotifications(siteID: siteID, type: type)
        }
        stores.dispatch(action)
    }

    func resetBadgeCountForAllStores(onCompletion: @escaping () -> Void) {
        let action = NotificationCountAction.resetForAllSites() { [weak self] in
            guard let self = self else { return }
            self.configuration.application.applicationIconBadgeNumber = AppIconBadgeNumber.clearsBadgeAndPotentiallyAllPushNotifications
            self.removeAllNotifications()
            onCompletion()
        }
        stores.dispatch(action)
    }

    func reloadBadgeCount() {
        guard let siteID = siteID else {
            return
        }
        loadNotificationCountAndUpdateApplicationBadgeNumberAndPostNotifications(siteID: siteID, type: nil)
    }

    /// Registers the Device Token agains WordPress.com backend, if there's a default account.
    ///
    /// - Parameters:
    ///     - tokenData: APNS's Token Data
    ///     - defaultStoreID: Default WooCommerce Store ID
    ///
    func registerDeviceToken(with tokenData: Data, defaultStoreID: Int64) {
        let newToken = tokenData.hexString

        if let _ = deviceToken, deviceToken != newToken {
            DDLogInfo("📱 Device Token Changed! OLD: [\(String(describing: deviceToken))] NEW: [\(newToken)]")
        } else {
            DDLogInfo("📱 Device Token Received: [\(newToken)]")
        }

        deviceToken = newToken

        // Register in Support's Infrastructure
        registerSupportDevice(with: newToken)

        // Register in the Dotcom's Infrastructure
        registerDotcomDevice(with: newToken, defaultStoreID: defaultStoreID) { (device, error) in
            guard let deviceID = device?.deviceID else {
                DDLogError("⛔️ Dotcom Push Notifications Registration Failure: \(error.debugDescription)")
                return
            }

            DDLogVerbose("📱 Successfully registered Device ID \(deviceID) for Push Notifications")
            self.deviceID = deviceID
        }
    }


    /// Handles Push Notifications Registration Errors. This method unregisters the current device from the WordPress.com
    /// Push Service.
    ///
    /// - Parameter error: Error received after attempting to register for Push Notifications.
    ///
    func registrationDidFail(with error: Error) {
        DDLogError("⛔️ Push Notifications Registration Failure: \(error)")
        unregisterForRemoteNotifications()
    }


    /// Handles a Remote Push Notification Payload. On completion the `completionHandler` will be executed.
    ///
    func handleNotification(_ userInfo: [AnyHashable: Any],
                            onBadgeUpdateCompletion: @escaping () -> Void,
                            completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DDLogVerbose("📱 Push Notification Received: \n\(userInfo)\n")

        // Badge: Update
        if let typeString = userInfo.string(forKey: APNSKey.type),
            let type = Note.Kind(rawValue: typeString),
            let siteID = siteID,
            let notificationSiteID = userInfo[APNSKey.siteID] as? Int64 {
            incrementNotificationCount(siteID: notificationSiteID, type: type, incrementCount: 1) { [weak self] in
                self?.loadNotificationCountAndUpdateApplicationBadgeNumberAndPostNotifications(siteID: siteID, type: type)
                onBadgeUpdateCompletion()
            }
        }

        // Badge: Reset
        guard userInfo.string(forKey: APNSKey.type) != PushType.badgeReset else {
            return
        }

        // Analytics
        trackNotification(with: userInfo)

        // Handling!
        let handlers = [
            handleSupportNotification,
            handleForegroundNotification,
            handleInactiveNotification,
            handleBackgroundNotification
        ]

        for handler in handlers {
            if handler(userInfo, completionHandler) {
                break
            }
        }
    }
}

// MARK: - Notification count & app badge number update
//
private extension PushNotificationsManager {
    func incrementNotificationCount(siteID: Int64, type: Note.Kind, incrementCount: Int, onCompletion: @escaping () -> Void) {
        let action = NotificationCountAction.increment(siteID: siteID, type: type, incrementCount: incrementCount, onCompletion: onCompletion)
        stores.dispatch(action)
    }

    func loadNotificationCountAndUpdateApplicationBadgeNumberAndPostNotifications(siteID: Int64, type: Note.Kind?) {
        loadNotificationCountAndUpdateApplicationBadgeNumber(siteID: siteID)
        postBadgeReloadNotifications(type: type)
    }

    func loadNotificationCountAndUpdateApplicationBadgeNumber(siteID: Int64) {
        let action = NotificationCountAction.load(siteID: siteID, type: .allKinds) { [weak self] count in
            self?.configuration.application.applicationIconBadgeNumber = count > 0 ?
                AppIconBadgeNumber.hasUnreadPushNotifications: AppIconBadgeNumber.clearsBadgeOnly
        }
        stores.dispatch(action)
    }

    func postBadgeReloadNotifications(type: Note.Kind?) {
        guard let type = type else {
            postBadgeReloadNotification(type: .comment)
            postBadgeReloadNotification(type: .storeOrder)
            return
        }
        postBadgeReloadNotification(type: type)
    }

    func postBadgeReloadNotification(type: Note.Kind) {
        switch type {
        case .comment:
            NotificationCenter.default.post(name: .reviewsBadgeReloadRequired, object: nil)
        case .storeOrder:
            NotificationCenter.default.post(name: .ordersBadgeReloadRequired, object: nil)
        default:
            break
        }
    }

    func removeAllNotifications() {
        configuration.userNotificationsCenter.removeAllNotifications()
    }
}

// MARK: - Push Handlers
//
private extension PushNotificationsManager {

    /// Handles a Support Remote Notification
    ///
    /// - Note: This should actually be *private*. BUT: for unit testing purposes we'll have to keep it public. Sorry.
    ///
    /// - Parameters:
    ///     - userInfo: The Notification's Payload
    ///     - completionHandler: A callback, to be executed on completion
    ///
    /// - Returns: True when handled. False otherwise
    ///
    func handleSupportNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {

        guard userInfo.string(forKey: APNSKey.type) == PushType.zendesk else {
                return false
        }

        self.configuration.supportManager.pushNotificationReceived()

        trackNotification(with: userInfo)

        if applicationState == .inactive {
            self.configuration.supportManager.displaySupportRequest(using: userInfo)
        }

        completionHandler(.newData)

        return true
    }


    /// Handles a Notification while in Foreground Mode
    ///
    /// - Parameters:
    ///     - userInfo: The Notification's Payload
    ///     - completionHandler: A callback, to be executed on completion
    ///
    /// - Returns: True when handled. False otherwise
    ///
    func handleForegroundNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard applicationState == .active, let _ = userInfo[APNSKey.identifier] else {
            return false
        }

        if let foregroundNotification = PushNotification.from(userInfo: userInfo) {
            configuration.application
                .presentInAppNotification(title: foregroundNotification.title,
                                          subtitle: foregroundNotification.subtitle,
                                          message: foregroundNotification.message,
                                          actionTitle: Localization.viewInAppNotification) { [weak self] in
                    guard let self = self else { return }
                    self.presentDetails(for: foregroundNotification)
                    self.foregroundNotificationsToViewSubject.send(foregroundNotification)
                    ServiceLocator.analytics.track(.viewInAppPushNotificationPressed, withProperties: [AnalyticKey.type: foregroundNotification.kind.rawValue])
                }

            foregroundNotificationsSubject.send(foregroundNotification)
        }

        synchronizeNotifications(completionHandler: completionHandler)

        return true
    }


    /// Handles a Notification while in Inactive Mode
    ///
    /// - Parameters:
    ///     - userInfo: The Notification's Payload
    ///     - completionHandler: A callback, to be executed on completion
    ///
    /// - Returns: True when handled. False otherwise
    ///
    func handleInactiveNotification(_ userInfo: [AnyHashable: Any], completionHandler: (UIBackgroundFetchResult) -> Void) -> Bool {
        guard applicationState == .inactive else {
            return false
        }

        DDLogVerbose("📱 Handling Notification in Inactive State")

        if let notification = PushNotification.from(userInfo: userInfo) {
            presentDetails(for: notification)

            inactiveNotificationsSubject.send(notification)
        }

        completionHandler(.newData)

        return true
    }


    /// Handles a Notification while in Background Mode
    ///
    /// - Parameters:
    ///     - userInfo: The Notification's Payload
    ///     - completionHandler: A callback, to be executed on completion
    ///
    /// - Returns: True when handled. False otherwise
    ///
    func handleBackgroundNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard applicationState == .background, let _ = userInfo[APNSKey.identifier] else {
            return false
        }

        synchronizeNotifications(completionHandler: completionHandler)

        return true
    }
}

private extension PushNotificationsManager {
    func presentDetails(for notification: PushNotification) {
        // Handling the product review notifications (`.comment`) has been moved to
        // `ReviewsCoordinator`. All other push notification handling should be in a coordinator
        // in the future too.
        if notification.kind != .comment {
            configuration.application.presentNotificationDetails(for: Int64(notification.noteID))
        }
    }
}


// MARK: - Dotcom Device Registration
//
private extension PushNotificationsManager {

    /// Registers an APNS DeviceToken in the WordPress.com backend.
    ///
    func registerDotcomDevice(with deviceToken: String, defaultStoreID: Int64, onCompletion: @escaping (DotcomDevice?, Error?) -> Void) {
        let device = APNSDevice(deviceToken: deviceToken)
        let action = NotificationAction.registerDevice(device: device,
                                                       applicationId: WooConstants.pushApplicationID,
                                                       applicationVersion: Bundle.main.version,
                                                       defaultStoreID: defaultStoreID,
                                                       onCompletion: onCompletion)
        stores.dispatch(action)
    }

    /// Unregisters the known DeviceID (if any) from the Push Notifications Backend.
    ///
    func unregisterDotcomDeviceIfPossible(onCompletion: @escaping (Error?) -> Void) {
        guard let knownDeviceId = deviceID else {
            onCompletion(nil)
            return
        }

        unregisterDotcomDevice(with: knownDeviceId, onCompletion: onCompletion)
    }

    /// Unregisters a given DeviceID from the Push Notifications backend.
    ///
    func unregisterDotcomDevice(with deviceID: String, onCompletion: @escaping (Error?) -> Void) {
        let action = NotificationAction.unregisterDevice(deviceId: deviceID, onCompletion: onCompletion)
        configuration.storesManager.dispatch(action)
    }
}

// MARK: - Support Relay
//
private extension PushNotificationsManager {

    /// Registers the specified DeviceToken for Support Push Notifications.
    ///
    func registerSupportDevice(with deviceToken: String) {
        configuration.supportManager.deviceTokenWasReceived(deviceToken: deviceToken)
    }

    /// Unregisters the specified DeviceToken for Support Push Notifications.
    ///
    func unregisterSupportDevice() {
        configuration.supportManager.unregisterForRemoteNotifications()
    }
}


// MARK: - Analytics
//
private extension PushNotificationsManager {

    /// Tracks the specified Notification's Payload.
    ///
    func trackNotification(with userInfo: [AnyHashable: Any]) {
        var properties = [String: Any]()

        if let noteID = userInfo.string(forKey: APNSKey.identifier) {
            properties[AnalyticKey.identifier] = noteID
        }

        if let type = userInfo.string(forKey: APNSKey.type) {
            properties[AnalyticKey.type] = type
        }

        if let theToken = deviceToken {
            properties[AnalyticKey.token] = theToken
        }

        if let siteID = siteID,
           let notificationSiteID = userInfo[APNSKey.siteID] as? Int64 {
            properties[AnalyticKey.fromSelectedSite] = siteID == notificationSiteID
        }

        switch applicationState {
        case .inactive:
            ServiceLocator.analytics.track(.pushNotificationAlertPressed, withProperties: properties)
        default:
            properties[AnalyticKey.appState] = applicationState.rawValue
            ServiceLocator.analytics.track(.pushNotificationReceived, withProperties: properties)
        }
    }
}


// MARK: - Yosemite Methods
//
private extension PushNotificationsManager {

    /// Synchronizes all of the Notifications. On success this method will always signal `.newData`, and `.noData` on error.
    ///
    func synchronizeNotifications(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let action = NotificationAction.synchronizeNotifications { error in
            DDLogInfo("📱 Finished Synchronizing Notifications!")

            let result = (error == nil) ? UIBackgroundFetchResult.newData : .noData
            completionHandler(result)
        }

        DDLogInfo("📱 Synchronizing Notifications in \(applicationState.description) State...")
        configuration.storesManager.dispatch(action)
    }
}

// MARK: - PushNotification Extension

private extension PushNotification {
    static func from(userInfo: [AnyHashable: Any]) -> PushNotification? {
        guard let noteID = userInfo.integer(forKey: APNSKey.identifier),
              let alert = userInfo.dictionary(forKey: APNSKey.aps)?.dictionary(forKey: APNSKey.alert),
              let title = alert.string(forKey: APNSKey.alertTitle),
              let type = userInfo.string(forKey: APNSKey.type),
              let noteKind = Note.Kind(rawValue: type) else {
                  return nil
              }
        let subtitle = alert.string(forKey: APNSKey.alertSubtitle)
        let message = alert.string(forKey: APNSKey.alertMessage)
        return PushNotification(noteID: noteID, kind: noteKind, title: title, subtitle: subtitle, message: message)
    }
}

// MARK: - App Icon Badge Number

enum AppIconBadgeNumber {
    /// Indicates that there are unread push notifications in Notification Center.
    static let hasUnreadPushNotifications = 1
    /// An unofficial workaround to clear the app icon badge without clearing all push notifications in Notification Center.
    static let clearsBadgeOnly = -1
    /// Clears the app icon badge and potentially all push notifications in Notification Center.
    static let clearsBadgeAndPotentiallyAllPushNotifications = 0
}

// MARK: - Private Types
//
private enum APNSKey {
    static let aps = "aps"
    static let alert = "alert"
    static let alertTitle = "title"
    static let alertSubtitle = "subtitle"
    static let alertMessage = "body"
    static let identifier = "note_id"
    static let type = "type"
    static let siteID = "blog"
}

private enum AnalyticKey {
    static let identifier = "push_notification_note_id"
    static let type = "push_notification_type"
    static let token = "push_notification_token"
    static let fromSelectedSite = "is_from_selected_site"
    static let appState = "app_state"
}

private enum PushType {
    static let badgeReset = "badge-reset"
    static let zendesk = "zendesk"
}

private extension PushNotificationsManager {
    enum Localization {
        static let viewInAppNotification = NSLocalizedString("View", comment: "Action title in an in-app notification to view more details.")
    }
}
