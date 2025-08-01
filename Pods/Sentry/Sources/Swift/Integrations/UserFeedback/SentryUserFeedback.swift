import Foundation

#if !SDK_V9
/// Adds additional information about what happened to an event.
/// @deprecated Use `SentryFeedback`.
@objc(SentryUserFeedback)
@available(*, deprecated, message: "Use SentryFeedback.")
open class UserFeedback: NSObject, SentrySerializable {
    
    /// The eventId of the event to which the user feedback is associated.
    @objc open private(set) var eventId: SentryId
    
    /// The name of the user.
    @objc open var name: String
    
    /// The email of the user.
    @objc open var email: String
    
    /// Comments of the user about what happened.
    @objc open var comments: String
    
    /// Initializes SentryUserFeedback and sets the required eventId.
    /// - Parameter eventId: The eventId of the event to which the user feedback is associated.
    @objc public init(eventId: SentryId) {
        self.eventId = eventId
        self.email = ""
        self.name = ""
        self.comments = ""
        super.init()
    }
    
    open func serialize() -> [String: Any] {
        return [
            "event_id": eventId.sentryIdString,
            "email": email,
            "name": name,
            "comments": comments
        ]
    }
}
#endif // !SDK_V9
