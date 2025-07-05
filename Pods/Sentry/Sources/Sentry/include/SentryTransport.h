#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryFlushResult) {
    kSentryFlushResultSuccess = 0,
    kSentryFlushResultTimedOut,
    kSentryFlushResultAlreadyFlushing,
};

NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

- (void)storeEnvelope:(SentryEnvelope *)envelope;

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

- (SentryFlushResult)flush:(NSTimeInterval)timeout;

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
- (void)setStartFlushCallback:(void (^)(void))callback;
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
