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

@end

NS_ASSUME_NONNULL_END
