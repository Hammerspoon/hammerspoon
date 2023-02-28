#import "SentryFramesTrackingIntegration.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryFramesTracker.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryFramesTracker *tracker;
#endif

@end

@implementation SentryFramesTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if (!PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode
        && ![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [SentryFramesTracker sharedInstance];
    [self.tracker start];

    return YES;
#else
    [SentryLog
        logWithMessage:
            @"NO UIKit -> SentryFramesTrackingIntegration will not track slow and frozen frames."
              andLevel:kSentryLevelInfo];

    return NO;
#endif
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
#if SENTRY_HAS_UIKIT
    if (nil != self.tracker) {
        [self.tracker stop];
    }
#endif
}

@end

NS_ASSUME_NONNULL_END
