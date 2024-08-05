#import "SentryFramesTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "PrivateSentrySDKOnly.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFramesTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

@property (nonatomic, strong) SentryFramesTracker *tracker;

@end

@implementation SentryFramesTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (!PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode
        && ![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = SentryDependencyContainer.sharedInstance.framesTracker;
    [self.tracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionIsTracingEnabled;
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
