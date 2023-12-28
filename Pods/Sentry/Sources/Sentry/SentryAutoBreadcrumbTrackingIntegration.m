#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
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

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [self installWithOptions:options
             breadcrumbTracker:[[SentryBreadcrumbTracker alloc] init]
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
        systemEventBreadcrumbs:
            [[SentrySystemEventBreadcrumbs alloc]
                         initWithFileManager:[SentryDependencyContainer sharedInstance].fileManager
                andNotificationCenterWrapper:[SentryDependencyContainer sharedInstance]
                                                 .notificationCenterWrapper]
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
    ];

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
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
{
    self.breadcrumbTracker = breadcrumbTracker;
    [self.breadcrumbTracker startWithDelegate:self];

#if SENTRY_HAS_UIKIT
    if (options.enableSwizzling) {
        [self.breadcrumbTracker startSwizzle];
    }
#endif // SENTRY_HAS_UIKIT

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    self.systemEventBreadcrumbs = systemEventBreadcrumbs;
    [self.systemEventBreadcrumbs startWithDelegate:self];
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
}

- (void)uninstall
{
    if (nil != self.breadcrumbTracker) {
        [self.breadcrumbTracker stop];
    }
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    if (nil != self.systemEventBreadcrumbs) {
        [self.systemEventBreadcrumbs stop];
    }
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK addBreadcrumb:crumb];
}

@end

NS_ASSUME_NONNULL_END
