@_spi(Private) @objc public class SentryThreadWrapper: NSObject {
    @objc public func sleep(forTimeInterval timeInterval: TimeInterval) {
        Thread.sleep(forTimeInterval: timeInterval)
    }
    
    @objc public func threadStarted(_ threadID: UUID) {
        // No op. Only needed for testing.
    }
    
    @objc public func threadFinished(_ threadID: UUID) {
        // No op. Only needed for testing.
    }
}
