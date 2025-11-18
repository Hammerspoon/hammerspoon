@_spi(Private) @objc public final class SentryMeasurementValue: NSObject {
    
    @objc public let value: NSNumber
    @objc public let unit: MeasurementUnit?
    
    @objc public init(value: NSNumber) {
        self.value = value
        self.unit = nil
    }
    
    @objc public init(value: NSNumber, unit: MeasurementUnit) {
        self.value = value
        self.unit = unit
    }
    
    @objc public func serialize() -> [String: Any] {
        var result: [String: Any] = [
            "value": self.value
        ]
        if let unit {
            result["unit"] = unit.unit
        }
        return result
    }
}
