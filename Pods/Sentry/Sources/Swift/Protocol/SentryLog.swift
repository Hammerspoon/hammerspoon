struct SentryLog: Codable {
    let timestamp: Date
    var traceId: SentryId
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
        traceId: SentryId? = nil,
        level: SentryLog.Level,
        body: String,
        attributes: [String: SentryLog.Attribute],
        severityNumber: Int? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId ?? SentryId.empty
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let traceIdString = try container.decode(String.self, forKey: .traceId)
        let traceId = SentryId(uuidString: traceIdString)
        let level = try container.decode(SentryLog.Level.self, forKey: .level)
        let body = try container.decode(String.self, forKey: .body)
        let attributes = try container.decode([String: SentryLog.Attribute].self, forKey: .attributes)
        let severityNumber = try container.decodeIfPresent(Int.self, forKey: .severityNumber)
        
        self.init(
            timestamp: timestamp,
            traceId: traceId,
            level: level,
            body: body,
            attributes: attributes,
            severityNumber: severityNumber
        )
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
