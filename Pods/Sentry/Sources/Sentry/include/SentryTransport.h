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

- (SentryFlushResult)flush:(NSTimeInterval)timeout;

#if TEST || TESTCI
- (void)setStartFlushCallback:(void (^)(void))callback;
#endif

@end

NS_ASSUME_NONNULL_END
