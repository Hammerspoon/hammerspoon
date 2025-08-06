#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryThreadWrapper;
@class SentryFramesTracker;
@protocol SentryANRTracker;

NS_ASSUME_NONNULL_BEGIN

/**
 * This class detects ANRs with a dedicated watchdog thread. It periodically checks the frame delay.
 * If the app cannot render a single frame and the frame delay is 100%, then it reports a
 * fully-blocking app hang. If the frame delay exceeds 99%, then this class reports a
 * non-fully-blocking app hang. We pick an extra high threshold of 99% because only then the app
 * seems to be hanging. With a lower threshold, the logic would overreport. Even when the app hangs
 * for 0.5 seconds and has a chance to render around five frames and then hangs again for 0.5
 * seconds, it can still respond to user input to navigate to a different screen, for example. In
 * that scenario, the frame delay is around 97%.
 */
@interface SentryANRTrackerV2 : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
                          framesTracker:(SentryFramesTracker *)framesTracker;

- (id<SentryANRTracker>)asProtocol;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
