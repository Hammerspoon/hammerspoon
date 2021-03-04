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
        id<SentryCurrentDateProvider> currentDateProvider =
            [[SentryDefaultCurrentDateProvider alloc] init];
        SentrySessionTracker *tracker =
            [[SentrySessionTracker alloc] initWithOptions:options
                                      currentDateProvider:currentDateProvider];
        [tracker start];
        self.tracker = tracker;
    }
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
