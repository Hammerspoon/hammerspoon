#import <Foundation/Foundation.h>

@class SentryEnvelope, SentryEvent, SentrySession, SentryUserFeedback, SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

// TODO: align with unified SDK api
NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

- (void)sendEvent:(SentryEvent *)event
      attachments:(NSArray<SentryAttachment *> *)attachments
    NS_SWIFT_NAME(send(event:attachments:));

- (void)sendEvent:(SentryEvent *)event
      withSession:(SentrySession *)session
      attachments:(NSArray<SentryAttachment *> *)attachments;

- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback NS_SWIFT_NAME(send(userFeedback:));

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

@end

NS_ASSUME_NONNULL_END
