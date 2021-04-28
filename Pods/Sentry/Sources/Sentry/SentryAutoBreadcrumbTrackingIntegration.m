#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySystemEventsBreadcrumbs.h"

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, weak) SentryOptions *options;

@property (nonatomic, strong) SentryBreadcrumbTracker *tracker;
@property (nonatomic, strong) SentrySystemEventsBreadcrumbs *system_events;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self enableAutomaticBreadcrumbTracking];
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
    if (nil != self.system_events) {
        [self.system_events stop];
    }
}

- (void)enableAutomaticBreadcrumbTracking
{
    self.tracker = [SentryBreadcrumbTracker alloc];
    [self.tracker start];
    self.system_events = [SentrySystemEventsBreadcrumbs alloc];
    [self.system_events start];
}

@end
