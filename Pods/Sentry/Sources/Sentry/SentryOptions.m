#import "SentryANRTracker.h"
#import "SentryANRTrackingIntegration.h"
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCrashIntegration.h"
#import "SentryDsn.h"
#import "SentryFileIOTrackingIntegration.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryNetworkTrackingIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySDK.h"
#import "SentryScope.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"
#import "SentrySwiftAsyncIntegration.h"
#import "SentryTracer.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import "SentryAppStartTrackingIntegration.h"
#    import "SentryFramesTrackingIntegration.h"
#    import "SentryPerformanceTrackingIntegration.h"
#    import "SentryScreenshotIntegration.h"
#    import "SentryUIEventTrackingIntegration.h"
#    import "SentryViewHierarchyIntegration.h"
#    import "SentryWatchdogTerminationTrackingIntegration.h"
#endif // SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT
#    import "SentryMetricKitIntegration.h"
#endif // SENTRY_HAS_METRIC_KIT
NSString *const kSentryDefaultEnvironment = @"production";

@implementation SentryOptions {
    BOOL _enableTracingManual;
}

+ (NSArray<NSString *> *)defaultIntegrations
{
    // The order of integrations here is important.
    // SentryCrashIntegration needs to be initialized before SentryAutoSessionTrackingIntegration.
    NSMutableArray<NSString *> *defaultIntegrations =
        @[
            NSStringFromClass([SentryCrashIntegration class]),
#if SENTRY_HAS_UIKIT
            NSStringFromClass([SentryAppStartTrackingIntegration class]),
            NSStringFromClass([SentryFramesTrackingIntegration class]),
            NSStringFromClass([SentryPerformanceTrackingIntegration class]),
            NSStringFromClass([SentryScreenshotIntegration class]),
            NSStringFromClass([SentryUIEventTrackingIntegration class]),
            NSStringFromClass([SentryViewHierarchyIntegration class]),
            NSStringFromClass([SentryWatchdogTerminationTrackingIntegration class]),
#    if !TARGET_OS_VISION
            NSStringFromClass([SentrySessionReplayIntegration class]),
#    endif
#endif // SENTRY_HAS_UIKIT
            NSStringFromClass([SentryANRTrackingIntegration class]),
            NSStringFromClass([SentryAutoBreadcrumbTrackingIntegration class]),
            NSStringFromClass([SentryAutoSessionTrackingIntegration class]),
            NSStringFromClass([SentryCoreDataTrackingIntegration class]),
            NSStringFromClass([SentryFileIOTrackingIntegration class]),
            NSStringFromClass([SentryNetworkTrackingIntegration class]),
            NSStringFromClass([SentrySwiftAsyncIntegration class])
        ]
            .mutableCopy;

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        [defaultIntegrations addObject:NSStringFromClass([SentryMetricKitIntegration class])];
    }
#endif // SENTRY_HAS_METRIC_KIT

    return defaultIntegrations;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.shutdownTimeInterval = 2.0;
        self.enableCrashHandler = YES;
#if !TARGET_OS_WATCH
        self.enableSigtermReporting = NO;
#endif // !TARGET_OS_WATCH
        self.diagnosticLevel = kSentryLevelDebug;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.maxCacheItems = 30;
        _integrations = SentryOptions.defaultIntegrations;
        self.sampleRate = SENTRY_DEFAULT_SAMPLE_RATE;
        self.enableAutoSessionTracking = YES;
        self.enableGraphQLOperationTracking = NO;
        self.enableWatchdogTerminationTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        self.sendDefaultPii = NO;
        self.enableAutoPerformanceTracing = YES;
        self.enablePerformanceV2 = NO;
        self.enableCaptureFailedRequests = YES;
        self.environment = kSentryDefaultEnvironment;
        self.enableTimeToFullDisplayTracing = NO;

        self.initialScope = ^SentryScope *(SentryScope *scope) { return scope; };
        _experimental = [[SentryExperimentalOptions alloc] init];
        _enableTracing = NO;
        _enableTracingManual = NO;
#if SENTRY_HAS_UIKIT
        self.enableUIViewControllerTracing = YES;
        self.attachScreenshot = NO;
        self.attachViewHierarchy = NO;
        self.enableUserInteractionTracing = YES;
        self.idleTimeout = SentryTracerDefaultTimeout;
        self.enablePreWarmedAppStartTracing = NO;
#endif // SENTRY_HAS_UIKIT
        self.enableAppHangTracking = YES;
        self.appHangTimeoutInterval = 2.0;
        self.enableAutoBreadcrumbTracking = YES;
        self.enableNetworkTracking = YES;
        self.enableFileIOTracing = YES;
        self.enableNetworkBreadcrumbs = YES;
        self.tracesSampleRate = nil;
#if SENTRY_TARGET_PROFILING_SUPPORTED
        _enableProfiling = NO;
        self.profilesSampleRate = nil;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
        self.enableCoreDataTracing = YES;
        _enableSwizzling = YES;
        self.swizzleClassNameExcludes = [NSSet new];
        self.sendClientReports = YES;
        self.swiftAsyncStacktraces = NO;
        self.enableSpotlight = NO;
        self.spotlightUrl = @"http://localhost:8969/stream";
        self.enableMetrics = NO;
        self.enableDefaultTagsForMetrics = YES;
        self.enableSpanLocalMetricAggregation = YES;

#if TARGET_OS_OSX
        NSString *dsn = [[[NSProcessInfo processInfo] environment] objectForKey:@"SENTRY_DSN"];
        if (dsn.length > 0) {
            self.dsn = dsn;
        }
#endif // TARGET_OS_OSX

        // Use the name of the bundle’s executable file as inAppInclude, so SentryInAppLogic
        // marks frames coming from there as inApp. With this approach, the SDK marks public
        // frameworks such as UIKitCore, CoreFoundation, GraphicsServices, and so forth, as not
        // inApp. For private frameworks, such as Sentry, dynamic and static frameworks differ.
        // Suppose you use dynamic frameworks inside your app. In that case, the SDK marks these as
        // not inApp as these frameworks are located in the application bundle, but their location
        // is different from the main executable.  In case you have a private framework that should
        // be inApp you can add it to inAppInclude. When using static frameworks, the frameworks end
        // up in the main executable. Therefore, the SDK currently can't detect if a frame of the
        // main executable originates from the application or a private framework and marks all of
        // them as inApp. To fix this, the user can use stack trace rules on Sentry.
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
        if (bundleExecutable == nil) {
            _inAppIncludes = [NSArray new];
        } else {
            _inAppIncludes = @[ bundleExecutable ];
        }

        _inAppExcludes = [NSArray new];

        // Set default release name
        if (infoDict != nil) {
            self.releaseName =
                [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"],
                          infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]];
        }

        NSRegularExpression *everythingAllowedRegex =
            [NSRegularExpression regularExpressionWithPattern:@".*"
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:NULL];
        self.tracePropagationTargets = @[ everythingAllowedRegex ];
        self.failedRequestTargets = @[ everythingAllowedRegex ];

        // defaults to 500 to 599
        SentryHttpStatusCodeRange *defaultHttpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:500 max:599];
        self.failedRequestStatusCodes = @[ defaultHttpStatusCodeRange ];
        self.cacheDirectoryPath
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject;

#if SENTRY_HAS_METRIC_KIT
        if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
            self.enableMetricKit = NO;
            self.enableMetricKitRawPayload = NO;
        }
#endif // SENTRY_HAS_METRIC_KIT
    }
    return self;
}

/** Only exposed via `SentryOptions+HybridSDKs.h`. */
- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (self = [self init]) {
        if (![self validateOptions:options didFailWithError:error]) {
            if (error != nil) {
                SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions: %@", *error);
            } else {
                SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions");
            }
            return nil;
        }
    }
    return self;
}

- (void)setTracePropagationTargets:(NSArray *)tracePropagationTargets
{
    for (id targetCheck in tracePropagationTargets) {
        if (![targetCheck isKindOfClass:[NSRegularExpression class]]
            && ![targetCheck isKindOfClass:[NSString class]]) {
            SENTRY_LOG_WARN(@"Only instances of NSString and NSRegularExpression are supported "
                            @"inside tracePropagationTargets.");
        }
    }

    _tracePropagationTargets = tracePropagationTargets;
}

- (void)setFailedRequestTargets:(NSArray *)failedRequestTargets
{
    for (id targetCheck in failedRequestTargets) {
        if (![targetCheck isKindOfClass:[NSRegularExpression class]]
            && ![targetCheck isKindOfClass:[NSString class]]) {
            SENTRY_LOG_WARN(@"Only instances of NSString and NSRegularExpression are supported "
                            @"inside failedRequestTargets.");
        }
    }

    _failedRequestTargets = failedRequestTargets;
}

- (void)setIntegrations:(NSArray<NSString *> *)integrations
{
    SENTRY_LOG_WARN(
        @"Setting `SentryOptions.integrations` is deprecated. Integrations should be enabled or "
        @"disabled using their respective `SentryOptions.enable*` property.");
    _integrations = integrations;
}

- (void)setDsn:(NSString *)dsn
{
    NSError *error = nil;
    self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:&error];

    if (error == nil) {
        _dsn = dsn;
    } else {
        SENTRY_LOG_ERROR(@"Could not parse the DSN: %@.", error);
    }
}

/**
 * Populates all @c SentryOptions values from @c options dict using fallbacks/defaults if needed.
 */
- (BOOL)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSPredicate *isNSString = [NSPredicate predicateWithBlock:^BOOL(
        id object, NSDictionary *bindings) { return [object isKindOfClass:[NSString class]]; }];

    [self setBool:options[@"debug"] block:^(BOOL value) { self->_debug = value; }];

    if ([options[@"diagnosticLevel"] isKindOfClass:[NSString class]]) {
        for (SentryLevel level = 0; level <= kSentryLevelFatal; level++) {
            if ([nameForSentryLevel(level) isEqualToString:options[@"diagnosticLevel"]]) {
                self.diagnosticLevel = level;
                break;
            }
        }
    }

    if (options[@"dsn"] != [NSNull null]) {
        NSString *dsn = @"";
        if (nil != options[@"dsn"] && [options[@"dsn"] isKindOfClass:[NSString class]]) {
            dsn = options[@"dsn"];
        }

        self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (self.parsedDsn == nil) {
            return NO;
        }
    }

    if ([options[@"release"] isKindOfClass:[NSString class]]) {
        self.releaseName = options[@"release"];
    }

    if ([options[@"environment"] isKindOfClass:[NSString class]]) {
        self.environment = options[@"environment"];
    }

    if ([options[@"dist"] isKindOfClass:[NSString class]]) {
        self.dist = options[@"dist"];
    }

    [self setBool:options[@"enabled"] block:^(BOOL value) { self->_enabled = value; }];

    if ([options[@"shutdownTimeInterval"] isKindOfClass:[NSNumber class]]) {
        self.shutdownTimeInterval = [options[@"shutdownTimeInterval"] doubleValue];
    }

    [self setBool:options[@"enableCrashHandler"]
            block:^(BOOL value) { self->_enableCrashHandler = value; }];

#if !TARGET_OS_WATCH
    [self setBool:options[@"enableSigtermReporting"]
            block:^(BOOL value) { self->_enableSigtermReporting = value; }];
#endif // !TARGET_OS_WATCH

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        self.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    [self setBool:options[@"enableNetworkBreadcrumbs"]
            block:^(BOOL value) { self->_enableNetworkBreadcrumbs = value; }];

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        self.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
    }

    if ([options[@"cacheDirectoryPath"] isKindOfClass:[NSString class]]) {
        self.cacheDirectoryPath = options[@"cacheDirectoryPath"];
    }

    if ([self isBlock:options[@"beforeSend"]]) {
        self.beforeSend = options[@"beforeSend"];
    }

    if ([self isBlock:options[@"beforeSendSpan"]]) {
        self.beforeSendSpan = options[@"beforeSendSpan"];
    }

    if ([self isBlock:options[@"beforeBreadcrumb"]]) {
        self.beforeBreadcrumb = options[@"beforeBreadcrumb"];
    }

    if ([self isBlock:options[@"beforeCaptureScreenshot"]]) {
        self.beforeCaptureScreenshot = options[@"beforeCaptureScreenshot"];
    }

    if ([self isBlock:options[@"onCrashedLastRun"]]) {
        self.onCrashedLastRun = options[@"onCrashedLastRun"];
    }

    if ([options[@"integrations"] isKindOfClass:[NSArray class]]) {
        self.integrations = [options[@"integrations"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"sampleRate"] isKindOfClass:[NSNumber class]]) {
        self.sampleRate = options[@"sampleRate"];
    }

    [self setBool:options[@"enableAutoSessionTracking"]
            block:^(BOOL value) { self->_enableAutoSessionTracking = value; }];

    [self setBool:options[@"enableGraphQLOperationTracking"]
            block:^(BOOL value) { self->_enableGraphQLOperationTracking = value; }];

    [self setBool:options[@"enableWatchdogTerminationTracking"]
            block:^(BOOL value) { self->_enableWatchdogTerminationTracking = value; }];

    [self setBool:options[@"swiftAsyncStacktraces"]
            block:^(BOOL value) { self->_swiftAsyncStacktraces = value; }];

    if ([options[@"sessionTrackingIntervalMillis"] isKindOfClass:[NSNumber class]]) {
        self.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    [self setBool:options[@"attachStacktrace"]
            block:^(BOOL value) { self->_attachStacktrace = value; }];

    if ([options[@"maxAttachmentSize"] isKindOfClass:[NSNumber class]]) {
        self.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }

    [self setBool:options[@"sendDefaultPii"]
            block:^(BOOL value) { self->_sendDefaultPii = value; }];

    [self setBool:options[@"enableAutoPerformanceTracing"]
            block:^(BOOL value) { self->_enableAutoPerformanceTracing = value; }];

    [self setBool:options[@"enablePerformanceV2"]
            block:^(BOOL value) { self->_enablePerformanceV2 = value; }];

    [self setBool:options[@"enableCaptureFailedRequests"]
            block:^(BOOL value) { self->_enableCaptureFailedRequests = value; }];

    [self setBool:options[@"enableTimeToFullDisplayTracing"]
            block:^(BOOL value) { self->_enableTimeToFullDisplayTracing = value; }];

    if ([self isBlock:options[@"initialScope"]]) {
        self.initialScope = options[@"initialScope"];
    }
#if SENTRY_HAS_UIKIT
    [self setBool:options[@"enableUIViewControllerTracing"]
            block:^(BOOL value) { self->_enableUIViewControllerTracing = value; }];

    [self setBool:options[@"attachScreenshot"]
            block:^(BOOL value) { self->_attachScreenshot = value; }];

    [self setBool:options[@"attachViewHierarchy"]
            block:^(BOOL value) { self->_attachViewHierarchy = value; }];

    [self setBool:options[@"enableUserInteractionTracing"]
            block:^(BOOL value) { self->_enableUserInteractionTracing = value; }];

    if ([options[@"idleTimeout"] isKindOfClass:[NSNumber class]]) {
        self.idleTimeout = [options[@"idleTimeout"] doubleValue];
    }

    [self setBool:options[@"enablePreWarmedAppStartTracing"]
            block:^(BOOL value) { self->_enablePreWarmedAppStartTracing = value; }];

#endif // SENTRY_HAS_UIKIT

    [self setBool:options[@"enableAppHangTracking"]
            block:^(BOOL value) { self->_enableAppHangTracking = value; }];

    if ([options[@"appHangTimeoutInterval"] isKindOfClass:[NSNumber class]]) {
        self.appHangTimeoutInterval = [options[@"appHangTimeoutInterval"] doubleValue];
    }

    [self setBool:options[@"enableNetworkTracking"]
            block:^(BOOL value) { self->_enableNetworkTracking = value; }];

    [self setBool:options[@"enableFileIOTracing"]
            block:^(BOOL value) { self->_enableFileIOTracing = value; }];

    if ([options[@"tracesSampleRate"] isKindOfClass:[NSNumber class]]) {
        self.tracesSampleRate = options[@"tracesSampleRate"];
    }

    if ([self isBlock:options[@"tracesSampler"]]) {
        self.tracesSampler = options[@"tracesSampler"];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([options[@"enableTracing"] isKindOfClass:NSNumber.self]) {
        self.enableTracing = [options[@"enableTracing"] boolValue];
    }
#pragma clang diagnostic pop

    if ([options[@"inAppIncludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppIncludes =
            [options[@"inAppIncludes"] filteredArrayUsingPredicate:isNSString];
        _inAppIncludes = [_inAppIncludes arrayByAddingObjectsFromArray:inAppIncludes];
    }

    if ([options[@"inAppExcludes"] isKindOfClass:[NSArray class]]) {
        _inAppExcludes = [options[@"inAppExcludes"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"urlSession"] isKindOfClass:[NSURLSession class]]) {
        self.urlSession = options[@"urlSession"];
    }

    if ([options[@"urlSessionDelegate"] conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
        self.urlSessionDelegate = options[@"urlSessionDelegate"];
    }

    [self setBool:options[@"enableSwizzling"]
            block:^(BOOL value) { self->_enableSwizzling = value; }];

    if ([options[@"swizzleClassNameExcludes"] isKindOfClass:[NSSet class]]) {
        _swizzleClassNameExcludes =
            [options[@"swizzleClassNameExcludes"] filteredSetUsingPredicate:isNSString];
    }

    [self setBool:options[@"enableCoreDataTracing"]
            block:^(BOOL value) { self->_enableCoreDataTracing = value; }];

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if ([options[@"profilesSampleRate"] isKindOfClass:[NSNumber class]]) {
        self.profilesSampleRate = options[@"profilesSampleRate"];
    }

    if ([self isBlock:options[@"profilesSampler"]]) {
        self.profilesSampler = options[@"profilesSampler"];
    }

    [self setBool:options[@"enableProfiling"]
            block:^(BOOL value) { self->_enableProfiling = value; }];

    [self setBool:options[NSStringFromSelector(@selector(enableAppLaunchProfiling))]
            block:^(BOOL value) { self->_enableAppLaunchProfiling = value; }];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [self setBool:options[@"sendClientReports"]
            block:^(BOOL value) { self->_sendClientReports = value; }];

    [self setBool:options[@"enableAutoBreadcrumbTracking"]
            block:^(BOOL value) { self->_enableAutoBreadcrumbTracking = value; }];

    if ([options[@"tracePropagationTargets"] isKindOfClass:[NSArray class]]) {
        self.tracePropagationTargets = options[@"tracePropagationTargets"];
    }

    if ([options[@"failedRequestStatusCodes"] isKindOfClass:[NSArray class]]) {
        self.failedRequestStatusCodes = options[@"failedRequestStatusCodes"];
    }

    if ([options[@"failedRequestTargets"] isKindOfClass:[NSArray class]]) {
        self.failedRequestTargets = options[@"failedRequestTargets"];
    }

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, *)) {
        [self setBool:options[@"enableMetricKit"]
                block:^(BOOL value) { self->_enableMetricKit = value; }];
        [self setBool:options[@"enableMetricKitRawPayload"]
                block:^(BOOL value) { self->_enableMetricKitRawPayload = value; }];
    }
#endif // SENTRY_HAS_METRIC_KIT

    [self setBool:options[@"enableSpotlight"]
            block:^(BOOL value) { self->_enableSpotlight = value; }];

    if ([options[@"spotlightUrl"] isKindOfClass:[NSString class]]) {
        self.spotlightUrl = options[@"spotlightUrl"];
    }

    [self setBool:options[@"enableMetrics"] block:^(BOOL value) { self->_enableMetrics = value; }];

    [self setBool:options[@"enableDefaultTagsForMetrics"]
            block:^(BOOL value) { self->_enableDefaultTagsForMetrics = value; }];

    [self setBool:options[@"enableSpanLocalMetricAggregation"]
            block:^(BOOL value) { self->_enableSpanLocalMetricAggregation = value; }];

    if ([self isBlock:options[@"beforeEmitMetric"]]) {
        self.beforeEmitMetric = options[@"beforeEmitMetric"];
    }

    if ([options[@"experimental"] isKindOfClass:NSDictionary.class]) {
        [self.experimental validateOptions:options[@"experimental"]];
    }

    return YES;
}

- (void)setBool:(id)value block:(void (^)(BOOL))block
{
    // Entries in the dictionary can be NSNull. Especially, on React-Native, this can happen.
    if (value != nil && ![value isEqual:[NSNull null]]) {
        block([value boolValue]);
    }
}

- (void)addInAppInclude:(NSString *)inAppInclude
{
    _inAppIncludes = [self.inAppIncludes arrayByAddingObject:inAppInclude];
}

- (void)addInAppExclude:(NSString *)inAppExclude
{
    _inAppExcludes = [self.inAppExcludes arrayByAddingObject:inAppExclude];
}

- (void)setSampleRate:(NSNumber *)sampleRate
{
    if (sampleRate == nil) {
        _sampleRate = nil;
    } else if (sentry_isValidSampleRate(sampleRate)) {
        _sampleRate = sampleRate;
    } else {
        _sampleRate = SENTRY_DEFAULT_SAMPLE_RATE;
    }
}

BOOL
sentry_isValidSampleRate(NSNumber *sampleRate)
{
    double rate = [sampleRate doubleValue];
    return rate >= 0 && rate <= 1.0;
}

- (void)setEnableTracing:(BOOL)enableTracing
{
    //`enableTracing` is basically an alias to tracesSampleRate
    // by enabling it we set tracesSampleRate to maximum
    // if the user did not configured other ways to enable tracing
    if ((_enableTracing = enableTracing)) {
        if (_tracesSampleRate == nil && _tracesSampler == nil && _enableTracing) {
            _tracesSampleRate = @1;
        }
    }
    _enableTracingManual = YES;
}

- (void)setTracesSampleRate:(NSNumber *)tracesSampleRate
{
    if (tracesSampleRate == nil) {
        _tracesSampleRate = nil;
    } else if (sentry_isValidSampleRate(tracesSampleRate)) {
        _tracesSampleRate = tracesSampleRate;
        if (!_enableTracingManual) {
            _enableTracing = YES;
        }
    } else {
        _tracesSampleRate = SENTRY_DEFAULT_TRACES_SAMPLE_RATE;
    }
}

- (void)setTracesSampler:(SentryTracesSamplerCallback)tracesSampler
{
    _tracesSampler = tracesSampler;
    if (_tracesSampler != nil && !_enableTracingManual) {
        _enableTracing = YES;
    }
}

- (BOOL)isTracingEnabled
{
    return _enableTracing
        && ((_tracesSampleRate != nil && [_tracesSampleRate doubleValue] > 0)
            || _tracesSampler != nil);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)setProfilesSampleRate:(NSNumber *)profilesSampleRate
{
    if (profilesSampleRate == nil) {
        _profilesSampleRate = nil;
    } else if (sentry_isValidSampleRate(profilesSampleRate)) {
        _profilesSampleRate = profilesSampleRate;
    } else {
        _profilesSampleRate = SENTRY_DEFAULT_PROFILES_SAMPLE_RATE;
    }
}

- (BOOL)isProfilingEnabled
{
    return (_profilesSampleRate != nil && [_profilesSampleRate doubleValue] > 0)
        || _profilesSampler != nil || _enableProfiling;
}

- (BOOL)isContinuousProfilingEnabled
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // this looks a little weird with the `!self.enableProfiling` but that actually is the
    // deprecated way to say "enable trace-based profiling", which necessarily disables continuous
    // profiling as they are mutually exclusive modes
    return _profilesSampleRate == nil && _profilesSampler == nil && !self.enableProfiling;
#    pragma clang diagnostic pop
}

- (void)setEnableProfiling_DEPRECATED_TEST_ONLY:(BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.enableProfiling = enableProfiling_DEPRECATED_TEST_ONLY;
#    pragma clang diagnostic pop
}

- (BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return self.enableProfiling;
#    pragma clang diagnostic pop
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * Checks if the passed in block is actually of type block. We can't check if the block matches a
 * specific block without some complex objc runtime method calls and therefore we only check if it's
 * a block or not. Assigning a wrong block to the @c SentryOptions blocks still could lead to
 * crashes at runtime, but when someone uses the @c initWithDict they should better know what they
 * are doing.
 * @see Taken from https://gist.github.com/steipete/6ee378bd7d87f276f6e0
 */
- (BOOL)isBlock:(nullable id)block
{
    static Class blockClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockClass = [^{} class];
        while ([blockClass superclass] != NSObject.class) {
            blockClass = [blockClass superclass];
        }
    });

    return [block isKindOfClass:blockClass];
}

#if SENTRY_UIKIT_AVAILABLE

- (void)setEnableUIViewControllerTracing:(BOOL)enableUIViewControllerTracing
{
#    if SENTRY_HAS_UIKIT
    _enableUIViewControllerTracing = enableUIViewControllerTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enableUIViewControllerTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setAttachScreenshot:(BOOL)attachScreenshot
{
#    if SENTRY_HAS_UIKIT
    _attachScreenshot = attachScreenshot;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"attachScreenshot only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setAttachViewHierarchy:(BOOL)attachViewHierarchy
{
#    if SENTRY_HAS_UIKIT
    _attachViewHierarchy = attachViewHierarchy;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"attachViewHierarchy only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setEnableUserInteractionTracing:(BOOL)enableUserInteractionTracing
{
#    if SENTRY_HAS_UIKIT
    _enableUserInteractionTracing = enableUserInteractionTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enableUserInteractionTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setIdleTimeout:(NSTimeInterval)idleTimeout
{
#    if SENTRY_HAS_UIKIT
    _idleTimeout = idleTimeout;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"idleTimeout only works with UIKit enabled. Ensure you're using the right "
        @"configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setEnablePreWarmedAppStartTracing:(BOOL)enablePreWarmedAppStartTracing
{
#    if SENTRY_HAS_UIKIT
    _enablePreWarmedAppStartTracing = enablePreWarmedAppStartTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enablePreWarmedAppStartTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

#endif // SENTRY_UIKIT_AVAILABLE

- (void)setEnableSpotlight:(BOOL)value
{
    _enableSpotlight = value;
#if defined(RELEASE)
    if (value) {
        SENTRY_LOG_WARN(@"Enabling Spotlight for a release build. We recommend running Spotlight "
                        @"only for local development.");
    }
#endif // defined(RELEASE)
}

#if defined(DEBUG) || defined(TEST) || defined(TESTCI)
- (NSString *)debugDescription
{
    NSMutableString *propertiesDescription = [NSMutableString string];
    @autoreleasepool {
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList([self class], &outCount);
        for (i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            const char *propName = property_getName(property);
            if (propName) {
                NSString *propertyName = [NSString stringWithUTF8String:propName];
                NSString *propertyValue = [[self valueForKey:propertyName] description];
                [propertiesDescription appendFormat:@"  %@: %@\n", propertyName, propertyValue];
            } else {
                SENTRY_LOG_DEBUG(@"Failed to get a property name.");
            }
        }
        free(properties);
    }
    return [NSString stringWithFormat:@"<%@: {\n%@\n}>", self, propertiesDescription];
}
#endif // defined(DEBUG) || defined(TEST) || defined(TESTCI)

@end
