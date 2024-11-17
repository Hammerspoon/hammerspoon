#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

#    if SENTRY_HAS_UIKIT
#        import "SentryMetricProfiler.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

@class SentrySample;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSArray<SentrySample *> *_Nullable sentry_slicedProfileSamples(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime, uint64_t endSystemTime);

#    if SENTRY_HAS_UIKIT

/**
 * Convert the data structure that records timestamps for GPU frame render info from
 * @c SentryFramesTracker to the structure expected for profiling metrics, and throw out any that
 * didn't occur within the profile time.
 * @param useMostRecentRecording @c SentryFramesTracker doesn't stop running once it starts.
 * Although we reset the profiling timestamps each time the profiler stops and starts, concurrent
 * transactions that start after the first one won't have a screen frame rate recorded within their
 * timeframe, because it will have already been recorded for the first transaction and isn't
 * recorded again unless the system changes it. In these cases, use the most recently recorded data
 * for it.
 */
NSArray<SentrySerializedMetricEntry *> *sentry_sliceTraceProfileGPUData(
    SentryFrameInfoTimeSeries *frameInfo, uint64_t startSystemTime, uint64_t endSystemTime,
    BOOL useMostRecentRecording);

NSArray<NSDictionary<NSString *, NSNumber *> *> *sentry_sliceContinuousProfileGPUData(
    SentryFrameInfoTimeSeries *frameInfo, NSTimeInterval start, NSTimeInterval end,
    BOOL useMostRecentFrameRate);

#    endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
