#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySessionTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoSessionTrackingIntegration ()

@property (nonatomic, strong) SentrySessionTracker *tracker;

@end

@implementation SentryAutoSessionTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (options.enableAutoSessionTracking) {
        SentrySessionTracker *tracker = [[SentrySessionTracker alloc]
                initWithOptions:options
            currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]];
        [tracker start];
        self.tracker = tracker;
    }
}

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
