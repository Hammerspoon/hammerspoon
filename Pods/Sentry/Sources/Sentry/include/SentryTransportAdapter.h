#import "SentryDataCategory.h"
#import "SentryDefines.h"
#import "SentryDiscardReason.h"
#import "SentryTransport.h"

@class SentryEnvelope, SentryEnvelopeItem, SentryEvent, SentrySession, SentryUserFeedback,
    SentryAttachment, SentryTraceContext, SentryOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * This class converts data objects to a SentryEnvelope and passes the SentryEnvelope to the
 * SentryTransport. It is a layer between the SentryClient and the transport to keep the
 * SentryClient small and make testing easier for the SentryClient.
 */
@interface SentryTransportAdapter : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTransport:(id<SentryTransport>)transport options:(SentryOptions *)options;

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

- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback NS_SWIFT_NAME(send(userFeedback:));

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (void)flush:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
