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
#import "SentryLogC.h"
#import "SentryMeta.h"
#import "SentryNetworkTrackingIntegration.h"
#import "SentryOptions+Private.h"
#import "SentryOptionsInternal.h"
#import "SentrySDKInternal.h"
#import "SentryScope.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"
#import "SentrySwiftAsyncIntegration.h"
#import "SentryTracer.h"
#import <objc/runtime.h>

NSString *const kSentryDefaultEnvironment = @"production";

@implementation SentryOptions {
#if !SDK_V9
    BOOL _enableTracingManual;
#endif // !SDK_V9
#if SWIFT_PACKAGE || SENTRY_TEST
    id _beforeSendLogDynamic;
#endif // SWIFT_PACKAGE || SENTRY_TEST
}

#if SWIFT_PACKAGE || SENTRY_TEST
// Provide explicit implementation for SPM builds where the property is excluded from header
// Use id to avoid typedef dependency, Swift extension provides type safety
- (id)beforeSendLogDynamic
{
    return _beforeSendLogDynamic;
}

- (void)setBeforeSendLogDynamic:(id)beforeSendLogDynamic
{
    _beforeSendLogDynamic = beforeSendLogDynamic;
}

#endif // SWIFT_PACKAGE || SENTRY_TEST

+ (NSArray<NSString *> *)defaultIntegrations
{
    NSArray<Class> *defaultIntegrationClasses = [SentryOptionsInternal defaultIntegrationClasses];
    NSMutableArray<NSString *> *defaultIntegrationNames =
        [[NSMutableArray alloc] initWithCapacity:defaultIntegrationClasses.count];

    for (Class class in defaultIntegrationClasses) {
        [defaultIntegrationNames addObject:NSStringFromClass(class)];
    }

    return defaultIntegrationNames;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.shutdownTimeInterval = 2.0;
        self.enableCrashHandler = YES;
#if TARGET_OS_OSX
        self.enableUncaughtNSExceptionReporting = NO;
#endif // TARGET_OS_OSX
#if !TARGET_OS_WATCH
        self.enableSigtermReporting = NO;
#endif // !TARGET_OS_WATCH
        self.diagnosticLevel = kSentryLevelDebug;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.maxCacheItems = 30;
#if !SDK_V9
        _integrations = [SentryOptions defaultIntegrations];
#endif // !SDK_V9
        self.sampleRate = SENTRY_DEFAULT_SAMPLE_RATE;
        self.enableAutoSessionTracking = YES;
        self.enableGraphQLOperationTracking = NO;
        self.enableWatchdogTerminationTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        self.sendDefaultPii = NO;
        self.enableAutoPerformanceTracing = YES;
#if !SDK_V9
        self.enablePerformanceV2 = NO;
#endif // !SDK_V9
        self.enablePersistingTracesWhenCrashing = NO;
        self.enableCaptureFailedRequests = YES;
        self.environment = kSentryDefaultEnvironment;
        self.enableTimeToFullDisplayTracing = NO;

        self.initialScope = ^SentryScope *(SentryScope *scope) { return scope; };
        __swiftExperimentalOptions = [[SentryExperimentalOptions alloc] init];
#if !SDK_V9
        _enableTracing = NO;
        _enableTracingManual = NO;
#endif // !SDK_V9
#if SENTRY_HAS_UIKIT
        self.enableUIViewControllerTracing = YES;
        self.attachScreenshot = NO;
        self.screenshot = [[SentryViewScreenshotOptions alloc] init];
        self.attachViewHierarchy = NO;
        self.reportAccessibilityIdentifier = YES;
        self.enableUserInteractionTracing = YES;
        self.idleTimeout = SentryTracerDefaultTimeout;
        self.enablePreWarmedAppStartTracing = NO;
#    if !SDK_V9
        self.enableAppHangTrackingV2 = NO;
#    endif // !SDK_V9
        self.enableReportNonFullyBlockingAppHangs = YES;
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
        self.sessionReplay = [[SentryReplayOptions alloc] init];
#endif

        self.enableAppHangTracking = YES;
        self.appHangTimeoutInterval = 2.0;
        self.enableAutoBreadcrumbTracking = YES;
        self.enableNetworkTracking = YES;
        self.enableFileIOTracing = YES;
        self.enableNetworkBreadcrumbs = YES;
        self.tracesSampleRate = nil;
#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if !SDK_V9
        _enableProfiling = NO;
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.profilesSampleRate = SENTRY_INITIAL_PROFILES_SAMPLE_RATE;
#        pragma clang diagnostic pop
#    endif // !SDK_V9
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
        self.enableCoreDataTracing = YES;
        _enableSwizzling = YES;
        self.swizzleClassNameExcludes = [NSSet new];
        self.sendClientReports = YES;
        self.swiftAsyncStacktraces = NO;
        self.enableSpotlight = NO;
        self.spotlightUrl = @"http://localhost:8969/stream";

#if TARGET_OS_OSX
        NSString *dsn = [[[NSProcessInfo processInfo] environment] objectForKey:@"SENTRY_DSN"];
        if (dsn.length > 0) {
            self.dsn = dsn;
        }
#endif // TARGET_OS_OSX

        // Use the name of the bundle's executable file as inAppInclude, so SentryInAppLogic
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
                  .firstObject
            ?: @"";

#if SENTRY_HAS_METRIC_KIT
        if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
            self.enableMetricKit = NO;
            self.enableMetricKitRawPayload = NO;
        }
#endif // SENTRY_HAS_METRIC_KIT
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

#if !SDK_V9
- (void)setIntegrations:(NSArray<NSString *> *)integrations
{
    _integrations = integrations.mutableCopy;
}
#endif // !SDK_V9

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

#if !SDK_V9
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
#endif // !SDK_V9

- (void)setTracesSampleRate:(NSNumber *)tracesSampleRate
{
    if (tracesSampleRate == nil) {
        _tracesSampleRate = nil;
    } else if (sentry_isValidSampleRate(tracesSampleRate)) {
        _tracesSampleRate = tracesSampleRate;
#if !SDK_V9
        if (!_enableTracingManual) {
            _enableTracing = YES;
        }
#endif // !SDK_V9
    } else {
        _tracesSampleRate = SENTRY_DEFAULT_TRACES_SAMPLE_RATE;
    }
}

- (void)setTracesSampler:(SentryTracesSamplerCallback)tracesSampler
{
    _tracesSampler = tracesSampler;
#if !SDK_V9
    if (_tracesSampler != nil && !_enableTracingManual) {
        _enableTracing = YES;
    }
#endif // !SDK_V9
}

- (BOOL)isTracingEnabled
{
#if SDK_V9
    return (_tracesSampleRate != nil && [_tracesSampleRate doubleValue] > 0)
        || _tracesSampler != nil;
#else
    return _enableTracing
        && ((_tracesSampleRate != nil && [_tracesSampleRate doubleValue] > 0)
            || _tracesSampler != nil);
#endif // !SDK_V9
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if !SDK_V9
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
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // this looks a little weird with the `!self.enableProfiling` but that actually is the
    // deprecated way to say "enable trace-based profiling", which necessarily disables continuous
    // profiling as they are mutually exclusive modes
    return _profilesSampleRate == nil && _profilesSampler == nil && !self.enableProfiling;
#        pragma clang diagnostic pop
}

#    endif // !SDK_V9

- (BOOL)isContinuousProfilingV2Enabled
{
#    if SDK_V9
    return _profiling != nil;
#    else
    return [self isContinuousProfilingEnabled] && _profiling != nil;
#    endif // SDK_V9
}

- (BOOL)isProfilingCorrelatedToTraces
{
#    if SDK_V9
    return _profiling != nil && _profiling.lifecycle == SentryProfileLifecycleTrace;
#    else
    return ![self isContinuousProfilingEnabled]
        || (_profiling != nil && _profiling.lifecycle == SentryProfileLifecycleTrace);
#    endif // SDK_V9
}

#    if !SDK_V9
- (void)setEnableProfiling_DEPRECATED_TEST_ONLY:(BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.enableProfiling = enableProfiling_DEPRECATED_TEST_ONLY;
#        pragma clang diagnostic pop
}

- (BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return self.enableProfiling;
#        pragma clang diagnostic pop
}
#    endif // !SDK_V9
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

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

#    if SENTRY_TARGET_REPLAY_SUPPORTED

- (BOOL)enableViewRendererV2
{
    return self.sessionReplay.enableViewRendererV2;
}

- (BOOL)enableFastViewRendering
{
    return self.sessionReplay.enableFastViewRendering;
}

#    endif // SENTRY_TARGET_REPLAY_SUPPORTED

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

#if SENTRY_HAS_UIKIT
- (BOOL)isAppHangTrackingV2Disabled
{
#    if SDK_V9
    BOOL isV2Enabled = self.enableAppHangTracking;
#    else
    BOOL isV2Enabled = self.enableAppHangTrackingV2;
#    endif // SDK_V9
    return !isV2Enabled || self.appHangTimeoutInterval <= 0;
}
#endif // SENTRY_HAS_UIKIT

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
- (void)setConfigureUserFeedback:(SentryUserFeedbackConfigurationBlock)configureUserFeedback
{
    SentryUserFeedbackConfiguration *userFeedbackConfiguration =
        [[SentryUserFeedbackConfiguration alloc] init];
    self.userFeedbackConfiguration = userFeedbackConfiguration;
    configureUserFeedback(userFeedbackConfiguration);
}
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

#if defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
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
#endif // defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

@end
