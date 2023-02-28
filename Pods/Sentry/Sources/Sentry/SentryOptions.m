#import "SentryOptions.h"
#import "SentryANRTracker.h"
#import "SentryDsn.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentrySDK.h"

@interface
SentryOptions ()

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultSampleRate;
@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nullable, nonatomic, copy, readonly) NSNumber *defaultProfilesSampleRate;
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
#endif
@end

NSString *const kSentryDefaultEnvironment = @"production";

@implementation SentryOptions

- (void)setMeasurement:(SentryMeasurementValue *)measurement
{
}

+ (NSArray<NSString *> *)defaultIntegrations
{
    NSMutableArray<NSString *> *defaultIntegrations =
        @[
            @"SentryCrashIntegration",
#if SENTRY_HAS_UIKIT
            @"SentryScreenshotIntegration", @"SentryUIEventTrackingIntegration",
            @"SentryViewHierarchyIntegration",
#endif
            @"SentryANRTrackingIntegration", @"SentryFramesTrackingIntegration",
            @"SentryAutoBreadcrumbTrackingIntegration", @"SentryAutoSessionTrackingIntegration",
            @"SentryAppStartTrackingIntegration", @"SentryWatchdogTerminationTrackingIntegration",
            @"SentryPerformanceTrackingIntegration", @"SentryNetworkTrackingIntegration",
            @"SentryFileIOTrackingIntegration", @"SentryCoreDataTrackingIntegration"
        ]
            .mutableCopy;

    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        [defaultIntegrations addObject:@"SentryMetricKitIntegration"];
    }

    return defaultIntegrations;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.shutdownTimeInterval = 2.0;
        self.enableCrashHandler = YES;
        self.diagnosticLevel = kSentryLevelDebug;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.maxCacheItems = 30;
        _integrations = SentryOptions.defaultIntegrations;
        _defaultSampleRate = @1;
        self.sampleRate = _defaultSampleRate;
        self.enableAutoSessionTracking = YES;
        self.enableWatchdogTerminationTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.stitchAsyncCode = NO;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        self.sendDefaultPii = NO;
        self.enableAutoPerformanceTracing = YES;
        self.enableCaptureFailedRequests = YES;
        self.environment = kSentryDefaultEnvironment;
#if SENTRY_HAS_UIKIT
        self.enableUIViewControllerTracing = YES;
        self.attachScreenshot = NO;
        self.attachViewHierarchy = NO;
        self.enableUserInteractionTracing = YES;
        self.idleTimeout = 3.0;
        self.enablePreWarmedAppStartTracing = NO;
#endif
        self.enableAppHangTracking = YES;
        self.appHangTimeoutInterval = 2.0;
        self.enableAutoBreadcrumbTracking = YES;
        self.enableNetworkTracking = YES;
        self.enableFileIOTracing = YES;
        self.enableNetworkBreadcrumbs = YES;
        _defaultTracesSampleRate = nil;
        self.tracesSampleRate = _defaultTracesSampleRate;
#if SENTRY_TARGET_PROFILING_SUPPORTED
        _enableProfiling = NO;
        _defaultProfilesSampleRate = nil;
        self.profilesSampleRate = _defaultProfilesSampleRate;
#endif
        self.enableCoreDataTracing = YES;
        _enableSwizzling = YES;
        self.sendClientReports = YES;

#if TARGET_OS_OSX
        NSString *dsn = [[[NSProcessInfo processInfo] environment] objectForKey:@"SENTRY_DSN"];
        if (dsn.length > 0) {
            self.dsn = dsn;
        }
#endif

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

#if SENTRY_HAS_METRIC_KIT
        if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
            self.enableMetricKit = NO;
        }
#endif
    }
    return self;
}

- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (self = [self init]) {
        if (![self validateOptions:options didFailWithError:error]) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Failed to initialize: %@", *error]
                      andLevel:kSentryLevelError];
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
 * Populates all `SentryOptions` values from `options` dict using fallbacks/defaults if needed.
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

    NSString *dsn = @"";
    if (nil != options[@"dsn"] && [options[@"dsn"] isKindOfClass:[NSString class]]) {
        dsn = options[@"dsn"];
    }

    self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];

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

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        self.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    [self setBool:options[@"enableNetworkBreadcrumbs"]
            block:^(BOOL value) { self->_enableNetworkBreadcrumbs = value; }];

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        self.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
    }

    if ([self isBlock:options[@"beforeSend"]]) {
        self.beforeSend = options[@"beforeSend"];
    }

    if ([self isBlock:options[@"beforeBreadcrumb"]]) {
        self.beforeBreadcrumb = options[@"beforeBreadcrumb"];
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

    [self setBool:options[@"enableWatchdogTerminationTracking"]
            block:^(BOOL value) { self->_enableWatchdogTerminationTracking = value; }];

    if ([options[@"sessionTrackingIntervalMillis"] isKindOfClass:[NSNumber class]]) {
        self.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    [self setBool:options[@"attachStacktrace"]
            block:^(BOOL value) { self->_attachStacktrace = value; }];

    [self setBool:options[@"stitchAsyncCode"]
            block:^(BOOL value) { self->_stitchAsyncCode = value; }];

    if ([options[@"maxAttachmentSize"] isKindOfClass:[NSNumber class]]) {
        self.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }

    [self setBool:options[@"sendDefaultPii"]
            block:^(BOOL value) { self->_sendDefaultPii = value; }];

    [self setBool:options[@"enableAutoPerformanceTracing"]
            block:^(BOOL value) { self->_enableAutoPerformanceTracing = value; }];

    [self setBool:options[@"enableCaptureFailedRequests"]
            block:^(BOOL value) { self->_enableCaptureFailedRequests = value; }];

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
#endif

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

    if ([options[@"inAppIncludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppIncludes =
            [options[@"inAppIncludes"] filteredArrayUsingPredicate:isNSString];
        _inAppIncludes = [_inAppIncludes arrayByAddingObjectsFromArray:inAppIncludes];
    }

    if ([options[@"inAppExcludes"] isKindOfClass:[NSArray class]]) {
        _inAppExcludes = [options[@"inAppExcludes"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"urlSessionDelegate"] conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
        self.urlSessionDelegate = options[@"urlSessionDelegate"];
    }

    [self setBool:options[@"enableSwizzling"]
            block:^(BOOL value) { self->_enableSwizzling = value; }];

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
#endif

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
    }
#endif

    if (nil != error && nil != *error) {
        return NO;
    } else {
        return YES;
    }
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
    } else if ([self isValidSampleRate:sampleRate]) {
        _sampleRate = sampleRate;
    } else {
        _sampleRate = _defaultSampleRate;
    }
}

- (BOOL)isValidSampleRate:(NSNumber *)sampleRate
{
    // Same valid range, so we can reuse the logic.
    return [self isValidTracesSampleRate:sampleRate];
}

- (void)setTracesSampleRate:(NSNumber *)tracesSampleRate
{
    if (tracesSampleRate == nil) {
        _tracesSampleRate = nil;
    } else if ([self isValidTracesSampleRate:tracesSampleRate]) {
        _tracesSampleRate = tracesSampleRate;
    } else {
        _tracesSampleRate = _defaultTracesSampleRate;
    }
}

- (BOOL)isValidTracesSampleRate:(NSNumber *)tracesSampleRate
{
    double rate = [tracesSampleRate doubleValue];
    return rate >= 0 && rate <= 1.0;
}

- (BOOL)isTracingEnabled
{
    return (_tracesSampleRate != nil && [_tracesSampleRate doubleValue] > 0)
        || _tracesSampler != nil;
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (BOOL)isValidProfilesSampleRate:(NSNumber *)profilesSampleRate
{
    return [self isValidTracesSampleRate:profilesSampleRate];
}

- (void)setProfilesSampleRate:(NSNumber *)profilesSampleRate
{
    if (profilesSampleRate == nil) {
        _profilesSampleRate = nil;
    } else if ([self isValidProfilesSampleRate:profilesSampleRate]) {
        _profilesSampleRate = profilesSampleRate;
    } else {
        _profilesSampleRate = _defaultProfilesSampleRate;
    }
}

- (BOOL)isProfilingEnabled
{
    return (_profilesSampleRate != nil && [_profilesSampleRate doubleValue] > 0)
        || _profilesSampler != nil || _enableProfiling;
}

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)setEnableProfiling_DEPRECATED_TEST_ONLY:(BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
    self.enableProfiling = enableProfiling_DEPRECATED_TEST_ONLY;
}

- (BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
    return self.enableProfiling;
}
#    pragma clang diagnostic pop
#endif

/**
 * Checks if the passed in block is actually of type block. We can't check if the block matches a
 * specific block without some complex objc runtime method calls and therefore we only check if its
 * a block or not. Assigning a wrong block to the SentryOption blocks still could lead to crashes at
 * runtime, but when someone uses the initWithDict they should better know what they are doing.
 *
 * Taken from https://gist.github.com/steipete/6ee378bd7d87f276f6e0
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

@end
