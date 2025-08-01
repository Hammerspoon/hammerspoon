@_implementationOnly import _SentryPrivate
import Foundation

/**
 * Subclass of SentryEvent so we can add the Decodable implementation via a Swift extension. We need
 * this due to our mixed use of public Swift and ObjC classes. We could avoid this class by
 * converting SentryReplayEvent back to ObjC, but we rather accept this tradeoff as we want to
 * convert all public classes to Swift in the future. This does not need to be public, but was previously
 * defined in objc and was public. In the next major version of the SDK we should make it `internal` and `final`
 * and remove the `@objc` annotation.
 *
 * @note: We can’t add the extension for Decodable directly on SentryEvent, because we get an error
 * in SentryReplayEvent: 'required' initializer 'init(from:)' must be provided by subclass of
 * 'Event' Once we add the initializer with required convenience public init(from decoder: any
 * Decoder) throws { fatalError("init(from:) has not been implemented")
 * }
 * we get the error initializer 'init(from:)' is declared in extension of 'Event' and cannot be
 * overridden. Therefore, we add the Decodable implementation not on the Event, but to a subclass of
 * the event.
 */
@objc(SentryEventDecodable)
open class SentryEventDecodable: Event, Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case message
        // Leaving out error on purpose, it's not serialized.
        case timestamp
        case startTimestamp = "start_timestamp"
        case level
        case platform
        case logger
        case serverName = "server_name"
        case releaseName = "release"
        case dist
        case environment
        case transaction
        case type
        case tags
        case extra
        case sdk
        case modules
        case fingerprint
        case user
        case context = "contexts"
        case threads
        case exception
        case stacktrace
        case debugMeta = "debug_meta"
        case breadcrumbs
        case request
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()

        let eventIdAsString = try container.decode(String.self, forKey: .eventId)
        SentryEventSwiftHelper.setEventIdString(eventIdAsString, event: self)
        self.message = try container.decodeIfPresent(SentryMessageDecodable.self, forKey: .message)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.startTimestamp = try container.decodeIfPresent(Date.self, forKey: .startTimestamp)

        if let rawLevel = try container.decodeIfPresent(String.self, forKey: .level) {
            let level = SentryLevelHelper.levelForName(rawLevel)
            SentryLevelBridge.setBreadcrumbLevelOn(self, level: level.rawValue)
        } else {
            SentryLevelBridge.setBreadcrumbLevelOn(self, level:
            SentryLevel.none.rawValue)
        }

        self.platform = try container.decode(String.self, forKey: .platform)
        self.logger = try container.decodeIfPresent(String.self, forKey: .logger)
        self.serverName = try container.decodeIfPresent(String.self, forKey: .serverName)
        self.releaseName = try container.decodeIfPresent(String.self, forKey: .releaseName)
        self.dist = try container.decodeIfPresent(String.self, forKey: .dist)
        self.environment = try container.decodeIfPresent(String.self, forKey: .environment)
        self.transaction = try container.decodeIfPresent(String.self, forKey: .transaction)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.tags = try container.decodeIfPresent([String: String].self, forKey: .tags)

        self.extra = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .extra)
        }
        self.sdk = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .sdk)
        }

        self.modules = try container.decodeIfPresent([String: String].self, forKey: .modules)
        self.fingerprint = try container.decodeIfPresent([String].self, forKey: .fingerprint)
        self.user = try container.decodeIfPresent(UserDecodable.self, forKey: .user)
        
        self.context = decodeArbitraryData {
            try container.decodeIfPresent([String: [String: ArbitraryData]].self, forKey: .context)
        }

        if let rawThreads = try container.decodeIfPresent([String: [SentryThreadDecodable]].self, forKey: .threads) {
            self.threads = rawThreads["values"]
        }
            
        if let rawExceptions = try container.decodeIfPresent([String: [ExceptionDecodable]].self, forKey: .exception) {
            self.exceptions = rawExceptions["values"]
        }
        
        self.stacktrace = try container.decodeIfPresent(SentryStacktraceDecodable.self, forKey: .stacktrace)
        
        if let rawDebugMeta = try container.decodeIfPresent([String: [DebugMetaDecodable]].self, forKey: .debugMeta) {
            self.debugMeta = rawDebugMeta["images"]
        }
        
        self.breadcrumbs = try container.decodeIfPresent([BreadcrumbDecodable].self, forKey: .breadcrumbs)
        self.request = try container.decodeIfPresent(SentryRequestDecodable.self, forKey: .request)
    }
}
