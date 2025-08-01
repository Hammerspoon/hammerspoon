#import "SentryDataCategory.h"
#import "SentryDefines.h"
#import "SentryDiscardReason.h"
#import "SentryTransport.h"

@class SentryAttachment;
@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryEvent;
@class SentryFeedback;
@class SentryOptions;
@class SentrySession;
@class SentryTraceContext;
@class SentryUserFeedback;

NS_ASSUME_NONNULL_BEGIN

/**
 * This class converts data objects to a SentryEnvelope and passes the SentryEnvelope to the
 * SentryTransport. It is a layer between the SentryClient and the transport to keep the
 * SentryClient small and make testing easier for the SentryClient.
 */
@interface SentryTransportAdapter : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTransports:(NSArray<id<SentryTransport>> *)transports
                           options:(SentryOptions *)options;

- (void)sendEvent:(SentryEvent *)event
          session:(SentrySession *)session
      attachments:(NSArray<SentryAttachment *> *)attachments;

- (void)sendEvent:(SentryEvent *)event
     traceContext:(nullable SentryTraceContext *)traceContext
      attachments:(NSArray<SentryAttachment *> *)attachments
    NS_SWIFT_NAME(send(event:traceContext:attachments:));

- (void)sendEvent:(SentryEvent *)event
               traceContext:(nullable SentryTraceContext *)traceContext
                attachments:(NSArray<SentryAttachment *> *)attachments
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(send(event:traceContext:attachments:additionalEnvelopeItems:));

- (void)sendEvent:(SentryEvent *)event
      withSession:(SentrySession *)session
     traceContext:(nullable SentryTraceContext *)traceContext
      attachments:(NSArray<SentryAttachment *> *)attachments;

- (void)storeEvent:(SentryEvent *)event traceContext:(nullable SentryTraceContext *)traceContext;

#if !SDK_V9
/**
 * @deprecated Use @c -[SentryClient @c captureFeedback:withScope:] .
 */
- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback
    NS_SWIFT_NAME(send(userFeedback:))
        DEPRECATED_MSG_ATTRIBUTE("Use -[SentryClient captureFeedback:withScope:].");
#endif // !SDK_V9

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

- (void)flush:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
