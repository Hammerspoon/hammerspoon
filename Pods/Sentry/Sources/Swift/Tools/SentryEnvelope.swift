@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryEnvelope: NSObject {
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc(initWithId:singleItem:) public convenience init(id: SentryId?, singleItem item: SentryEnvelopeItem) {
        self.init(header: SentryEnvelopeHeader(id: id), singleItem: item)
    }
    
    @objc(initWithHeader:singleItem:) public convenience init(header: SentryEnvelopeHeader, singleItem item: SentryEnvelopeItem) {
        self.init(header: header, items: [item])
    }
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc(initWithId:items:) public convenience init(id: SentryId?, items: [SentryEnvelopeItem]) {
        self.init(header: SentryEnvelopeHeader(id: id), items: items)
    }
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    convenience init(session: SentrySession) {
        let item = SentryEnvelopeItem(session: session)
        self.init(header: SentryEnvelopeHeader(id: nil), singleItem: item)
    }
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    convenience init(sessions: [SentrySession]) {
        let items = sessions.map { SentryEnvelopeItem(session: $0) }
        self.init(header: SentryEnvelopeHeader(id: nil), items: items)
    }
    
    @objc(initWithHeader:items:) public init(header: SentryEnvelopeHeader, items: [SentryEnvelopeItem]) {
        self.header = header
        self.items = items
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    convenience init(event: Event) {
        let item = SentryEnvelopeItem(event: event)
        let headerId = SentryEnvelopeHeaderHelper.headerId(from: event)
        self.init(header: SentryEnvelopeHeader(id: headerId.sentryId), singleItem: item)
    }
    
    #if !SDK_V9
    @available(*, deprecated, message: "Building the envelopes for the new SentryFeedback type is done directly in -[SentryClient captureFeedback:withScope:].")
    convenience init(userFeedback: UserFeedback) {
        let item = SentryEnvelopeItem(userFeedback: userFeedback)
        self.init(header: SentryEnvelopeHeader(id: userFeedback.eventId), singleItem: item)
    }
    #endif // !SDK_V9
    
    @objc public let header: SentryEnvelopeHeader
    @objc public let items: [SentryEnvelopeItem]
}
