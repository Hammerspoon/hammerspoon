#import "SentryUIEventTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

#    import <SentryLog.h>
#    import <SentryNSDataSwizzling.h>
#    import <SentryOptions+Private.h>
#    import <SentryOptions.h>
#    import <SentryUIEventTracker.h>
#    import <SentryUIEventTrackerTransactionMode.h>

@interface
SentryUIEventTrackingIntegration ()

@property (nonatomic, strong) SentryUIEventTracker *uiEventTracker;

@end

@implementation SentryUIEventTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryUIEventTrackerTransactionMode *mode =
        [[SentryUIEventTrackerTransactionMode alloc] initWithIdleTimeout:options.idleTimeout];

    self.uiEventTracker = [[SentryUIEventTracker alloc] initWithMode:mode];

    [self.uiEventTracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableSwizzling
        | kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableUserInteractionTracing;
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end

#endif // SENTRY_HAS_UIKIT
