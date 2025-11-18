#import "SentryANRTrackingIntegration.h"
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCrashIntegration.h"
#import "SentryDsn.h"
#import "SentryFileIOTrackingIntegration.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryNetworkTrackingIntegration.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"
#import "SentryOptionsInternal.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"
#import "SentrySwiftAsyncIntegration.h"

#if SENTRY_HAS_UIKIT
#    import "SentryAppStartTrackingIntegration.h"
#    import "SentryFramesTrackingIntegration.h"
#    import "SentryPerformanceTrackingIntegration.h"
#    import "SentryScreenshotIntegration.h"
#    import "SentryUIEventTrackingIntegration.h"
#    import "SentryUserFeedbackIntegration.h"
#    import "SentryViewHierarchyIntegration.h"
#    import "SentryWatchdogTerminationTrackingIntegration.h"
#endif // SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT
#    import "SentryMetricKitIntegration.h"
#endif // SENTRY_HAS_METRIC_KIT

@implementation SentryOptionsInternal

+ (NSArray<Class> *)defaultIntegrationClasses
{
    // The order of integrations here is important.
    // SentryCrashIntegration needs to be initialized before SentryAutoSessionTrackingIntegration.
    // And SentrySessionReplayIntegration before SentryCrashIntegration.
    NSMutableArray<Class> *defaultIntegrations = [NSMutableArray<Class> arrayWithObjects:
#if SENTRY_TARGET_REPLAY_SUPPORTED
            [SentrySessionReplayIntegration class],
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryCrashIntegration class],
#if SENTRY_HAS_UIKIT
        [SentryAppStartTrackingIntegration class], [SentryFramesTrackingIntegration class],
        [SentryPerformanceTrackingIntegration class], [SentryUIEventTrackingIntegration class],
        [SentryViewHierarchyIntegration class],
        [SentryWatchdogTerminationTrackingIntegration class],
#endif // SENTRY_HAS_UIKIT
#if SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryScreenshotIntegration class],
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryANRTrackingIntegration class], [SentryAutoBreadcrumbTrackingIntegration class],
        [SentryAutoSessionTrackingIntegration class], [SentryCoreDataTrackingIntegration class],
        [SentryFileIOTrackingIntegration class], [SentryNetworkTrackingIntegration class],
        [SentrySwiftAsyncIntegration class], nil];

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    if (@available(iOS 13.0, iOSApplicationExtension 13.0, *)) {
        [defaultIntegrations addObject:[SentryUserFeedbackIntegration class]];
    }
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        [defaultIntegrations addObject:[SentryMetricKitIntegration class]];
    }
#endif // SENTRY_HAS_METRIC_KIT

    return defaultIntegrations;
}

+ (nullable SentryOptions *)initWithDict:(NSDictionary<NSString *, id> *)options
                        didFailWithError:(NSError *_Nullable *_Nullable)error
{
    SentryOptions *sentryOptions = [[SentryOptions alloc] init];
    if (![SentryOptionsInternal validateOptions:options
                                  sentryOptions:sentryOptions
                               didFailWithError:error]) {
        if (error != nil) {
            SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions: %@", *error);
        } else {
            SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions");
        }
        return nil;
    }
    return sentryOptions;
}

/**
 * Populates all @c SentryOptions values from @c options dict using fallbacks/defaults if needed.
 */
+ (BOOL)validateOptions:(NSDictionary<NSString *, id> *)options
          sentryOptions:(SentryOptions *)sentryOptions
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSPredicate *isNSString = [NSPredicate predicateWithBlock:^BOOL(
        id object, NSDictionary *bindings) { return [object isKindOfClass:[NSString class]]; }];

    [self setBool:options[@"debug"] block:^(BOOL value) { sentryOptions.debug = value; }];

    if ([options[@"diagnosticLevel"] isKindOfClass:[NSString class]]) {
        NSString *_Nonnull diagnosticLevel
            = SENTRY_UNWRAP_NULLABLE(NSString, options[@"diagnosticLevel"]);
        for (SentryLevel level = 0; level <= kSentryLevelFatal; level++) {
            if ([nameForSentryLevel(level) isEqualToString:diagnosticLevel]) {
                sentryOptions.diagnosticLevel = level;
                break;
            }
        }
    }

    if (options[@"dsn"] != [NSNull null]) {
        NSString *dsn = @"";
        if (nil != options[@"dsn"] && [options[@"dsn"] isKindOfClass:[NSString class]]) {
            dsn = options[@"dsn"];
        }

        sentryOptions.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (sentryOptions.parsedDsn == nil) {
            return NO;
        }
    }

    if ([options[@"release"] isKindOfClass:[NSString class]]) {
        sentryOptions.releaseName = options[@"release"];
    }

    if ([options[@"environment"] isKindOfClass:[NSString class]]) {
        NSString *_Nonnull environment = SENTRY_UNWRAP_NULLABLE(NSString, options[@"environment"]);
        sentryOptions.environment = environment;
    }

    if ([options[@"dist"] isKindOfClass:[NSString class]]) {
        sentryOptions.dist = options[@"dist"];
    }

    [self setBool:options[@"enabled"] block:^(BOOL value) { sentryOptions.enabled = value; }];

    if ([options[@"shutdownTimeInterval"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.shutdownTimeInterval = [options[@"shutdownTimeInterval"] doubleValue];
    }

    [self setBool:options[@"enableCrashHandler"]
            block:^(BOOL value) { sentryOptions.enableCrashHandler = value; }];

#if TARGET_OS_OSX
    [self setBool:options[@"enableUncaughtNSExceptionReporting"]
            block:^(BOOL value) { sentryOptions.enableUncaughtNSExceptionReporting = value; }];
#endif // TARGET_OS_OSX

#if !TARGET_OS_WATCH
    [self setBool:options[@"enableSigtermReporting"]
            block:^(BOOL value) { sentryOptions.enableSigtermReporting = value; }];
#endif // !TARGET_OS_WATCH

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    [self setBool:options[@"enableNetworkBreadcrumbs"]
            block:^(BOOL value) { sentryOptions.enableNetworkBreadcrumbs = value; }];

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
    }

    if ([options[@"cacheDirectoryPath"] isKindOfClass:[NSString class]]) {
        NSString *_Nonnull cacheDirectoryPath
            = SENTRY_UNWRAP_NULLABLE(NSString, options[@"cacheDirectoryPath"]);
        sentryOptions.cacheDirectoryPath = cacheDirectoryPath;
    }

    if ([self isBlock:options[@"beforeSend"]]) {
        sentryOptions.beforeSend = options[@"beforeSend"];
    }

    if ([self isBlock:options[@"beforeSendSpan"]]) {
        sentryOptions.beforeSendSpan = options[@"beforeSendSpan"];
    }

    if ([self isBlock:options[@"beforeBreadcrumb"]]) {
        sentryOptions.beforeBreadcrumb = options[@"beforeBreadcrumb"];
    }

    if ([self isBlock:options[@"beforeCaptureScreenshot"]]) {
        sentryOptions.beforeCaptureScreenshot = options[@"beforeCaptureScreenshot"];
    }

    if ([self isBlock:options[@"beforeCaptureViewHierarchy"]]) {
        sentryOptions.beforeCaptureViewHierarchy = options[@"beforeCaptureViewHierarchy"];
    }

    if ([self isBlock:options[@"onCrashedLastRun"]]) {
        sentryOptions.onCrashedLastRun = options[@"onCrashedLastRun"];
    }

#if !SDK_V9
    if ([options[@"integrations"] isKindOfClass:[NSArray class]]) {
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
        sentryOptions.integrations =
            [[options[@"integrations"] filteredArrayUsingPredicate:isNSString] mutableCopy];
#    pragma clang diagnstic pop
    }
#endif // !SDK_V9

    if ([options[@"sampleRate"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.sampleRate = options[@"sampleRate"];
    }

    [self setBool:options[@"enableAutoSessionTracking"]
            block:^(BOOL value) { sentryOptions.enableAutoSessionTracking = value; }];

    [self setBool:options[@"enableGraphQLOperationTracking"]
            block:^(BOOL value) { sentryOptions.enableGraphQLOperationTracking = value; }];

    [self setBool:options[@"enableWatchdogTerminationTracking"]
            block:^(BOOL value) { sentryOptions.enableWatchdogTerminationTracking = value; }];

    [self setBool:options[@"swiftAsyncStacktraces"]
            block:^(BOOL value) { sentryOptions.swiftAsyncStacktraces = value; }];

    if ([options[@"sessionTrackingIntervalMillis"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    [self setBool:options[@"attachStacktrace"]
            block:^(BOOL value) { sentryOptions.attachStacktrace = value; }];

    if ([options[@"maxAttachmentSize"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }

    [self setBool:options[@"sendDefaultPii"]
            block:^(BOOL value) { sentryOptions.sendDefaultPii = value; }];

    [self setBool:options[@"enableAutoPerformanceTracing"]
            block:^(BOOL value) { sentryOptions.enableAutoPerformanceTracing = value; }];

#if !SDK_V9
    [self setBool:options[@"enablePerformanceV2"]
            block:^(BOOL value) { sentryOptions.enablePerformanceV2 = value; }];
#endif // !SDK_V9

    [self setBool:options[@"enablePersistingTracesWhenCrashing"]
            block:^(BOOL value) { sentryOptions.enablePersistingTracesWhenCrashing = value; }];

    [self setBool:options[@"enableCaptureFailedRequests"]
            block:^(BOOL value) { sentryOptions.enableCaptureFailedRequests = value; }];

    [self setBool:options[@"enableTimeToFullDisplayTracing"]
            block:^(BOOL value) { sentryOptions.enableTimeToFullDisplayTracing = value; }];

    if ([self isBlock:options[@"initialScope"]]) {
        sentryOptions.initialScope
            = (SentryScope * (^_Nonnull)(SentryScope *)) options[@"initialScope"];
    }
#if SENTRY_HAS_UIKIT
    [self setBool:options[@"enableUIViewControllerTracing"]
            block:^(BOOL value) { sentryOptions.enableUIViewControllerTracing = value; }];

    [self setBool:options[@"attachScreenshot"]
            block:^(BOOL value) { sentryOptions.attachScreenshot = value; }];

    [self setBool:options[@"attachViewHierarchy"]
            block:^(BOOL value) { sentryOptions.attachViewHierarchy = value; }];

    [self setBool:options[@"reportAccessibilityIdentifier"]
            block:^(BOOL value) { sentryOptions.reportAccessibilityIdentifier = value; }];

    [self setBool:options[@"enableUserInteractionTracing"]
            block:^(BOOL value) { sentryOptions.enableUserInteractionTracing = value; }];

    if ([options[@"idleTimeout"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.idleTimeout = [options[@"idleTimeout"] doubleValue];
    }

    [self setBool:options[@"enablePreWarmedAppStartTracing"]
            block:^(BOOL value) { sentryOptions.enablePreWarmedAppStartTracing = value; }];

#    if !SDK_V9
    [self setBool:options[@"enableAppHangTrackingV2"]
            block:^(BOOL value) { sentryOptions.enableAppHangTrackingV2 = value; }];
#    endif // !SDK_V9

    [self setBool:options[@"enableReportNonFullyBlockingAppHangs"]
            block:^(BOOL value) { sentryOptions.enableReportNonFullyBlockingAppHangs = value; }];

#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
    if ([options[@"sessionReplay"] isKindOfClass:NSDictionary.class]) {
        sentryOptions.sessionReplay = [[SentryReplayOptions alloc]
            initWithDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, options[@"sessionReplay"])];
    }
#endif // SENTRY_TARGET_REPLAY_SUPPORTED

    [self setBool:options[@"enableAppHangTracking"]
            block:^(BOOL value) { sentryOptions.enableAppHangTracking = value; }];

    if ([options[@"appHangTimeoutInterval"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.appHangTimeoutInterval = [options[@"appHangTimeoutInterval"] doubleValue];
    }

    [self setBool:options[@"enableNetworkTracking"]
            block:^(BOOL value) { sentryOptions.enableNetworkTracking = value; }];

    [self setBool:options[@"enableFileIOTracing"]
            block:^(BOOL value) { sentryOptions.enableFileIOTracing = value; }];

    if ([options[@"tracesSampleRate"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.tracesSampleRate = options[@"tracesSampleRate"];
    }

    if ([self isBlock:options[@"tracesSampler"]]) {
        sentryOptions.tracesSampler = options[@"tracesSampler"];
    }
#if !SDK_V9
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([options[@"enableTracing"] isKindOfClass:NSNumber.self]) {
        sentryOptions.enableTracing = [options[@"enableTracing"] boolValue];
    }
#    pragma clang diagnostic pop
#endif // !SDK_V9

    if ([options[@"inAppIncludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppIncludes =
            [options[@"inAppIncludes"] filteredArrayUsingPredicate:isNSString];
        for (NSString *include in inAppIncludes) {
            [sentryOptions addInAppInclude:include];
        }
    }

    if ([options[@"inAppExcludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppExcludes =
            [options[@"inAppExcludes"] filteredArrayUsingPredicate:isNSString];
        for (NSString *exclude in inAppExcludes) {
            [sentryOptions addInAppExclude:exclude];
        }
    }

    if ([options[@"urlSession"] isKindOfClass:[NSURLSession class]]) {
        sentryOptions.urlSession = options[@"urlSession"];
    }

    if ([options[@"urlSessionDelegate"] conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
        sentryOptions.urlSessionDelegate = options[@"urlSessionDelegate"];
    }

    [self setBool:options[@"enableSwizzling"]
            block:^(BOOL value) { sentryOptions.enableSwizzling = value; }];

    if ([options[@"swizzleClassNameExcludes"] isKindOfClass:[NSSet class]]) {
        sentryOptions.swizzleClassNameExcludes = [SENTRY_UNWRAP_NULLABLE(
            NSSet, options[@"swizzleClassNameExcludes"]) filteredSetUsingPredicate:isNSString];
    }

    [self setBool:options[@"enableCoreDataTracing"]
            block:^(BOOL value) { sentryOptions.enableCoreDataTracing = value; }];

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if !SDK_V9
    if ([options[@"profilesSampleRate"] isKindOfClass:[NSNumber class]]) {
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
        sentryOptions.profilesSampleRate = options[@"profilesSampleRate"];
#        pragma clang diagnostic pop
    }

#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([self isBlock:options[@"profilesSampler"]]) {
        sentryOptions.profilesSampler = options[@"profilesSampler"];
    }
#        pragma clang diagnostic pop

#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self setBool:options[@"enableProfiling"]
            block:^(BOOL value) { sentryOptions.enableProfiling = value; }];

    [self setBool:options[NSStringFromSelector(@selector(enableAppLaunchProfiling))]
            block:^(BOOL value) { sentryOptions.enableAppLaunchProfiling = value; }];
#        pragma clang diagnostic pop
#    endif // !SDK_V9
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [self setBool:options[@"sendClientReports"]
            block:^(BOOL value) { sentryOptions.sendClientReports = value; }];

    [self setBool:options[@"enableAutoBreadcrumbTracking"]
            block:^(BOOL value) { sentryOptions.enableAutoBreadcrumbTracking = value; }];

    if ([options[@"tracePropagationTargets"] isKindOfClass:[NSArray class]]) {
        sentryOptions.tracePropagationTargets
            = SENTRY_UNWRAP_NULLABLE(NSArray, options[@"tracePropagationTargets"]);
    }

    if ([options[@"failedRequestStatusCodes"] isKindOfClass:[NSArray class]]) {
        sentryOptions.failedRequestStatusCodes
            = SENTRY_UNWRAP_NULLABLE(NSArray, options[@"failedRequestStatusCodes"]);
    }

    if ([options[@"failedRequestTargets"] isKindOfClass:[NSArray class]]) {
        sentryOptions.failedRequestTargets
            = SENTRY_UNWRAP_NULLABLE(NSArray, options[@"failedRequestTargets"]);
    }

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        [self setBool:options[@"enableMetricKit"]
                block:^(BOOL value) { sentryOptions.enableMetricKit = value; }];
        [self setBool:options[@"enableMetricKitRawPayload"]
                block:^(BOOL value) { sentryOptions.enableMetricKitRawPayload = value; }];
    }
#endif // SENTRY_HAS_METRIC_KIT

    [self setBool:options[@"enableSpotlight"]
            block:^(BOOL value) { sentryOptions.enableSpotlight = value; }];

    if ([options[@"spotlightUrl"] isKindOfClass:[NSString class]]) {
        sentryOptions.spotlightUrl = SENTRY_UNWRAP_NULLABLE(NSString, options[@"spotlightUrl"]);
    }

    if ([options[@"experimental"] isKindOfClass:NSDictionary.class]) {
        [sentryOptions.experimental validateOptions:options[@"experimental"]];
    }

    return YES;
}

/**
 * Checks if the passed in block is actually of type block. We can't check if the block matches a
 * specific block without some complex objc runtime method calls and therefore we only check if it's
 * a block or not. Assigning a wrong block to the @c SentryOptions blocks still could lead to
 * crashes at runtime, but when someone uses the @c initWithDict they should better know what they
 * are doing.
 * @see Taken from https://gist.github.com/steipete/6ee378bd7d87f276f6e0
 */
+ (BOOL)isBlock:(nullable id)block
{
    static Class blockClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockClass = [^{ } class];
        while ([blockClass superclass] != NSObject.class) {
            blockClass = [blockClass superclass];
        }
    });

    return [block isKindOfClass:blockClass];
}

+ (void)setBool:(id)value block:(void (^)(BOOL))block
{
    // Entries in the dictionary can be NSNull. Especially, on React-Native, this can happen.
    if (value != nil && ![value isEqual:[NSNull null]]) {
        block([value boolValue]);
    }
}

@end
