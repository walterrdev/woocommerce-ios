import Foundation

/// Abstracts the Analytics engine.
///
public protocol Analytics {
    /// Initialize the analytics engine
    ///
    func initialize()

    /// Track a specific event with associated properties and an associated error (that is translated to properties)
    ///
    /// - Parameters:
    ///   - eventName: the event name
    ///   - properties: a collection of properties related to the event
    ///   - error: the error to track
    ///
    func track(_ eventName: String, properties: [AnyHashable: Any]?, error: Error?)

    /// Refresh the tracking metadata for the currently logged-in or anonymous user.
    /// It's good to call this function after a user logs in or out of the app.
    ///
    func refreshUserData()

    /// Sets the boolean flag to signal that the user has opted out of analytics
    /// It will trigger a call to `refreshUserData` before starting tracking again.
    ///
    /// - Parameters:
    ///   - optedOut: Boolean flag. If true, we stop tracking.
    func setUserHasOptedOut(_ optedOut: Bool)

    /// Check user opt-in for analytics
    ///
    var userHasOptedIn: Bool { get set }

    /// AnalyticsProvider: Interface to the actual analytics implementation
    ///
    var analyticsProvider: AnalyticsProvider { get }
}
