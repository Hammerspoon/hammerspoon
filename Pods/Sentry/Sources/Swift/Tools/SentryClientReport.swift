@objc
@_spi(Private) public final class SentryClientReport: NSObject, SentrySerializable {
    
    @objc(initWithDiscardedEvents:dateProvider:)
    public init(discardedEvents: [SentryDiscardedEvent], dateProvider: SentryCurrentDateProvider) {
        timestamp = dateProvider.date()
        self.discardedEvents = discardedEvents
    }
    
    @objc
    public func serialize() -> [String: Any] {
        let events = discardedEvents.map { $0.serialize() }
        return [
            "timestamp": NSNumber(value: self.timestamp.timeIntervalSince1970),
            "discarded_events": events
        ]
    }
    
    /**
     * The timestamp of when the client report was created.
     */
    private let timestamp: Date
    let discardedEvents: [SentryDiscardedEvent]
    
}
