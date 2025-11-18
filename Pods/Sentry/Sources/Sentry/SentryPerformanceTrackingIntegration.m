#import "SentryPerformanceTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryLogC.h"
#    import "SentryOptions.h"
#    import "SentrySubClassFinder.h"
#    import "SentrySwift.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#    import "SentryUIViewControllerSwizzling.h"

@interface SentryPerformanceTrackingIntegration ()

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
        [[SentryDispatchQueueWrapper alloc] initWithName:"io.sentry.ui-view-controller-swizzling"
                                              attributes:attributes];

    SentrySubClassFinder *subClassFinder = [[SentrySubClassFinder alloc]
           initWithDispatchQueue:dispatchQueue
              objcRuntimeWrapper:[SentryDependencyContainer.sharedInstance objcRuntimeWrapper]
        swizzleClassNameExcludes:options.swizzleClassNameExcludes];

    self.swizzling = [[SentryUIViewControllerSwizzling alloc]
           initWithOptions:options
             dispatchQueue:dispatchQueue
        objcRuntimeWrapper:[SentryDependencyContainer.sharedInstance objcRuntimeWrapper]
            subClassFinder:subClassFinder
        processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]
          binaryImageCache:[SentryDependencyContainer.sharedInstance binaryImageCache]];

    [self.swizzling start];
    SentryUIViewControllerPerformanceTracker *performanceTracker =
        [SentryDependencyContainer.sharedInstance uiViewControllerPerformanceTracker];
    performanceTracker.alwaysWaitForFullDisplay = options.enableTimeToFullDisplayTracing;

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
