#import "SentryNetworkTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSURLSessionTaskSearch.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    BOOL shouldEnableNetworkTracking = YES;

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because isTracingEnabled is disabled."
                         andLevel:kSentryLevelDebug];
        shouldEnableNetworkTracking = NO;
    }

    if (shouldEnableNetworkTracking && !options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable NetworkTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        shouldEnableNetworkTracking = NO;
    }

    if (shouldEnableNetworkTracking && !options.enableNetworkTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable NetworkTracking because enableNetworkTracking is disabled."
                  andLevel:kSentryLevelDebug];
        shouldEnableNetworkTracking = NO;
    }

    if (shouldEnableNetworkTracking) {
        [SentryNetworkTracker.sharedInstance enableNetworkTracking];
        [SentryNetworkTrackingIntegration swizzleNSURLSessionConfiguration];
    }

    if (options.enableNetworkBreadcrumbs) {
        [SentryNetworkTracker.sharedInstance enableNetworkBreadcrumbs];
    }

    if (shouldEnableNetworkTracking || options.enableNetworkBreadcrumbs) {
        [SentryNetworkTrackingIntegration swizzleURLSessionTask];
    } else {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
    }
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

+ (void)swizzleNSURLSessionConfiguration
{
    // The HTTPAdditionalHeaders is only an instance method for NSURLSessionConfiguration on
    // iOS/tvOS 8.x, 14.x, and 15.x. On the other OS versions, it only has a property.
    // Therefore, we need to make sure that NSURLSessionConfiguration has this method to be able to
    // swizzle it. Otherwise, we would crash. Cause we can't swizzle properties currently, we only
    // swizzle when the method is available.
    // See
    // https://developer.limneos.net/index.php?ios=14.4&framework=CFNetwork.framework&header=NSURLSessionConfiguration.h
    // and
    // https://developer.limneos.net/index.php?ios=13.1.3&framework=CFNetwork.framework&header=__NSCFURLSessionConfiguration.h.
    SEL selector = NSSelectorFromString(@"HTTPAdditionalHeaders");
    Class classToSwizzle = NSURLSessionConfiguration.class;
    Method method = class_getInstanceMethod(classToSwizzle, selector);

    if (method == nil) {
        [SentryLog logWithMessage:@"SentryNetworkSwizzling: Didn't find HTTPAdditionalHeaders on "
                                  @"NSURLSessionConfiguration. Won't add Sentry Trace HTTP headers."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (method != nil) {
        SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType(NSDictionary *),
            SentrySWArguments(), SentrySWReplacement({
                return [SentryNetworkTracker.sharedInstance addTraceHeader:SentrySWCallOriginal()];
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
    }
}

#pragma clang diagnostic pop

@end
