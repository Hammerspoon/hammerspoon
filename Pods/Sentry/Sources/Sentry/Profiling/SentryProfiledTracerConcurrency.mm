#import "SentryProfiledTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    import "SentryDependencyContainer.h"
#    import "SentryEvent+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilingSwiftHelpers.h"
#    import "SentrySamplerDecision.h"
#    import "SentryTraceProfiler.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction.h"

#    if SENTRY_HAS_UIKIT
#        import "SentryAppStartMeasurement.h"
#        import "SentryFramesTracker.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

/**
 * a mapping of profilers to the number of tracers that started them that are still in-flight and
 * will need to query them for their profiling data when they finish. this helps resolve the
 * incongruity between the different timeout durations between tracers (500s) and profilers (30s),
 * where a transaction may start a profiler that then times out, and then a new transaction starts a
 * new profiler, and we must keep the aborted one around until its associated transaction finishes.
 */
static NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
    /* number of in-flight tracers */ NSNumber *> *_gProfilersToTracers;

/** provided for fast access to a profiler given a tracer */
static NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
    *_gTracersToProfilers;

static unsigned int _gInFlightRootSpans = 0;

namespace {

std::mutex _gStateLock;

/**
 * Remove a profiler from tracking given the id of the tracer it's associated with.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpTraceProfiler(SentryProfiler *profiler, NSString *tracerKey)
{
    const auto profilerKey = sentry_stringFromSentryID(profiler.profilerId);
    [_gTracersToProfilers removeObjectForKey:tracerKey];
    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue - 1);
    const auto remainingTracers = [_gProfilersToTracers[profilerKey] unsignedIntValue];
    if (remainingTracers > 0) {
        SENTRY_LOG_DEBUG(@"Waiting on %lu tracers to finish.", remainingTracers);
        return;
    }

    [_gProfilersToTracers removeObjectForKey:profilerKey];
    [profiler stopForReason:SentryProfilerTruncationReasonNormal];
}

/**
 * Decrement number of root spans in flight and stop continuous profiler if there are none left.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpContinuousProfilerV2()
{
    if (_gInFlightRootSpans == 0) {
        SENTRY_LOG_ERROR(@"Attemtpted to stop continuous profiler with no root spans in flight.");
    } else {
        _gInFlightRootSpans -= 1;
    }

    if (_gInFlightRootSpans == 0) {
        SENTRY_LOG_DEBUG(@"Last root span ended, stopping profiler.");
        [SentryContinuousProfiler stop];
    } else {
        SENTRY_LOG_DEBUG(@"Waiting for remaining root spans to finish before stopping profiler.");
    }
}

void
sentry_trackRootSpanForContinuousProfilerV2()
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (![SentryContinuousProfiler isCurrentlyProfiling] && _gInFlightRootSpans != 0) {
        SENTRY_LOG_ERROR(@"Unbalanced tracking of root spans and profiler detected.");
        return;
    }

    [SentryContinuousProfiler start];
    _gInFlightRootSpans += 1;
}

void
sentry_stopTrackingRootSpanForContinuousProfilerV2()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    _unsafe_cleanUpContinuousProfilerV2();
}

SentryId *_Nullable _sentry_startContinuousProfilerV2ForTrace(
    SentryProfileOptions *profileOptions, SentryTransactionContext *transactionContext)
{
    if (!sentry_isTraceLifecycle(profileOptions)) {
        return nil;
    }
    if (sentry_isNotSampled(transactionContext)) {
        return nil;
    }

    if (sentry_profileConfiguration.profilerSessionSampleDecision.decision
        != kSentrySampleDecisionYes) {
        return nil;
    }

    SentryId *profilerReferenceId = sentry_getSentryId();
    SENTRY_LOG_DEBUG(
        @"Starting continuous profiler for root span tracer with profilerReferenceId %@",
        sentry_stringFromSentryID(profilerReferenceId));
    sentry_trackRootSpanForContinuousProfilerV2();
    return profilerReferenceId;
}

} // namespace

void
sentry_trackTransactionProfilerForTrace(SentryProfiler *profiler, SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = sentry_stringFromSentryID(profiler.profilerId);
    const auto tracerKey = sentry_stringFromSentryID(internalTraceId);

    SENTRY_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    SENTRY_CASSERT((_gProfilersToTracers == nil && _gTracersToProfilers == nil)
            || (_gProfilersToTracers != nil && _gTracersToProfilers != nil),
        @"Both structures must be initialized simultaneously.");

    if (_gProfilersToTracers == nil) {
        _gProfilersToTracers = [NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
            /* number of in-flight tracers */ NSNumber *>
            dictionary];
        _gTracersToProfilers =
            [NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
                dictionary];
    }

    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue + 1);
    _gTracersToProfilers[tracerKey] = profiler;
}

void
sentry_discardProfilerCorrelatedToTrace(SentryId *internalTraceId, SentryHub *hub)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if ([SentryContinuousProfiler isCurrentlyProfiling]) {
        SENTRY_LOG_DEBUG(@"Stopping tracking discarded tracer with profileReferenceId %@",
            sentry_stringFromSentryID(internalTraceId));
        _unsafe_cleanUpContinuousProfilerV2();
    } else if (internalTraceId != nil) {
#    if !SDK_V9
        SentryClient *_Nullable client = hub.getClient;
        if (client == nil) {
            SENTRY_LOG_ERROR(@"No client found, skipping cleanup.");
            return;
        }
        if (sentry_isContinuousProfilingEnabled(SENTRY_UNWRAP_NULLABLE(SentryClient, client))) {
            SENTRY_LOG_ERROR(@"Tracers are not tracked with continuous profiling V1.");
            return;
        }
#    endif // !SDK_V9

        if (_gTracersToProfilers == nil) {
            SENTRY_LOG_ERROR(@"Tracer to profiler should have already been initialized by the "
                             @"time they are being queried");
        }

        const auto tracerKey = sentry_stringFromSentryID(internalTraceId);
        const auto profiler = _gTracersToProfilers[tracerKey];

        if (profiler == nil) {
            return;
        }

        _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
        if (_gProfilersToTracers == nil) {
            SENTRY_LOG_ERROR(@"Profiler to tracer structure should have already been "
                             @"initialized by the time they are being queried");
        }
        if (_gProfilersToTracers.count == 0) {
            [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
        }
#    endif // SENTRY_HAS_UIKIT
    }
}

SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (_gTracersToProfilers == nil || _gProfilersToTracers == nil) {
        SENTRY_LOG_ERROR(
            @"Structures should have already been initialized by the time they are being queried");
        return nil;
    }

    const auto tracerKey = sentry_stringFromSentryID(internalTraceId);
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (profiler == nil) {
        SENTRY_LOG_ERROR(@"Expected a profiler to be associated with tracer id %@.", tracerKey);
        return nil;
    }

    _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    profiler.screenFrameData =
        [SentryDependencyContainer.sharedInstance.framesTracker.currentFrames copy];
    SENTRY_LOG_DEBUG(
        @"Grabbing copy of frames tracker screen frames data to attach to profiler: %@.",
        profiler.screenFrameData);
    if (_gProfilersToTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

void
sentry_stopProfilerDueToFinishedTransaction(
    SentryHub *hub, SentryDispatchQueueWrapper *dispatchQueue, SentryTransaction *transaction,
    BOOL isProfiling, NSDate *traceStartTimestamp, uint64_t startSystemTime
#    if SENTRY_HAS_UIKIT
    ,
    SentryAppStartMeasurement *appStartMeasurement
#    endif // SENTRY_HAS_UIKIT
)
{
    if (sentry_profileConfiguration != nil && sentry_profileConfiguration.isProfilingThisLaunch
        && sentry_profileConfiguration.profileOptions != nil
        && sentry_isTraceLifecycle(SENTRY_UNWRAP_NULLABLE(
            SentryProfileOptions, sentry_profileConfiguration.profileOptions))) {
        SENTRY_LOG_DEBUG(@"Stopping launch UI trace profile.");
        sentry_stopTrackingRootSpanForContinuousProfilerV2();
        return;
    }

    SentryClient *_Nullable client = hub.getClient;
    if (isProfiling && client != nil
        && sentry_isContinuousProfilingV2Enabled(SENTRY_UNWRAP_NULLABLE(SentryClient, client))
        && sentry_isProfilingCorrelatedToTraces(SENTRY_UNWRAP_NULLABLE(SentryClient, client))) {
        SENTRY_LOG_DEBUG(@"Stopping tracking root span tracer with profilerReferenceId %@",
            sentry_stringFromSentryID(transaction.trace.profilerReferenceID));
        sentry_stopTrackingRootSpanForContinuousProfilerV2();
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    if (!isProfiling) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }

    NSDate *startTimestamp;

#    if SENTRY_HAS_UIKIT
    if (appStartMeasurement != nil) {
        startTimestamp = appStartMeasurement.runtimeInitTimestamp;
    }
#    endif // SENTRY_HAS_UIKIT

    if (startTimestamp == nil) {
        startTimestamp = traceStartTimestamp;
    }
    if (!SENTRY_CASSERT_RETURN(startTimestamp != nil,
            @"A transaction with a profile should have a start timestamp already. We will "
            @"assign the current time but this will be incorrect.")) {
        startTimestamp = sentry_getDate();
    }

    // if we have an app start span, use its app start timestamp. otherwise use the tracer's
    // start system time as we currently do
    SENTRY_LOG_DEBUG(@"Tracer start time: %llu", startSystemTime);

    transaction.startSystemTime = startSystemTime;
#    if SENTRY_HAS_UIKIT
    if (appStartMeasurement != nil) {
        SENTRY_LOG_DEBUG(@"Assigning transaction start time as app start system time (%llu)",
            appStartMeasurement.runtimeInitSystemTimestamp);
        transaction.startSystemTime = appStartMeasurement.runtimeInitSystemTimestamp;
    }
#    endif // SENTRY_HAS_UIKIT

    [SentryTraceProfiler recordMetrics];
    transaction.endSystemTime = sentry_getSystemTime();

    SentryProfiler *_Nullable nullableProfiler
        = sentry_profilerForFinishedTracer(transaction.trace.profilerReferenceID);
    if (!nullableProfiler) {
        [hub captureTransaction:transaction withScope:hub.scope];
        return;
    }
    SentryProfiler *_Nonnull profiler = SENTRY_UNWRAP_NULLABLE(SentryProfiler, nullableProfiler);

    // This code can run on the main thread, and the profile serialization can take a couple of
    // milliseconds. Therefore, we move this to a background thread to avoid potentially
    // blocking the main thread.
    sentry_dispatchAsync(dispatchQueue, ^{
        const auto profilingData = [profiler.state copyProfilingData];

        const auto profileEnvelopeItem = sentry_traceProfileEnvelopeItem(
            hub, profiler, profilingData, transaction, startTimestamp);

        if (!profileEnvelopeItem) {
            [hub captureTransaction:transaction withScope:hub.scope];
        } else {
            [hub captureTransaction:transaction
                              withScope:hub.scope
                additionalEnvelopeItems:@[ SENTRY_UNWRAP_NULLABLE(
                                            SentryEnvelopeItem, profileEnvelopeItem) ]];
        }
    });
}

SentryId *_Nullable sentry_startProfilerForTrace(SentryTracerConfiguration *configuration,
    SentryHub *hub, SentryTransactionContext *transactionContext)
{
    if (sentry_profileConfiguration.profileOptions != nil) {
        // launch profile; there's no hub to get options from, so they're read from the launch
        // profile config file
        return _sentry_startContinuousProfilerV2ForTrace(
            sentry_profileConfiguration.profileOptions, transactionContext);
    }
    SentryClient *_Nullable client = hub.getClient;
    if (client != nil
        && sentry_isContinuousProfilingV2Enabled(SENTRY_UNWRAP_NULLABLE(SentryClient, client))) {
        // non launch profile
        if (sentry_getParentSpanID(transactionContext) != nil) {
            SENTRY_LOG_DEBUG(@"Not a root span, will not start automatically for trace lifecycle.");
            return nil;
        }
        SentryProfileOptions *_Nullable profilingOptions
            = sentry_getProfiling(SENTRY_UNWRAP_NULLABLE(SentryClient, client));
        if (profilingOptions == nil) {
            SENTRY_LOG_DEBUG(@"No profiling options found, will not start profiler.");
            return nil;
        }
        return _sentry_startContinuousProfilerV2ForTrace(profilingOptions, transactionContext);
    }
    BOOL profileShouldBeSampled
        = configuration.profilesSamplerDecision.decision == kSentrySampleDecisionYes;
#    if !SDK_V9
    BOOL isContinuousProfiling = client != nil
        && sentry_isContinuousProfilingEnabled(SENTRY_UNWRAP_NULLABLE(SentryClient, client));
    BOOL shouldStartNormalTraceProfile = !isContinuousProfiling && profileShouldBeSampled;
#    else
    BOOL shouldStartNormalTraceProfile = profileShouldBeSampled;
#    endif // !SDK_V9

    if (sentry_isTracingAppLaunch || shouldStartNormalTraceProfile) {
        SentryId *internalID = sentry_getSentryId();
        if ([SentryTraceProfiler startWithTracer:internalID]) {
            SENTRY_LOG_DEBUG(@"Started profiler for trace %@ with internal id %@",
                sentry_stringFromSentryID(sentry_getTraceID(transactionContext)),
                sentry_stringFromSentryID(internalID));
            return internalID;
        }
    }
    return nil;
}

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
void
sentry_resetConcurrencyTracking()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    [_gTracersToProfilers removeAllObjects];
    [_gProfilersToTracers removeAllObjects];
    _gInFlightRootSpans = 0;
}

NSUInteger
sentry_currentProfiledTracers()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    return [_gTracersToProfilers count];
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
