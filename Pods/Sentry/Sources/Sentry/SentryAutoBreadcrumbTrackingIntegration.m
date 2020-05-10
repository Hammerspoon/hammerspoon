#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"

@interface SentryAutoBreadcrumbTrackingIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self enableAutomaticBreadcrumbTracking];
}

- (void)enableAutomaticBreadcrumbTracking {
    [[SentryBreadcrumbTracker alloc] start];
}

@end
