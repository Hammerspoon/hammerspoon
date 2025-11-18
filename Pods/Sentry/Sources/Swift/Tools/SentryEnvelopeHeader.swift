@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryEnvelopeHeader: NSObject {
    /**
     * Initializes an @c SentryEnvelopeHeader object with the specified eventId.
     * @note Sets the @c sdkInfo from @c SentryMeta.
     * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
     * related to event.
     */
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc public convenience init(id eventId: SentryId?) {
        self.init(id: eventId, traceContext: nil)
    }
    
    /**
     * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId and @c traceContext.
     * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
     * attachment related to event.
     * @param traceContext Current trace state.
     */
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc public convenience init(id eventId: SentryId?, traceContext: TraceContext?) {
        self.init(id: eventId, sdkInfo: SentrySdkInfo.global(), traceContext: traceContext)
    }
    
    /**
     * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId, @c skdInfo and
     * @c traceContext. It is recommended to use @c initWithId:traceContext: because it sets the
     * @c sdkInfo for you.
     * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
     * attachment related to event.
     * @param sdkInfo Describes the Sentry SDK. Can be @c nil for backwards compatibility. New
     * instances should always provide a version.
     * @param traceContext Current trace state.
     */
    @objc public
    init(id eventId: SentryId?, sdkInfo: SentrySdkInfo?, traceContext: TraceContext?) {
        self.eventId = eventId
        self.sdkInfo = sdkInfo
        self.traceContext = traceContext
    }
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc public static func empty() -> Self {
        Self(id: nil, traceContext: nil)
    }
    
    /**
     * The event identifier, if available.
     * An event id exist if the envelope contains an event of items within it are related. i.e
     * Attachments
     */
    @objc public var eventId: SentryId?
    @objc public var sdkInfo: SentrySdkInfo?
    @objc public var traceContext: TraceContext?
    
    /**
     * The timestamp when the event was sent from the SDK as string in RFC 3339 format. Used
     * for clock drift correction of the event timestamp. The time zone must be UTC.
     *
     * The timestamp should be generated as close as possible to the transmision of the event,
     * so that the delay between sending the envelope and receiving it on the server-side is
     * minimized.
     */
    @objc public var sentAt: Date?
}
