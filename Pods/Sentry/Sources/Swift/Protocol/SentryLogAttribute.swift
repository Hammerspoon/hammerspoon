extension SentryLog {
    /// A typed attribute that can be attached to structured log entries.
    ///
    /// `Attribute` provides a type-safe way to store structured data alongside log messages.
    /// Supports String, Bool, Int, and Double types.
    @objc(SentryStructuredLogAttribute)
    @objcMembers
    public final class Attribute: NSObject {
        /// The type identifier for this attribute ("string", "boolean", "integer", "double")
        public let type: String
        /// The actual value stored in this attribute
        public let value: Any
        
        public init(string value: String) {
            self.type = "string"
            self.value = value
            super.init()
        }
        
        public init(boolean value: Bool) {
            self.type = "boolean"
            self.value = value
            super.init()
        }
        
        public init(integer value: Int) {
            self.type = "integer"
            self.value = value
            super.init()
        }
        
        public init(double value: Double) {
            self.type = "double"
            self.value = value
            super.init()
        }
        
        /// Creates a double attribute from a float value
        public init(float value: Float) {
            self.type = "double"
            self.value = Double(value)
            super.init()
        }
        
        internal init(value: Any) {
            switch value {
            case let stringValue as String:
                self.type = "string"
                self.value = stringValue
            case let boolValue as Bool:
                self.type = "boolean"
                self.value = boolValue
            case let intValue as Int:
                self.type = "integer"
                self.value = intValue
            case let doubleValue as Double:
                self.type = "double"
                self.value = doubleValue
            case let floatValue as Float:
                self.type = "double"
                self.value = Double(floatValue)
            default:
                // For any other type, convert to string representation
                self.type = "string"
                self.value = String(describing: value)
                    }
        super.init()
    }
    }
}

// MARK: - Internal Codable Support
@_spi(Private) extension SentryLog.Attribute: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
        case type
    }
    
    @_spi(Private) public convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(String.self, forKey: .type)
        
        let value: Any
        switch type {
        case "string":
            value = try container.decode(String.self, forKey: .value)
        case "boolean":
            value = try container.decode(Bool.self, forKey: .value)
        case "integer":
            value = try container.decode(Int.self, forKey: .value)
        case "double":
            value = try container.decode(Double.self, forKey: .value)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
        
        self.init(value: value)
    }
    
    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        
        switch type {
        case "string":
            guard let stringValue = value as? String else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected String but got \(Swift.type(of: value))"))
            }
            try container.encode(stringValue, forKey: .value)
        case "boolean":
            guard let boolValue = value as? Bool else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Bool but got \(Swift.type(of: value))"))
            }
            try container.encode(boolValue, forKey: .value)
        case "integer":
            guard let intValue = value as? Int else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Int but got \(Swift.type(of: value))"))
            }
            try container.encode(intValue, forKey: .value)
        case "double":
            guard let doubleValue = value as? Double else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Double but got \(Swift.type(of: value))"))
            }
            try container.encode(doubleValue, forKey: .value)
        default:
            try container.encode(String(describing: value), forKey: .value)
        }
    }
}
