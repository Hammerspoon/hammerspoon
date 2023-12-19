#import "SentryUIEventTrackerMode.h"

#if SENTRY_HAS_UIKIT

@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIEventTrackerTransactionMode : NSObject <SentryUIEventTrackerMode>
SENTRY_NO_INIT

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                 idleTimeout:(NSTimeInterval)idleTimeout;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
