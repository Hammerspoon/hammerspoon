#import "SentryFileIOTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"

@implementation SentryFileIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    [SentryNSDataSwizzling start];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable FileIOTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because tracing is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableFileIOTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable FileIOTracking because enableFileIOTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
