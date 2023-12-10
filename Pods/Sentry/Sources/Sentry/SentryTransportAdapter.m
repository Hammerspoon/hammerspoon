#import "SentryTransportAdapter.h"
#import "SentryEnvelope.h"
#import "SentryEvent.h"
#import "SentryOptions.h"
#import "SentryUserFeedback.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransportAdapter ()

@property (nonatomic, strong) id<SentryTransport> transport;
@property (nonatomic, strong) SentryOptions *options;

@end

@implementation SentryTransportAdapter

- (instancetype)initWithTransport:(id<SentryTransport>)transport options:(SentryOptions *)options
{
    if (self = [super init]) {
        self.transport = transport;
        self.options = options;
    }

    return self;
}

- (void)sendEvent:(SentryEvent *)event attachments:(NSArray<SentryAttachment *> *)attachments
{
    [self sendEvent:event traceContext:nil attachments:attachments];
}

- (void)sendEvent:(SentryEvent *)event
          session:(SentrySession *)session
      attachments:(NSArray<SentryAttachment *> *)attachments
{
    [self sendEvent:event withSession:session traceContext:nil attachments:attachments];
}

- (void)sendEvent:(SentryEvent *)event
     traceContext:(nullable SentryTraceContext *)traceContext
      attachments:(NSArray<SentryAttachment *> *)attachments
{
    [self sendEvent:event
                   traceContext:traceContext
                    attachments:attachments
        additionalEnvelopeItems:@[]];
}

- (void)sendEvent:(SentryEvent *)event
               traceContext:(nullable SentryTraceContext *)traceContext
                attachments:(NSArray<SentryAttachment *> *)attachments
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    NSMutableArray<SentryEnvelopeItem *> *items = [self buildEnvelopeItems:event
                                                               attachments:attachments];
    [items addObjectsFromArray:additionalEnvelopeItems];

    SentryEnvelopeHeader *envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:event.eventId
                                                                       traceContext:traceContext];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader items:items];

    [self sendEnvelope:envelope];
}

- (void)sendEvent:(SentryEvent *)event
      withSession:(SentrySession *)session
     traceContext:(nullable SentryTraceContext *)traceContext
      attachments:(NSArray<SentryAttachment *> *)attachments
{
    NSMutableArray<SentryEnvelopeItem *> *items = [self buildEnvelopeItems:event
                                                               attachments:attachments];
    [items addObject:[[SentryEnvelopeItem alloc] initWithSession:session]];

    SentryEnvelopeHeader *envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:event.eventId
                                                                       traceContext:traceContext];

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader items:items];

    [self sendEnvelope:envelope];
}

- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithUserFeedback:userFeedback];
    SentryEnvelopeHeader *envelopeHeader =
        [[SentryEnvelopeHeader alloc] initWithId:userFeedback.eventId traceContext:nil];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader
                                                           singleItem:item];
    [self sendEnvelope:envelope];
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
{
    [self.transport sendEnvelope:envelope];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self.transport recordLostEvent:category reason:reason];
}

- (void)flush:(NSTimeInterval)timeout
{
    [self.transport flush:timeout];
}

- (NSMutableArray<SentryEnvelopeItem *> *)buildEnvelopeItems:(SentryEvent *)event
                                                 attachments:
                                                     (NSArray<SentryAttachment *> *)attachments
{
    NSMutableArray<SentryEnvelopeItem *> *items = [NSMutableArray new];
    [items addObject:[[SentryEnvelopeItem alloc] initWithEvent:event]];

    for (SentryAttachment *attachment in attachments) {
        SentryEnvelopeItem *item =
            [[SentryEnvelopeItem alloc] initWithAttachment:attachment
                                         maxAttachmentSize:self.options.maxAttachmentSize];
        // The item is nil, when creating the envelopeItem failed.
        if (nil != item) {
            [items addObject:item];
        }
    }

    return items;
}

@end

NS_ASSUME_NONNULL_END
