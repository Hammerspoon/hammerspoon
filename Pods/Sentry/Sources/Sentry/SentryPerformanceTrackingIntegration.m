#import "SentryPerformanceTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDefaultObjCRuntimeWrapper.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryLog.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryOptions.h"
#    import "SentrySubClassFinder.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#    import "SentryUIViewControllerSwizzling.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, strong) SentryUIViewControllerSwizzling *swizzling;

@end

@implementation SentryPerformanceTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
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
              objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]
        swizzleClassNameExcludes:options.swizzleClassNameExcludes];

    self.swizzling = [[SentryUIViewControllerSwizzling alloc]
           initWithOptions:options
             dispatchQueue:dispatchQueue
        objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]
            subClassFinder:subClassFinder
        processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]
          binaryImageCache:[SentryDependencyContainer.sharedInstance binaryImageCache]];

    [self.swizzling start];
    SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay
        = options.enableTimeToFullDisplayTracing;

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing
        | kIntegrationOptionEnableUIViewControllerTracing | kIntegrationOptionIsTracingEnabled
        | kIntegrationOptionEnableSwizzling;
}

@end

#endif // SENTRY_HAS_UIKIT
