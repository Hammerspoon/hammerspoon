#import "SentryPerformanceTrackingIntegration.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryProcessInfoWrapper.h"
#import "SentrySubClassFinder.h"
#import "SentryUIViewControllerSwizzling.h"

@interface
SentryPerformanceTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIViewControllerSwizzling *swizzling;
#endif

@end

@implementation SentryPerformanceTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if (![super installWithOptions:options]) {
        return NO;
    }

    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-ui-view-controller-swizzling"
                                              attributes:attributes];

    SentrySubClassFinder *subClassFinder = [[SentrySubClassFinder alloc]
        initWithDispatchQueue:dispatchQueue
           objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]];

    self.swizzling = [[SentryUIViewControllerSwizzling alloc]
           initWithOptions:options
             dispatchQueue:dispatchQueue
        objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]
            subClassFinder:subClassFinder
        processInfoWrapper:[[SentryProcessInfoWrapper alloc] init]];

    [self.swizzling start];
    return YES;
#else
    SENTRY_LOG_DEBUG(@"NO UIKit -> [SentryPerformanceTrackingIntegration start] does nothing.");
    return NO;
#endif
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing
        | kIntegrationOptionEnableUIViewControllerTracing | kIntegrationOptionIsTracingEnabled
        | kIntegrationOptionEnableSwizzling;
}

@end
