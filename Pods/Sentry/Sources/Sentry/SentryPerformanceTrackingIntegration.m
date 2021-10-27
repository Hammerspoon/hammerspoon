#import "SentryPerformanceTrackingIntegration.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryUIViewControllerSwizziling.h"

@interface
SentryPerformanceTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIViewControllerSwizziling *swizzling;
#endif

@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"AutoUIPerformanceTracking disabled. Will not start "
                                  @"SentryPerformanceTrackingIntegration."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:@"No tracesSampleRate and tracesSampler set. Will not start "
                                  @"SentryPerformanceTrackingIntegration."
                         andLevel:kSentryLevelDebug];
        return;
    }

#if SENTRY_HAS_UIKIT
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-ui-view-controller-swizzling"
                                              attributes:attributes];
    self.swizzling = [[SentryUIViewControllerSwizziling alloc] initWithOptions:options
                                                                 dispatchQueue:dispatchQueue];

    [self.swizzling start];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryPerformanceTrackingIntegration "
                              @"start] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

@end
