#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySystemEventsBreadcrumbs.h"

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, weak) SentryOptions *options;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self enableAutomaticBreadcrumbTracking];
}

- (void)enableAutomaticBreadcrumbTracking
{
    [[SentryBreadcrumbTracker alloc] start];
    [[SentrySystemEventsBreadcrumbs alloc] start];
}

@end
