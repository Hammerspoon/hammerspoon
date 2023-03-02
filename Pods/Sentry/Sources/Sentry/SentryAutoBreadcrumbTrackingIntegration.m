#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySystemEventBreadcrumbs.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *breadcrumbTracker;
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    [self installWithOptions:options
             breadcrumbTracker:[[SentryBreadcrumbTracker alloc] init]
        systemEventBreadcrumbs:[[SentrySystemEventBreadcrumbs alloc] init]];
}

/**
 * For testing.
 */
- (void)installWithOptions:(nonnull SentryOptions *)options
         breadcrumbTracker:(SentryBreadcrumbTracker *)breadcrumbTracker
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs
{
    self.breadcrumbTracker = breadcrumbTracker;
    [self.breadcrumbTracker start];

    if (options.enableSwizzling) {
        [self.breadcrumbTracker startSwizzle];
    }

    self.systemEventBreadcrumbs = systemEventBreadcrumbs;
    [self.systemEventBreadcrumbs start];
}

- (void)uninstall
{
    if (nil != self.breadcrumbTracker) {
        [self.breadcrumbTracker stop];
    }
    if (nil != self.systemEventBreadcrumbs) {
        [self.systemEventBreadcrumbs stop];
    }
}

@end

NS_ASSUME_NONNULL_END
