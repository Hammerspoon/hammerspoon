#import "SentryFramesTrackingIntegration.h"
#import "SentryFramesTracker.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryFramesTracker *tracker;
#endif

@end

@implementation SentryFramesTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker = [SentryFramesTracker sharedInstance];
    [self.tracker start];

#else
    [SentryLog
        logWithMessage:
            @"NO UIKit -> SentryFramesTrackingIntegration will not track slow and frozen frames."
              andLevel:kSentryLevelInfo];
#endif
}

#if SENTRY_HAS_UIKIT
- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:
                       @"AutoUIPerformanceTracking disabled. Will not track slow and frozen frames."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.isTracingEnabled) {
        [SentryLog
            logWithMessage:
                @"No tracesSampleRate and tracesSampler set. Will not track slow and frozen frames."
                  andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}
#endif

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
