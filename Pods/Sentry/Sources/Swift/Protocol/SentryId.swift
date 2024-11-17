import Foundation

@objcMembers
public class SentryId: NSObject {

    /**
     * A @c SentryId with an empty UUID "00000000000000000000000000000000".
     */
    public static var empty = SentryId(uuidString: "00000000-0000-0000-0000-000000000000")
    
    /**
     * Returns a 32 lowercase character hexadecimal string description of the @c SentryId, such as
     * "12c2d058d58442709aa2eca08bf20986".
     */
    public var sentryIdString: String {
        return id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
    
    private let id: UUID
    
    /**
     * Creates a @c SentryId with a random UUID.
     */
    public override init() {
        id = UUID()
    }
    
    /**
     * Creates a SentryId with the given UUID.
     */
    public init(uuid: UUID) {
        id = uuid
    }
    
    /**
     * Creates a @c SentryId from a 32 character hexadecimal string without dashes such as
     * "12c2d058d58442709aa2eca08bf20986" or a 36 character hexadecimal string such as such as
     * "12c2d058-d584-4270-9aa2-eca08bf20986".
     * @return SentryId.empty for invalid strings.
     */
    @objc(initWithUUIDString:)
    public init(uuidString: String) {
        if let id = UUID(uuidString: uuidString) {
            self.id = id
            return
        }
        
        if uuidString.count == 32 {   
            let dashedUUID = uuidString.enumerated().reduce(into: [Character]()) { partialResult, next in
                if next.offset == 8 || next.offset == 12 || next.offset == 16 || next.offset == 20 {
                    partialResult.append("-")
                }
                partialResult.append(next.element)
            }
            if let id = UUID(uuidString: String(dashedUUID)) {
                self.id = id
                return
            }
        }
        
        //The string conversion will not fail, but I'm using null coalescing to quiet swiftlint that don't let us use force unwrap.
        self.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SentryId else { return false }
        return other.id == self.id
    }
    
    override public var description: String {
        sentryIdString
    }
    
    override public var hash: Int {
        id.hashValue
    }
}
