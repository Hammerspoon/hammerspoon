#import "SentryProfiledTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryProfiler+Private.h"
#    import "SentrySwift.h"
#    include <mutex>

#    if SENTRY_HAS_UIKIT
#        import "SentryDependencyContainer.h"
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

namespace {

/**
 * Remove a profiler from tracking given the id of the tracer it's associated with.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpProfiler(SentryProfiler *profiler, NSString *tracerKey)
{
    const auto profilerKey = profiler.profilerId.sentryIdString;

    [_gTracersToProfilers removeObjectForKey:tracerKey];
    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue - 1);
    if ([_gProfilersToTracers[profilerKey] unsignedIntValue] == 0) {
        [_gProfilersToTracers removeObjectForKey:profilerKey];
        if ([profiler isRunning]) {
            [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        }
    }
}

} // namespace

std::mutex _gStateLock;

void
sentry_trackProfilerForTracer(SentryProfiler *profiler, SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = profiler.profilerId.sentryIdString;
    const auto tracerKey = internalTraceId.sentryIdString;

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
sentry_discardProfilerForTracer(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gTracersToProfilers != nil && _gProfilersToTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = internalTraceId.sentryIdString;
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (profiler == nil) {
        return;
    }

    _unsafe_cleanUpProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    if (_gProfilersToTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT
}

SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gTracersToProfilers != nil && _gProfilersToTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = internalTraceId.sentryIdString;
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (!SENTRY_CASSERT_RETURN(profiler != nil,
            @"Expected a profiler to be associated with tracer id %@.", tracerKey)) {
        return nil;
    }

    _unsafe_cleanUpProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    profiler.screenFrameData =
        [SentryDependencyContainer.sharedInstance.framesTracker.currentFrames copy];
    if (_gProfilersToTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
void
sentry_resetConcurrencyTracking()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    [_gTracersToProfilers removeAllObjects];
    [_gProfilersToTracers removeAllObjects];
}

NSUInteger
sentry_currentProfiledTracers()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    return [_gTracersToProfilers count];
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
