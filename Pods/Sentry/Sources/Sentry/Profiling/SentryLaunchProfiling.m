#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLogC.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfiler+Private.h"
#    import "SentryRandom.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySampling.h"
#    import "SentrySamplingContext.h"
#    import "SentrySpanOperation.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"
#    import "SentryTraceOrigin.h"
#    import "SentryTracer+Private.h"
#    import "SentryTracerConfiguration.h"
#    import "SentryTransactionContext+Private.h"

NS_ASSUME_NONNULL_BEGIN

BOOL isProfilingAppLaunch;
NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate = @"traces";
NSString *const kSentryLaunchProfileConfigKeyTracesSampleRand = @"traces.sample_rand";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate = @"profiles";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRand = @"profiles.sample_rand";
NSString *const kSentryLaunchProfileConfigKeyContinuousProfiling = @"continuous-profiling";
NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2
    = @"continuous-profiling-v2-enabled";
NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle
    = @"continuous-profiling-v2-lifecycle";
static SentryTracer *_Nullable launchTracer;

#    pragma mark - Private

SentryTracer *_Nullable sentry_launchTracer;

SentryTracerConfiguration *
sentry_configForLaunchProfilerForTrace(
    NSNumber *profilesRate, NSNumber *profilesRand, SentryProfileOptions *_Nullable profileOptions)
{
    SentryTracerConfiguration *config = [SentryTracerConfiguration defaultConfiguration];
    config.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:profilesRate
                                         withSampleRand:profilesRand];
    config.profileOptions = profileOptions;
    return config;
}

#    pragma mark - Package

typedef struct {
    BOOL shouldProfile;
    /** Only needed for trace launch profiling or continuous profiling v2 with trace lifecycle;
     * unused with continuous profiling. */
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SentryLaunchProfileConfig
sentry_launchShouldHaveTransactionProfiling(SentryOptions *options)
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL shouldProfileNextLaunch = options.enableAppLaunchProfiling && options.enableTracing;
    if (!shouldProfileNextLaunch) {
        SENTRY_LOG_DEBUG(@"Specified options configuration doesn't enable launch profiling: "
                         @"options.enableAppLaunchProfiling: %d; options.enableTracing: %d; won't "
                         @"profile launch",
            options.enableAppLaunchProfiling, options.enableTracing);
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }
#    pragma clang diagnostic pop

    SentryTransactionContext *transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
    transactionContext.forNextAppLaunch = YES;
    SentrySamplingContext *context =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];
    SentrySamplerDecision *tracesSamplerDecision = sentry_sampleTrace(context, options);
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(
            @"Sampling out the launch trace for transaction profiling; won't profile launch.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SentrySamplerDecision *profilesSamplerDecision
        = sentry_sampleTraceProfile(context, tracesSamplerDecision, options);
    if (profilesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(
            @"Sampling out the launch profile for transaction profiling; won't profile launch.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(@"Will start transaction profile next launch; will profile launch.");
    return (SentryLaunchProfileConfig) { YES, tracesSamplerDecision, profilesSamplerDecision };
}

SentryLaunchProfileConfig
sentry_launchShouldHaveContinuousProfilingV2(SentryOptions *options)
{
    if (!options.profiling.profileAppStarts) {
        SENTRY_LOG_DEBUG(@"Continuous profiling v2 enabled but disabled app start profiling, "
                         @"won't profile launch.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }
    if (options.profiling.lifecycle == SentryProfileLifecycleTrace) {
        if (!options.isTracingEnabled) {
            SENTRY_LOG_DEBUG(@"Continuous profiling v2 enabled for trace lifecycle but tracing is "
                             @"disabled, won't profile launch.");
            SENTRY_LOG_WARN(
                @"Tracing must be enabled in order to configure app start profiling with trace "
                @"lifecycle. See SentryOptions.tracesSampleRate and SentryOptions.tracesSampler.");
            return (SentryLaunchProfileConfig) { NO, nil, nil };
        }

        SentryTransactionContext *transactionContext =
            [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
        transactionContext.forNextAppLaunch = YES;
        SentrySamplingContext *context =
            [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];
        SentrySamplerDecision *tracesSamplerDecision = sentry_sampleTrace(context, options);
        if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(@"Sampling out the launch trace for continuous profile v2 trace "
                             @"lifecycle, won't profile launch.");
            return (SentryLaunchProfileConfig) { NO, nil, nil };
        }

        SentrySamplerDecision *profileSamplerDecision
            = sentry_sampleProfileSession(options.profiling.sessionSampleRate);
        if (profileSamplerDecision.decision != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(
                @"Sampling out continuous v2 trace lifecycle profile, won't profile launch.");
            return (SentryLaunchProfileConfig) { NO, nil, nil };
        }

        SENTRY_LOG_DEBUG(
            @"Continuous profiling v2 trace lifecycle conditions satisfied, will profile launch.");
        return (SentryLaunchProfileConfig) { YES, tracesSamplerDecision, profileSamplerDecision };
    }

    SentrySamplerDecision *profileSampleDecision
        = sentry_sampleProfileSession(options.profiling.sessionSampleRate);
    if (profileSampleDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out continuous v2 profile, won't profile launch.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(
        @"Continuous profiling v2 manual lifecycle conditions satisfied, will profile launch.");
    return (SentryLaunchProfileConfig) { YES, nil, profileSampleDecision };
}

SentryLaunchProfileConfig
sentry_shouldProfileNextLaunch(SentryOptions *options)
{
    if ([options isContinuousProfilingV2Enabled]) {
        return sentry_launchShouldHaveContinuousProfilingV2(options);
    }

    if ([options isContinuousProfilingEnabled]) {
        return (SentryLaunchProfileConfig) { options.enableAppLaunchProfiling, nil, nil };
    }

    return sentry_launchShouldHaveTransactionProfiling(options);
}

SentryTransactionContext *
sentry_contextForLaunchProfilerForTrace(NSNumber *tracesRate, NSNumber *tracesRand)
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithName:@"launch"
                                            nameSource:kSentryTransactionNameSourceCustom
                                             operation:SentrySpanOperationAppLifecycle
                                                origin:SentryTraceOriginAutoAppStartProfile
                                               sampled:kSentrySampleDecisionYes
                                            sampleRate:tracesRate
                                            sampleRand:tracesRand];
    return context;
}

/**
 * We remove the config file after successfully starting a launch profile. the config should
 * only apply to a single launch. subsequent launches must be configured by subsequent calls to
 * @c SentrySDK.startWIithOptions ; if that is not called, either deliberately by SDK consumers or
 * due to a problem before it can run, then we won't reuse the config–in the worst case, the launch
 * profile itself is the root cause of such a cycle, so this mitigates that and other possibities
 */
void
_sentry_cleanUpConfigFile(void)
{
    removeAppLaunchProfilingConfigFile();
}

#    pragma mark - Testing only

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
BOOL
sentry_willProfileNextLaunch(SentryOptions *options)
{
    return sentry_shouldProfileNextLaunch(options).shouldProfile;
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#    pragma mark - Exposed only to tests

void
_sentry_nondeduplicated_startLaunchProfile(void)
{
    if (!appLaunchProfileConfigFileExists()) {
        SENTRY_LOG_DEBUG(@"No launch profile config exists, will not profile launch.");
        return;
    }

#    if defined(DEBUG)
    // quick and dirty way to get debug logging this early in the process run. this will get
    // overwritten once SentrySDK.startWithOptions is called according to the values of
    // SentryOptions.debug and SentryOptions.diagnosticLevel
    [SentrySDKLogSupport configure:YES diagnosticLevel:kSentryLevelDebug];
#    endif // defined(DEBUG)

    NSDictionary<NSString *, NSNumber *> *launchConfig = sentry_appLaunchProfileConfiguration();

    if (launchConfig == nil) {
        SENTRY_LOG_DEBUG(@"No launch profile config exists, will not profile launch.");
        _sentry_cleanUpConfigFile();
        return;
    }

    if ([launchConfig[kSentryLaunchProfileConfigKeyContinuousProfiling] boolValue]) {
        SENTRY_LOG_DEBUG(@"Starting continuous launch profile v1.");
        [SentryContinuousProfiler start];
        _sentry_cleanUpConfigFile();
        return;
    }

    SentryProfileOptions *profileOptions = nil;
    if ([launchConfig[kSentryLaunchProfileConfigKeyContinuousProfilingV2] boolValue]) {
        SENTRY_LOG_DEBUG(@"Starting continuous launch profile v2.");
        NSNumber *lifecycleValue
            = launchConfig[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle];
        if (lifecycleValue == nil) {
            SENTRY_LOG_ERROR(
                @"Missing expected launch profile config parameter for lifecycle. Will "
                @"not proceed with launch profile.");
            _sentry_cleanUpConfigFile();
            return;
        }

        SentryProfileLifecycle lifecycle = lifecycleValue.intValue;
        if (lifecycle == SentryProfileLifecycleManual) {
            NSNumber *sampleRate = launchConfig[kSentryLaunchProfileConfigKeyProfilesSampleRate];
            NSNumber *sampleRand = launchConfig[kSentryLaunchProfileConfigKeyProfilesSampleRand];

            if (sampleRate == nil || sampleRand == nil) {
                SENTRY_LOG_ERROR(
                    @"Tried to start a continuous profile v2 with no configured sample "
                    @"rate/rand. Will not run profiler.");
                _sentry_cleanUpConfigFile();
                return;
            }

            SentrySamplerDecision *decision =
                [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                                  forSampleRate:sampleRate
                                                 withSampleRand:sampleRand];
            sentry_profilerSessionSampleDecision = decision;

            [SentryContinuousProfiler start];
            _sentry_cleanUpConfigFile();
            return;
        }

        profileOptions = [[SentryProfileOptions alloc] init];
        profileOptions.lifecycle = lifecycle;
        profileOptions.profileAppStarts = true;
    }

    NSNumber *profilesRate = launchConfig[kSentryLaunchProfileConfigKeyProfilesSampleRate];
    if (profilesRate == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch profile sample rate, will not "
                         @"start trace profiler for launch.");
        _sentry_cleanUpConfigFile();
        return;
    }
    profileOptions.sessionSampleRate = profilesRate.floatValue;

    NSNumber *profilesRand = launchConfig[kSentryLaunchProfileConfigKeyProfilesSampleRand];
    if (profilesRand == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch profile sample rand, will not "
                         @"start trace profiler for launch.");
        _sentry_cleanUpConfigFile();
        return;
    }

    NSNumber *tracesRate = launchConfig[kSentryLaunchProfileConfigKeyTracesSampleRate];
    if (tracesRate == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch trace sample rate, will not start "
                         @"trace profiler for launch.");
        _sentry_cleanUpConfigFile();
        return;
    }

    NSNumber *tracesRand = launchConfig[kSentryLaunchProfileConfigKeyTracesSampleRand];
    if (tracesRand == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch trace sample rand, will not start "
                         @"trace profiler for launch.");
        _sentry_cleanUpConfigFile();
        return;
    }

    SENTRY_LOG_INFO(@"Starting app launch trace profile at %llu.",
        [SentryDefaultCurrentDateProvider getAbsoluteTime]);
    sentry_isTracingAppLaunch = YES;

    SentryTransactionContext *context
        = sentry_contextForLaunchProfilerForTrace(tracesRate, tracesRand);
    SentryTracerConfiguration *config
        = sentry_configForLaunchProfilerForTrace(profilesRate, profilesRand, profileOptions);
    SentrySamplerDecision *decision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:profilesRate
                                         withSampleRand:profilesRand];
    sentry_profilerSessionSampleDecision = decision;
    sentry_launchTracer = [[SentryTracer alloc] initWithTransactionContext:context
                                                                       hub:nil
                                                             configuration:config];

    _sentry_cleanUpConfigFile();
}

#    pragma mark - Public

BOOL sentry_isTracingAppLaunch;

void
sentry_configureLaunchProfiling(SentryOptions *options)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SentryLaunchProfileConfig config = sentry_shouldProfileNextLaunch(options);
        if (!config.shouldProfile) {
            SENTRY_LOG_DEBUG(@"Removing launch profile config file.");
            removeAppLaunchProfilingConfigFile();
            return;
        }

        NSMutableDictionary<NSString *, NSNumber *> *configDict =
            [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        if ([options isContinuousProfilingEnabled]) {
            if ([options isContinuousProfilingV2Enabled]) {
                SENTRY_LOG_DEBUG(@"Configuring continuous launch profile v2.");
                configDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2] = @YES;
                configDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle] =
                    @(options.profiling.lifecycle);
                if (options.profiling.lifecycle == SentryProfileLifecycleTrace) {
                    configDict[kSentryLaunchProfileConfigKeyTracesSampleRate]
                        = config.tracesDecision.sampleRate;
                    configDict[kSentryLaunchProfileConfigKeyTracesSampleRand]
                        = config.tracesDecision.sampleRand;
                }
                configDict[kSentryLaunchProfileConfigKeyProfilesSampleRate]
                    = config.profilesDecision.sampleRate;
                configDict[kSentryLaunchProfileConfigKeyProfilesSampleRand]
                    = config.profilesDecision.sampleRand;
            } else {
                SENTRY_LOG_DEBUG(@"Configuring continuous launch profile.");
                configDict[kSentryLaunchProfileConfigKeyContinuousProfiling] = @YES;
            }
        } else {
            SENTRY_LOG_DEBUG(@"Configuring trace launch profile.");
            configDict[kSentryLaunchProfileConfigKeyTracesSampleRate]
                = config.tracesDecision.sampleRate;
            configDict[kSentryLaunchProfileConfigKeyTracesSampleRand]
                = config.tracesDecision.sampleRand;
            configDict[kSentryLaunchProfileConfigKeyProfilesSampleRate]
                = config.profilesDecision.sampleRate;
            configDict[kSentryLaunchProfileConfigKeyProfilesSampleRand]
                = config.profilesDecision.sampleRand;
        }
        writeAppLaunchProfilingConfigFile(configDict);
    }];
}

void
sentry_startLaunchProfile(void)
{
    static dispatch_once_t onceToken;
    // this function is called from SentryTracer.load but in the future we may expose access
    // directly to customers, and we'll want to ensure it only runs once. dispatch_once is an
    // efficient operation so it's fine to leave this in the launch path in any case.
    dispatch_once(&onceToken, ^{ _sentry_nondeduplicated_startLaunchProfile(); });
}

void
sentry_stopAndTransmitLaunchProfile(SentryHub *hub)
{
    if (sentry_launchTracer == nil) {
        SENTRY_LOG_DEBUG(@"No launch tracer present to stop.");
        return;
    }

    sentry_launchTracer.hub = hub;
    sentry_stopAndDiscardLaunchProfileTracer();
}

void
sentry_stopAndDiscardLaunchProfileTracer(void)
{
    SENTRY_LOG_DEBUG(@"Finishing launch tracer.");
    [sentry_launchTracer finish];
    sentry_isTracingAppLaunch = NO;
    sentry_launchTracer = nil;
}

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
