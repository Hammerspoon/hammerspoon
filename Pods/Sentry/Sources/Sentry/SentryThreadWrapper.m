#import "SentryThreadWrapper.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryThreadWrapper

- (void)sleepForTimeInterval:(NSTimeInterval)timeInterval
{
    [NSThread sleepForTimeInterval:timeInterval];
}

- (void)threadStarted:(NSUUID *)threadID;
{
    // No op. Only needed for testing.
}

- (void)threadFinished:(NSUUID *)threadID
{
    // No op. Only needed for testing.
}

+ (void)onMainThread:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        SENTRY_LOG_DEBUG(@"Already on main thread.");
        block();
    } else {
        SENTRY_LOG_DEBUG(@"Dispatching asynchronously to main queue.");
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end

NS_ASSUME_NONNULL_END
