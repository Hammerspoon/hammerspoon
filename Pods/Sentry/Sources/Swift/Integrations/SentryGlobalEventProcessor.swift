@_spi(Private) public typealias SentryEventProcessor = (Event) -> Event?

@_spi(Private) @objc public final class SentryGlobalEventProcessor: NSObject {
    
    var processors = [SentryEventProcessor]()
    
    @objc(addEventProcessor:) public func add(_ newProcessor: @escaping SentryEventProcessor) {
        processors.append(newProcessor)
    }
    
    /// Only for testing
    func removeAllProcessors() {
        self.processors.removeAll()
    }
    
    @objc @discardableResult public func reportAll(_ event: Event) -> Event? {
        var mutableEvent = event
        for processor in processors {
            if let newEvent = processor(mutableEvent) {
                mutableEvent = newEvent
            } else {
                return nil
            }
        }
        return mutableEvent
    }
}
