struct SentryLog: Codable {
    let timestamp: Date
    let traceId: SentryId
    let level: SentryLog.Level
    let body: String
    let attributes: [String: SentryLog.Attribute]
    let severityNumber: Int?
    
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case level
        case body
        case attributes
        case severityNumber = "severity_number"
    }
    
    /// The traceId is initially an empty default value and is populated during processing;
    /// by the time processing completes, it is guaranteed to be a valid non-empty trace id.
    init(
        timestamp: Date,
        traceId: SentryId,
        level: SentryLog.Level,
        body: String,
        attributes: [String: SentryLog.Attribute],
        severityNumber: Int? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber ?? level.toSeverityNumber()
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let traceIdString = try container.decode(String.self, forKey: .traceId)
        traceId = SentryId(uuidString: traceIdString)
        level = try container.decode(SentryLog.Level.self, forKey: .level)
        body = try container.decode(String.self, forKey: .body)
        attributes = try container.decode([String: SentryLog.Attribute].self, forKey: .attributes)
        severityNumber = try container.decodeIfPresent(Int.self, forKey: .severityNumber)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(level, forKey: .level)
        try container.encode(body, forKey: .body)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(severityNumber, forKey: .severityNumber)
    }
}
