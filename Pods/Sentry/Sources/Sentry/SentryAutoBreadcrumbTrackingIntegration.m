#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySystemEventBreadcrumbs.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *breadcrumbTracker;
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [self installWithOptions:options
             breadcrumbTracker:[[SentryBreadcrumbTracker alloc]
                                   initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance]
                                                              .swizzleWrapper]
        systemEventBreadcrumbs:
            [[SentrySystemEventBreadcrumbs alloc]
                         initWithFileManager:[SentryDependencyContainer sharedInstance].fileManager
                      andCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                andNotificationCenterWrapper:[SentryDependencyContainer sharedInstance]
                                                 .notificationCenterWrapper]];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoBreadcrumbTracking;
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
    [self.systemEventBreadcrumbs startWithDelegate:self];
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

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK addBreadcrumb:crumb];
}

@end

NS_ASSUME_NONNULL_END
