#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryDependencyContainer.h"
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

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentrySessionTracker *tracker = [[SentrySessionTracker alloc]
           initWithOptions:options
        notificationCenter:[SentryDependencyContainer sharedInstance].notificationCenterWrapper];
    [tracker start];
    self.tracker = tracker;

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoSessionTracking;
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
