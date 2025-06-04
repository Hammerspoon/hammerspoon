@_implementationOnly import _SentryPrivate
import Foundation

extension SentryEventDecodable: Decodable {
    
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
        self.eventId = SentryId(uuidString: eventIdAsString)
        self.message = try container.decodeIfPresent(SentryMessage.self, forKey: .message)
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
        self.user = try container.decodeIfPresent(User.self, forKey: .user)
        
        self.context = decodeArbitraryData {
            try container.decodeIfPresent([String: [String: ArbitraryData]].self, forKey: .context)
        }

        if let rawThreads = try container.decodeIfPresent([String: [SentryThread]].self, forKey: .threads) {
            self.threads = rawThreads["values"]
        }
            
        if let rawExceptions = try container.decodeIfPresent([String: [Exception]].self, forKey: .exception) {
            self.exceptions = rawExceptions["values"]
        }
        
        self.stacktrace = try container.decodeIfPresent(SentryStacktrace.self, forKey: .stacktrace)
        
        if let rawDebugMeta = try container.decodeIfPresent([String: [DebugMeta]].self, forKey: .debugMeta) {
            self.debugMeta = rawDebugMeta["images"]
        }
        
        self.breadcrumbs = try container.decodeIfPresent([Breadcrumb].self, forKey: .breadcrumbs)
        self.request = try container.decodeIfPresent(SentryRequest.self, forKey: .request)
    }
}
