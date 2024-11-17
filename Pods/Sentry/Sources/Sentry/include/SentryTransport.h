#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"
#import <Foundation/Foundation.h>

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

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

- (SentryFlushResult)flush:(NSTimeInterval)timeout;

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
- (void)setStartFlushCallback:(void (^)(void))callback;
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
