#import "SentryContinuousProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentrySDK+Private.h"
#    import "SentrySample.h"
#    import "SentrySwift.h"
#    include <mutex>

#    if SENTRY_HAS_UIKIT
#        import "SentryFramesTracker.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

#    pragma mark - Private

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _threadUnsafe_gContinuousProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _threadUnsafe_gContinuousCurrentProfiler;

NSTimer *_Nullable _chunkTimer;

/** @note: The session ID is reused for any profile sessions started in the same app session. */
SentryId *_profileSessionID;

void
disableTimer()
{
    [_chunkTimer invalidate];
    _chunkTimer = nil;
}

void
_sentry_threadUnsafe_transmitChunkEnvelope(void)
{
    const auto profiler = _threadUnsafe_gContinuousCurrentProfiler;
    const auto profilerState = [profiler.state copyProfilingData];
    [profiler.state clear]; // !!!: profile this to see if it takes longer than one sample duration
                            // length: ~9ms

    const auto metricProfilerState = [profiler.metricProfiler serializeContinuousProfileMetrics];
    [profiler.metricProfiler clear];

#    if SENTRY_HAS_UIKIT
    const auto framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
    SentryScreenFrames *screenFrameData = [framesTracker.currentFrames copy];
    [framesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT

    const auto envelope = sentry_continuousProfileChunkEnvelope(
        profiler.profilerId, profilerState, metricProfilerState
#    if SENTRY_HAS_UIKIT
        ,
        screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
    [SentrySDK captureEnvelope:envelope];
}
} // namespace

@implementation SentryContinuousProfiler

#    pragma mark - Public

+ (void)start
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

        if ([_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
            SENTRY_LOG_DEBUG(@"A continuous profiler is already running.");
            return;
        }

        if (!(_threadUnsafe_gContinuousCurrentProfiler =
                    [[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous])) {
            SENTRY_LOG_WARN(@"Continuous profiler was unable to be initialized.");
            return;
        }

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ _profileSessionID = [[SentryId alloc] init]; });
        _threadUnsafe_gContinuousCurrentProfiler.profilerId = _profileSessionID;
    }

    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        postNotification:[[NSNotification alloc]
                             initWithName:kSentryNotificationContinuousProfileStarted
                                   object:nil
                                 userInfo:nil]];
    [self scheduleTimer];
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return [_threadUnsafe_gContinuousCurrentProfiler isRunning];
}

+ (void)stop
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

        if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
            SENTRY_LOG_DEBUG(@"No continuous profiler is currently running.");
            return;
        }

        _sentry_threadUnsafe_transmitChunkEnvelope();
        disableTimer();

        [_threadUnsafe_gContinuousCurrentProfiler
            stopForReason:SentryProfilerTruncationReasonNormal];
        _threadUnsafe_gContinuousCurrentProfiler = nil;
    }
}

+ (nullable SentryId *)currentProfilerID
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return _threadUnsafe_gContinuousCurrentProfiler.profilerId;
}

#    pragma mark - Private

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
+ (void)scheduleTimer
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
        if (_chunkTimer != nil) {
            return;
        }

        _chunkTimer = [SentryDependencyContainer.sharedInstance.timerFactory
            scheduledTimerWithTimeInterval:kSentryProfilerChunkExpirationInterval
                                    target:self
                                  selector:@selector(timerExpired)
                                  userInfo:nil
                                   repeats:YES];
    }];
}

+ (void)timerExpired
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running. Sending whatever data it has left "
                        @"and disabling the timer from running again.");
        disableTimer();
    }

    _sentry_threadUnsafe_transmitChunkEnvelope();
}

#    pragma mark - Testing

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
+ (nullable SentryProfiler *)profiler
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return _threadUnsafe_gContinuousCurrentProfiler;
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
