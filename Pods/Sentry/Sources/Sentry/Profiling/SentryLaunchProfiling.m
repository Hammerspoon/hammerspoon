#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLogC.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiler+Private.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySampling.h"
#    import "SentrySamplingContext.h"
#    import "SentrySpanOperation.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"
#    import "SentryTraceOrigin.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTracerConfiguration.h"
#    import "SentryTransactionContext+Private.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate = @"traces";
NSString *const kSentryLaunchProfileConfigKeyTracesSampleRand = @"traces.sample_rand";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate = @"profiles";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRand = @"profiles.sample_rand";
#    if !SDK_V9
NSString *const kSentryLaunchProfileConfigKeyContinuousProfiling = @"continuous-profiling";
#    endif // !SDK_V9
NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2
    = @"continuous-profiling-v2-enabled";
NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle
    = @"continuous-profiling-v2-lifecycle";
NSString *const kSentryLaunchProfileConfigKeyWaitForFullDisplay
    = @"launch-profile.wait-for-full-display";

SentryTracer *_Nullable sentry_launchTracer;

#    pragma mark - Private

SentrySamplerDecision *_Nullable _sentry_profileSampleDecision(
    NSDictionary<NSString *, NSNumber *> *launchConfigDict)
{
    NSNumber *profilesRand = launchConfigDict[kSentryLaunchProfileConfigKeyProfilesSampleRand];
    if (profilesRand == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch profile sample rand, will not "
                         @"start trace profiler for launch.");
        return nil;
    }

    NSNumber *profilesRate = launchConfigDict[kSentryLaunchProfileConfigKeyProfilesSampleRate];
    if (profilesRate == nil) {
        SENTRY_LOG_DEBUG(
            @"Tried to start a profile with no configured sample rate. Will not run profiler.");
        return nil;
    }

    return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                             forSampleRate:profilesRate
                                            withSampleRand:profilesRand];
}

/**
 * Create a @c SentryLaunchProfileConfiguration , fill in its properties based on the dictionary of
 * persisted values loaded from disk, and set the in-memory data structure.
 */
void
_sentry_hydrateV2Options(NSDictionary<NSString *, NSNumber *> *launchConfigDict,
    SentryProfileOptions *profileOptions, SentrySamplerDecision *samplerDecision,
    SentryProfileLifecycle lifecycle, BOOL shouldWaitForFullDisplay)
{
    profileOptions.lifecycle = lifecycle;
    profileOptions.profileAppStarts = true;
    profileOptions.sessionSampleRate = samplerDecision.sampleRate.floatValue;

    sentry_profileConfiguration = [[SentryProfileConfiguration alloc]
        initContinuousProfilingV2WaitingForFullDisplay:shouldWaitForFullDisplay
                                       samplerDecision:samplerDecision
                                        profileOptions:profileOptions];
}

void
_sentry_continuousProfilingV1_startLaunchProfile(BOOL shouldWaitForFullDisplay)
{
    sentry_profileConfiguration =
        [[SentryProfileConfiguration alloc] initWaitingForFullDisplay:shouldWaitForFullDisplay
                                                         continuousV1:YES];
    [SentryContinuousProfiler start];
}

/**
 * Hydrate any relevant launch profiling options persisted from the previous launch and start a
 * trace that will automatically start a manual lifecycle continuous profile (v2)
 */
void
_sentry_continuousProfilingV2_startManualLaunchProfile(
    NSDictionary<NSString *, NSNumber *> *launchConfigDict, SentryProfileOptions *profileOptions,
    SentrySamplerDecision *decision, BOOL shouldWaitForFullDisplay)
{
    NSNumber *sampleRand = launchConfigDict[kSentryLaunchProfileConfigKeyProfilesSampleRand];

    if (sampleRand == nil) {
        SENTRY_LOG_ERROR(@"Tried to start a continuous profile v2 with no configured sample "
                         @"rate/rand. Will not run profiler.");
        return;
    }

    _sentry_hydrateV2Options(launchConfigDict, profileOptions, decision,
        SentryProfileLifecycleManual, shouldWaitForFullDisplay);

    [SentryContinuousProfiler start];
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

void
_sentry_startTraceProfiler(
    NSDictionary<NSString *, NSNumber *> *launchConfigDict, SentrySamplerDecision *decision)
{
    NSNumber *tracesRate = launchConfigDict[kSentryLaunchProfileConfigKeyTracesSampleRate];
    if (tracesRate == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch trace sample rate, will not start "
                         @"trace profiler for launch.");
        return;
    }

    NSNumber *tracesRand = launchConfigDict[kSentryLaunchProfileConfigKeyTracesSampleRand];
    if (tracesRand == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch trace sample rand, will not start "
                         @"trace profiler for launch.");
        return;
    }

    SENTRY_LOG_INFO(@"Starting app launch trace profile at %llu.",
        [SentryDefaultCurrentDateProvider getAbsoluteTime]);
    sentry_isTracingAppLaunch = YES;

    SentryTracerConfiguration *tracerConfig = [SentryTracerConfiguration defaultConfiguration];
    tracerConfig.profilesSamplerDecision = decision;

    SentryTransactionContext *transactionContext
        = sentry_contextForLaunchProfilerForTrace(tracesRate, tracesRand);
    sentry_launchTracer = [[SentryTracer alloc] initWithTransactionContext:transactionContext
                                                                       hub:nil
                                                             configuration:tracerConfig];
}

#    if !SDK_V9
SentryLaunchProfileDecision
sentry_launchShouldHaveTransactionProfiling(SentryOptions *options)
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL shouldProfileNextLaunch = options.enableAppLaunchProfiling && options.enableTracing;
    if (!shouldProfileNextLaunch) {
        SENTRY_LOG_DEBUG(@"Specified options configuration doesn't enable launch profiling: "
                         @"options.enableAppLaunchProfiling: %d; options.enableTracing: %d; won't "
                         @"profile launch",
            options.enableAppLaunchProfiling, options.enableTracing);
        return (SentryLaunchProfileDecision) { NO, nil, nil };
    }
#        pragma clang diagnostic pop

    SentryTransactionContext *transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
    transactionContext.forNextAppLaunch = YES;
    SentrySamplingContext *context =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];
    SentrySamplerDecision *tracesSamplerDecision = sentry_sampleTrace(context, options);
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(
            @"Sampling out the launch trace for transaction profiling; won't profile launch.");
        return (SentryLaunchProfileDecision) { NO, nil, nil };
    }

    SentrySamplerDecision *profilesSamplerDecision
        = sentry_sampleTraceProfile(context, tracesSamplerDecision, options);
    if (profilesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(
            @"Sampling out the launch profile for transaction profiling; won't profile launch.");
        return (SentryLaunchProfileDecision) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(@"Will start transaction profile next launch; will profile launch.");
    return (SentryLaunchProfileDecision) { YES, tracesSamplerDecision, profilesSamplerDecision };
}
#    endif // !SDK_V9

SentryLaunchProfileDecision
sentry_launchShouldHaveContinuousProfilingV2(SentryOptions *options)
{
    if (!options.profiling.profileAppStarts) {
        SENTRY_LOG_DEBUG(@"Continuous profiling v2 enabled but disabled app start profiling, "
                         @"won't profile launch.");
        return (SentryLaunchProfileDecision) { NO, nil, nil };
    }
    if (options.profiling.lifecycle == SentryProfileLifecycleTrace) {
        if (!options.isTracingEnabled) {
            SENTRY_LOG_DEBUG(@"Continuous profiling v2 enabled for trace lifecycle but tracing is "
                             @"disabled, won't profile launch.");
            SENTRY_LOG_WARN(
                @"Tracing must be enabled in order to configure app start profiling with trace "
                @"lifecycle. See SentryOptions.tracesSampleRate and SentryOptions.tracesSampler.");
            return (SentryLaunchProfileDecision) { NO, nil, nil };
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
            return (SentryLaunchProfileDecision) { NO, nil, nil };
        }

        SentrySamplerDecision *profileSamplerDecision
            = sentry_sampleProfileSession(options.profiling.sessionSampleRate);
        if (profileSamplerDecision.decision != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(
                @"Sampling out continuous v2 trace lifecycle profile, won't profile launch.");
            return (SentryLaunchProfileDecision) { NO, nil, nil };
        }

        SENTRY_LOG_DEBUG(
            @"Continuous profiling v2 trace lifecycle conditions satisfied, will profile launch.");
        return (SentryLaunchProfileDecision) { YES, tracesSamplerDecision, profileSamplerDecision };
    }

    SentrySamplerDecision *profileSampleDecision
        = sentry_sampleProfileSession(options.profiling.sessionSampleRate);
    if (profileSampleDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out continuous v2 profile, won't profile launch.");
        return (SentryLaunchProfileDecision) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(
        @"Continuous profiling v2 manual lifecycle conditions satisfied, will profile launch.");
    return (SentryLaunchProfileDecision) { YES, nil, profileSampleDecision };
}

SentryLaunchProfileDecision
sentry_shouldProfileNextLaunch(SentryOptions *options)
{
    if ([options isContinuousProfilingV2Enabled]) {
        return sentry_launchShouldHaveContinuousProfilingV2(options);
    }
#    if SDK_V9
    return (SentryLaunchProfileDecision) { NO, nil, nil };
#    else

#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([options isContinuousProfilingEnabled]) {
        return (SentryLaunchProfileDecision) { options.enableAppLaunchProfiling, nil, nil };
    }
#        pragma clang diagnostic pop

    return sentry_launchShouldHaveTransactionProfiling(options);
#    endif // SDK_V9
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

#    pragma mark - Exposed for testing

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
BOOL
sentry_willProfileNextLaunch(SentryOptions *options)
{
    return sentry_shouldProfileNextLaunch(options).shouldProfile;
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

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

    NSDictionary<NSString *, NSNumber *> *persistedLaunchConfigOptionsDict
        = sentry_persistedLaunchProfileConfigurationOptions();

    BOOL isContinuousV2 =
        [persistedLaunchConfigOptionsDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2]
            boolValue];
#    if !SDK_V9
    BOOL isContinuousV1 =
        [persistedLaunchConfigOptionsDict[kSentryLaunchProfileConfigKeyContinuousProfiling]
            boolValue];
    if (isContinuousV1 && isContinuousV2) {
        SENTRY_LOG_WARN(@"Launch profile misconfiguration detected.");
        _sentry_cleanUpConfigFile();
        return;
    }
#    else
    BOOL isContinuousV1 = false;
#    endif // !SDK_V9

    SentrySamplerDecision *decision
        = _sentry_profileSampleDecision(persistedLaunchConfigOptionsDict);
    if (!isContinuousV1 && nil == decision) {
        SENTRY_LOG_DEBUG(@"Couldn't hydrate the persisted sample decision.");
        _sentry_cleanUpConfigFile();
        return;
    }

    NSNumber *shouldWaitForFullDisplayValue
        = persistedLaunchConfigOptionsDict[kSentryLaunchProfileConfigKeyWaitForFullDisplay];
    if (shouldWaitForFullDisplayValue == nil) {
        SENTRY_LOG_DEBUG(@"Received a nil configured launch profile value indicating whether "
                         @"or not the profile should be finished on full display or SDK start, "
                         @"cannot know when to stop the profile, will not start this launch.");
        _sentry_cleanUpConfigFile();
        return;
    }

    BOOL shouldWaitForFullDisplay = shouldWaitForFullDisplayValue.boolValue;

    if (isContinuousV1) {
        SENTRY_LOG_DEBUG(@"Starting continuous launch profile v1.");
        _sentry_continuousProfilingV1_startLaunchProfile(shouldWaitForFullDisplay);
        _sentry_cleanUpConfigFile();
        return;
    }

    SentryProfileOptions *profileOptions = nil;
    if (isContinuousV2) {
        SENTRY_LOG_DEBUG(@"Starting continuous launch profile v2.");
        NSNumber *lifecycleValue = persistedLaunchConfigOptionsDict
            [kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle];
        if (lifecycleValue == nil) {
            SENTRY_LOG_ERROR(
                @"Missing expected launch profile config parameter for lifecycle. Will "
                @"not proceed with launch profile.");
            _sentry_cleanUpConfigFile();
            return;
        }

        profileOptions = [[SentryProfileOptions alloc] init];

        SentryProfileLifecycle lifecycle = lifecycleValue.intValue;
        if (lifecycle == SentryProfileLifecycleManual) {
            _sentry_continuousProfilingV2_startManualLaunchProfile(persistedLaunchConfigOptionsDict,
                profileOptions, decision, shouldWaitForFullDisplay);
            _sentry_cleanUpConfigFile();
            return;
        }

        _sentry_hydrateV2Options(persistedLaunchConfigOptionsDict, profileOptions, decision,
            SentryProfileLifecycleTrace, shouldWaitForFullDisplay);
    } else {
        sentry_profileConfiguration =
            [[SentryProfileConfiguration alloc] initWaitingForFullDisplay:shouldWaitForFullDisplay
                                                             continuousV1:NO];
    }

    // trace lifecycle UI profiling (continuous profiling v2) and trace-based profiling both join
    // paths here
    _sentry_startTraceProfiler(persistedLaunchConfigOptionsDict, decision);
    _sentry_cleanUpConfigFile();
}

#    pragma mark - Public

BOOL sentry_isTracingAppLaunch;

void
sentry_configureLaunchProfilingForNextLaunch(SentryOptions *options)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SentryLaunchProfileDecision config = sentry_shouldProfileNextLaunch(options);
        if (!config.shouldProfile) {
            SENTRY_LOG_DEBUG(@"Removing launch profile config file.");
            removeAppLaunchProfilingConfigFile();
            return;
        }

        NSMutableDictionary<NSString *, NSNumber *> *configDict =
            [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        configDict[kSentryLaunchProfileConfigKeyWaitForFullDisplay] =
            @(options.enableTimeToFullDisplayTracing);
#    if !SDK_V9
        if ([options isContinuousProfilingEnabled]) {
#    endif // !SDK_V9
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
#    if !SDK_V9
                SENTRY_LOG_DEBUG(@"Configuring continuous launch profile.");
                configDict[kSentryLaunchProfileConfigKeyContinuousProfiling] = @YES;
#    endif // !SDK_V9
            }
#    if !SDK_V9
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
#    endif // !SDK_V9
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
sentry_stopAndDiscardLaunchProfileTracer(SentryHub *_Nullable hub)
{
    SENTRY_LOG_DEBUG(@"Finishing launch tracer.");
    sentry_launchTracer.hub = hub;
    [sentry_launchTracer finish];
    sentry_profileConfiguration = nil;
    sentry_isTracingAppLaunch = NO;
    sentry_launchTracer = nil;
}

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
