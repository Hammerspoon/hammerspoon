#import "SentryTraceProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    pragma mark - Private

NSTimer *_Nullable _sentry_threadUnsafe_traceProfileTimeoutTimer;

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _threadUnsafe_gTraceProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _threadUnsafe_gTraceProfiler;
} // namespace

@implementation SentryTraceProfiler

#    pragma mark - Public

+ (BOOL)startWithTracer:(SentryId *)traceId
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gTraceProfilerLock);

        if ([_threadUnsafe_gTraceProfiler isRunning]) {
            SENTRY_LOG_DEBUG(@"A trace profiler is already running.");
            sentry_trackProfilerForTracer(_threadUnsafe_gTraceProfiler, traceId);
            // record a new metric sample for every concurrent span start
            [_threadUnsafe_gTraceProfiler.metricProfiler recordMetrics];
            return YES;
        }

        _threadUnsafe_gTraceProfiler =
            [[SentryProfiler alloc] initWithMode:SentryProfilerModeTrace];
        if (_threadUnsafe_gTraceProfiler == nil) {
            SENTRY_LOG_WARN(@"Trace profiler was unable to be initialized, will not proceed.");
            return NO;
        }

        _threadUnsafe_gTraceProfiler.profilerId = [[SentryId alloc] init];
        sentry_trackProfilerForTracer(_threadUnsafe_gTraceProfiler, traceId);
    }

    [self scheduleTimeoutTimer];
    return YES;
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gTraceProfilerLock);
    return [_threadUnsafe_gTraceProfiler isRunning];
}

+ (void)recordMetrics
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gTraceProfilerLock);
    if (![_threadUnsafe_gTraceProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"No trace profiler is currently running.");
        return;
    }

    [_threadUnsafe_gTraceProfiler.metricProfiler recordMetrics];
}

#    pragma mark - Private

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
+ (void)scheduleTimeoutTimer
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
        std::lock_guard<std::mutex> l(_threadUnsafe_gTraceProfilerLock);
        if (_sentry_threadUnsafe_traceProfileTimeoutTimer != nil) {
            return;
        }

        _sentry_threadUnsafe_traceProfileTimeoutTimer =
            [SentryDependencyContainer.sharedInstance.timerFactory
                scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
                                       repeats:NO
                                         block:^(NSTimer *_Nonnull timer) {
                                             [self timeoutTimerExpired];
                                         }];
    }];
}

+ (void)timeoutTimerExpired
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gTraceProfilerLock);
    _sentry_threadUnsafe_traceProfileTimeoutTimer = nil;

    if (![_threadUnsafe_gTraceProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", self);
    [_threadUnsafe_gTraceProfiler stopForReason:SentryProfilerTruncationReasonTimeout];
}

#    pragma mark - Testing helpers

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
+ (SentryProfiler *_Nullable)getCurrentProfiler
{
    return _threadUnsafe_gTraceProfiler;
}

+ (void)resetConcurrencyTracking
{
    sentry_resetConcurrencyTracking();
}

+ (NSUInteger)currentProfiledTracers
{
    return sentry_currentProfiledTracers();
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
