#import "SentryAppStartTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryAppStartTracker.h"
#    import "SentryLogC.h"
#    import "SentryOptions.h"
#    import "SentrySwift.h"
#    import <PrivateSentrySDKOnly.h>
#    import <SentryAppStateManager.h>
#    import <SentryCrashWrapper.h>
#    import <SentryDependencyContainer.h>

@interface SentryAppStartTrackingIntegration ()

@property (nonatomic, strong) SentryAppStartTracker *tracker;

@end

@implementation SentryAppStartTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (!PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode
        && ![super installWithOptions:options]) {
        return NO;
    }

    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;

    self.tracker = [[SentryAppStartTracker alloc]
          initWithDispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                       appStateManager:appStateManager
                         framesTracker:SentryDependencyContainer.sharedInstance.framesTracker
        enablePreWarmedAppStartTracing:options.enablePreWarmedAppStartTracing
                   enablePerformanceV2:options.enablePerformanceV2];
    [self.tracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionIsTracingEnabled;
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

#endif // SENTRY_HAS_UIKIT
