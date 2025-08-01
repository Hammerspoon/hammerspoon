#import "SentryContinuousProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryLogC.h"
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
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

#    pragma mark - Private

NSTimeInterval kSentryProfilerChunkExpirationInterval = 60;

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _threadUnsafe_gContinuousProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _threadUnsafe_gContinuousCurrentProfiler;

NSTimer *_Nullable _chunkTimer;

/** @note: The session ID is reused for any profile sessions started in the same app session. */
SentryId *_profileSessionID;

/**
 * To avoid sending small chunks at the end of profiles, we let the current chunk run to the full
 * time after the call to stop the profiler is received.
 * */
BOOL _stopCalled;

#    if SENTRY_HAS_UIKIT
NSObject *_observerToken;
#    endif // SENTRY_HAS_UIKIT

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

void
_sentry_unsafe_stopTimerAndCleanup()
{
    disableTimer();

    [_threadUnsafe_gContinuousCurrentProfiler stopForReason:SentryProfilerTruncationReasonNormal];
    _threadUnsafe_gContinuousCurrentProfiler = nil;
}
} // namespace

@implementation SentryContinuousProfiler

#    pragma mark - Public

+ (void)start
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

        _stopCalled = NO;

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

#    if SENTRY_HAS_UIKIT
    _observerToken = [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserverForName:UIApplicationWillResignActiveNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull notification) {
                    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
                        removeObserver:_observerToken];
                    [self stopTimerAndCleanup];
                }];
#    endif // SENTRY_HAS_UIKIT
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return [_threadUnsafe_gContinuousCurrentProfiler isRunning];
}

+ (void)stop
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

    if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"No continuous profiler is currently running.");
        return;
    }

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    // we want to allow immediately stopping a continuous profile for a UI test, since those
    // currently only test launch profiles, and there is no reliable way to make the UI test
    // wait until the continuous profile chunk would finish (behavior introduced in
    // https://github.com/getsentry/sentry-cocoa/pull/4214). we just want to look in its samples
    // for a call to main()
    if ([NSProcessInfo.processInfo.arguments
            containsObject:@"--io.sentry.continuous-profiler-immediate-stop"]) {
        _sentry_threadUnsafe_transmitChunkEnvelope();
        _sentry_unsafe_stopTimerAndCleanup();
        return;
    }
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

    SENTRY_LOG_DEBUG(@"Stopping continuous profiler after current chunk completes.");
    _stopCalled = YES;
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
            SENTRY_LOG_WARN(@"There was already a timer in flight, but this codepath shouldn't be "
                            @"taken if there is no profiler running.");
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
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
        if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
            SENTRY_LOG_WARN(@"Current profiler is not running. Sending whatever data it has left "
                            @"and disabling the timer from running again.");
            disableTimer();
        }

        _sentry_threadUnsafe_transmitChunkEnvelope();

        if (!_stopCalled) {
            return;
        }
    }

    SENTRY_LOG_DEBUG(
        @"Last continuous profile chunk transmitted after stop called, shutting down profiler.");

#    if SENTRY_HAS_UIKIT
    if (_observerToken != nil) {
        [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
            removeObserver:_observerToken];
    }
#    endif // SENTRY_HAS_UIKIT

    [self stopTimerAndCleanup];
}

+ (void)stopTimerAndCleanup
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    _sentry_unsafe_stopTimerAndCleanup();
}

#    pragma mark - Testing

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
+ (nullable SentryProfiler *)profiler
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return _threadUnsafe_gContinuousCurrentProfiler;
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
