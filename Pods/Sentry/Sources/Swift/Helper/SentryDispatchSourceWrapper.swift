@_implementationOnly import _SentryPrivate

/**
 * A wrapper around a dispatch timer source that can be subclassed for mocking in tests.
 */
@objcMembers @_spi(Private) public class SentryDispatchSourceWrapper: NSObject {

    private let queueWrapper: SentryDispatchQueueWrapper
    private let source: DispatchSourceTimer

    public init(interval: Int, leeway: Int, queue queueWrapper: SentryDispatchQueueWrapper, eventHandler: @escaping () -> Void) {

        self.queueWrapper = queueWrapper
        self.source = DispatchSource.makeTimerSource(queue: queueWrapper.queue)

        super.init()

        source.setEventHandler(handler: eventHandler)
        source.schedule(
            deadline: .now(),
            repeating: .nanoseconds(interval),
            leeway: .nanoseconds(leeway)
        )
        source.resume()
    }

    public func cancel() {
        source.cancel()
    }

    #if SENTRY_TEST || SENTRY_TEST_CI
    public var dispatchSource: DispatchSourceTimer {
        return source
    }

    public var queue: SentryDispatchQueueWrapper {
        return queueWrapper
    }
    #endif // SENTRY_TEST || SENTRY_TEST_CI
}
