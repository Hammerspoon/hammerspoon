#import "SentryHub.h"

@class SentryId, SentryScope, SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHub (Private)

- (void)captureCrashEvent:(SentryEvent *)event;

- (void)setSampleRandomValue:(NSNumber *)value;

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                              waitForChildren:(BOOL)waitForChildren
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

- (SentryId *)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope;
@end

NS_ASSUME_NONNULL_END
