struct NSNumberDecodableWrapper: Decodable {
    let value: NSNumber?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = NSNumber(value: intValue)
        }
        // On 32-bit platforms UInt is UInt32, so we use UInt64 to cover all platforms.
        // We don't need UInt128 because NSNumber doesn't support it.
        else if let uint64Value = try? container.decode(UInt64.self) {
            value = NSNumber(value: uint64Value)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = NSNumber(value: doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            value = NSNumber(value: boolValue)
        } else {
            SentrySDKLog.warning("Failed to decode NSNumber from container for key: \(container.codingPath.last?.stringValue ?? "unknown")")
            value = nil
        }
    }
}
