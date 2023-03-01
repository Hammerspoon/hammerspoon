#import "SentryNetworkTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSURLSessionTaskSearch.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@implementation SentryNetworkTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [self logWithOptionName:@"enableSwizzling"];
        return NO;
    }

    BOOL shouldEnableNetworkTracking = [super shouldBeEnabledWithOptions:options];

    if (shouldEnableNetworkTracking) {
        [SentryNetworkTracker.sharedInstance enableNetworkTracking];
    }

    if (options.enableNetworkBreadcrumbs) {
        [SentryNetworkTracker.sharedInstance enableNetworkBreadcrumbs];
    }

    if (options.enableCaptureFailedRequests) {
        [SentryNetworkTracker.sharedInstance enableCaptureFailedRequests];
    }

    if (shouldEnableNetworkTracking || options.enableNetworkBreadcrumbs
        || options.enableCaptureFailedRequests) {
        [SentryNetworkTrackingIntegration swizzleURLSessionTask];
        return YES;
    } else {
        return NO;
    }
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableAutoPerformanceTracing
        | kIntegrationOptionEnableNetworkTracking;
}

- (void)uninstall
{
    [SentryNetworkTracker.sharedInstance disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTask
{
    NSArray<Class> *classesToSwizzle = [SentryNSURLSessionTaskSearch urlSessionTaskClassesToTrack];

    SEL setStateSelector = NSSelectorFromString(@"setState:");
    SEL resumeSelector = NSSelectorFromString(@"resume");

    for (Class classToSwizzle in classesToSwizzle) {
        SentrySwizzleInstanceMethod(classToSwizzle, resumeSelector, SentrySWReturnType(void),
            SentrySWArguments(), SentrySWReplacement({
                [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];
                SentrySWCallOriginal();
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)resumeSelector);

        SentrySwizzleInstanceMethod(classToSwizzle, setStateSelector, SentrySWReturnType(void),
            SentrySWArguments(NSURLSessionTaskState state), SentrySWReplacement({
                [SentryNetworkTracker.sharedInstance urlSessionTask:self setState:state];
                SentrySWCallOriginal(state);
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)setStateSelector);
    }
}

#pragma clang diagnostic pop

@end
