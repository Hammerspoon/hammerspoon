#import "SentryNetworkTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    // We are aware that the SDK only creates breadcrumbs for HTTP requests if performance is
    // enabled. A proper fix is not straight forward as we need several checks on SentryOptions in
    // SentryNetworkTracker. As we have a problem with KVO, see
    // https://github.com/getsentry/sentry-cocoa/issues/1328, we don't know if we can keep the
    // SentryNetworkTracker (written on 29th of September 2021). Therefore we accept this tradeof
    // for now.

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because isTracingEnabled is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable NetworkTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableNetworkTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable NetworkTracking because enableNetworkTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return;
    }

    [SentryNetworkTracker.sharedInstance enable];
    [SentryNetworkTrackingIntegration swizzleNSURLSessionConfiguration];
    [SentryNetworkTrackingIntegration swizzleURLSessionTaskResume];
}

- (void)uninstall
{
    [SentryNetworkTracker.sharedInstance disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTaskResume
{
    SEL selector = NSSelectorFromString(@"resume");
    SentrySwizzleInstanceMethod(NSURLSessionTask.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];
            SentrySWCallOriginal();
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
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
