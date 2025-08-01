import Foundation

@objcMembers
public class SentryFeedback: NSObject {
    @objc public enum SentryFeedbackSource: Int {
        public var serialize: String {
            switch self {
            case .widget: return "widget"
            case .custom: return "custom"
            }
        }
        
        case widget
        case custom
    }
    
    var name: String?
    var email: String?
    var message: String
    var source: SentryFeedbackSource
    @_spi(Private) public let eventId: SentryId
    
    /// Data objects for any attachments. Currently the web UI only supports showing one attached image, like for a screenshot.
    private var attachments: [Data]?
    
    /// The event id that this feedback is associated with, like a crash report.
    var associatedEventId: SentryId?
    
    /// - parameters:
    ///   - associatedEventId The ID for an event you'd like associated with the feedback.
    ///   - attachments Data objects for any attachments. Currently the web UI only supports showing one attached image, like for a screenshot.
    @objc public init(message: String, name: String?, email: String?, source: SentryFeedbackSource = .widget, associatedEventId: SentryId? = nil, attachments: [Data]? = nil) {
        self.eventId = SentryId()
        self.name = name
        self.email = email
        self.message = message
        self.source = source
        self.associatedEventId = associatedEventId
        self.attachments = attachments
        super.init()
    }
}

extension SentryFeedback: SentrySerializable {
    public func serialize() -> [String: Any] {
        let numberOfOptionalItems = (name == nil ? 0 : 1) + (email == nil ? 0 : 1) + (associatedEventId == nil ? 0 : 1)
        var dict = [String: Any](minimumCapacity: 2 + numberOfOptionalItems)
        dict["message"] = message
        if let name = name {
            dict["name"] = name
        }
        if let email = email {
            dict["contact_email"] = email
        }
        if let associatedEventId = associatedEventId {
            dict["associated_event_id"] = associatedEventId.sentryIdString
        }
        dict["source"] = source.serialize
        
        return dict
    }
}
 
// MARK: Public
extension SentryFeedback {
    /// - note: This dictionary is to pass to the block `SentryUserFeedbackConfiguration.onSubmitSuccess`, describing the contents submitted. This is different from the serialized form of the feedback for envelope transmission, because there are some internal details in that serialization that are irrelevant to the consumer and are not available at the time `onSubmitSuccess` is called.
    func dataDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "message": message
        ]
        if let name = name {
            dict["name"] = name
        }
        if let email = email {
            dict["email"] = email
        }
        if let attachments = attachments {
            dict["attachments"] = attachments
        }
        return dict
    }
    
    /**
     * - note: Currently there is only a single attachment possible, for the screenshot, of which there can be only one.
     */
    @_spi(Private) public func attachmentsForEnvelope() -> [Attachment] {
        var items = [Attachment]()
        if let screenshot = attachments?.first {
            items.append(Attachment(data: screenshot, filename: "screenshot.png", contentType: "application/png"))
        }
        return items
    }
}
