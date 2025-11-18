import Foundation

@objcMembers
@_spi(Private)
public final class SentryDiscardedEvent: NSObject, SentrySerializable {
    
    let reason: String
    let category: String
    public let quantity: UInt
    
    public init(reason: String, category: String, quantity: UInt) {
        self.reason = reason
        self.category = category
        self.quantity = quantity
        super.init()
    }
    
    public func serialize() -> [String: Any] {
        return [
            "reason": reason,
            "category": category,
            "quantity": quantity
        ]
    }
}
