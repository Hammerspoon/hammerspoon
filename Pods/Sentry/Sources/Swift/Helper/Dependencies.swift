@objc(SentryDependencies) @_spi(Private) public final class Dependencies: NSObject {
    @objc public static let dispatchQueueWrapper = SentryDispatchQueueWrapper()
    @objc public static let dateProvider = SentryDefaultCurrentDateProvider()
}
