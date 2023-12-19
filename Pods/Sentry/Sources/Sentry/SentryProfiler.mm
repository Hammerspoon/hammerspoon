#import "SentryProfiler+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "NSDate+SentryExtras.h"
#    import "SentryClient+Private.h"
#    import "SentryCurrentDateProvider.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryDispatchFactory.h"
#    import "SentryDispatchSourceWrapper.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemHeader.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryEvent+Private.h"
#    import "SentryFormatter.h"
#    import "SentryFramesTracker.h"
#    import "SentryHub+Private.h"
#    import "SentryId.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentrySDK+Private.h"
#    import "SentrySample.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentrySerialization.h"
#    import "SentrySpanId.h"
#    import "SentrySystemWrapper.h"
#    import "SentryThread.h"
#    import "SentryThreadWrapper.h"
#    import "SentryTime.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"

#    import <cstdint>
#    import <memory>

#    if SENTRY_HAS_UIKIT
#        import "SentryScreenFrames.h"
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

const int kSentryProfilerFrequencyHz = 101;
NSTimeInterval kSentryProfilerTimeoutInterval = 30;

NSString *const kSentryProfilerSerializationKeySlowFrameRenders = @"slow_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders = @"frozen_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrameRates = @"screen_frame_rates";

using namespace sentry::profiling;

std::mutex _gProfilerLock;
SentryProfiler *_Nullable _gCurrentProfiler;

BOOL
threadSanitizerIsPresent(void)
{
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    return YES;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    return NO;
}

NSString *
profilerTruncationReasonName(SentryProfilerTruncationReason reason)
{
    switch (reason) {
    case SentryProfilerTruncationReasonNormal:
        return @"normal";
    case SentryProfilerTruncationReasonAppMovedToBackground:
        return @"backgrounded";
    case SentryProfilerTruncationReasonTimeout:
        return @"timeout";
    }
}

#    if SENTRY_HAS_UIKIT
/**
 * Convert the data structure that records timestamps for GPU frame render info from
 * SentryFramesTracker to the structure expected for profiling metrics, and throw out any that
 * didn't occur within the profile time.
 * @param useMostRecentRecording @c SentryFramesTracker doesn't stop running once it starts.
 * Although we reset the profiling timestamps each time the profiler stops and starts, concurrent
 * transactions that start after the first one won't have a screen frame rate recorded within their
 * timeframe, because it will have already been recorded for the first transaction and isn't
 * recorded again unless the system changes it. In these cases, use the most recently recorded data
 * for it.
 */
NSArray<SentrySerializedMetricReading *> *
sliceGPUData(SentryFrameInfoTimeSeries *frameInfo, uint64_t startSystemTime, uint64_t endSystemTime,
    BOOL useMostRecentRecording)
{
    auto slicedGPUEntries = [NSMutableArray<SentrySerializedMetricEntry *> array];
    __block NSNumber *nearestPredecessorValue;
    [frameInfo enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto timestamp = obj[@"timestamp"].unsignedLongLongValue;

        if (!orderedChronologically(startSystemTime, timestamp)) {
            SENTRY_LOG_DEBUG(@"GPU info recorded (%llu) before transaction start (%llu), "
                             @"will not report it.",
                timestamp, startSystemTime);
            nearestPredecessorValue = obj[@"value"];
            return;
        }

        if (!orderedChronologically(timestamp, endSystemTime)) {
            SENTRY_LOG_DEBUG(@"GPU info recorded after transaction finished, won't record.");
            return;
        }
        const auto relativeTimestamp = getDurationNs(startSystemTime, timestamp);

        [slicedGPUEntries addObject:@ {
            @"elapsed_since_start_ns" : sentry_stringForUInt64(relativeTimestamp),
            @"value" : obj[@"value"],
        }];
    }];
    if (useMostRecentRecording && slicedGPUEntries.count == 0 && nearestPredecessorValue != nil) {
        [slicedGPUEntries addObject:@ {
            @"elapsed_since_start_ns" : @"0",
            @"value" : nearestPredecessorValue,
        }];
    }
    return slicedGPUEntries;
}
#    endif // SENTRY_HAS_UIKIT

/** Given an array of samples with absolute timestamps, return the serialized JSON mapping with
 * their data, with timestamps normalized relative to the provided transaction's start time. */
NSArray<NSDictionary *> *
serializedSamplesWithRelativeTimestamps(NSArray<SentrySample *> *samples, uint64_t startSystemTime)
{
    const auto result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        // This shouldn't happen as we would've filtered out any such samples, but we should still
        // guard against it before calling getDurationNs as a defensive measure
        if (!orderedChronologically(startSystemTime, sample.absoluteTimestamp)) {
            SENTRY_LOG_WARN(@"Filtered sample not chronological with transaction.");
            return;
        }
        const auto dict = [NSMutableDictionary dictionaryWithDictionary:@ {
            @"elapsed_since_start_ns" :
                sentry_stringForUInt64(getDurationNs(startSystemTime, sample.absoluteTimestamp)),
            @"thread_id" : sentry_stringForUInt64(sample.threadID),
            @"stack_id" : sample.stackIndex,
        }];
        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }

        [result addObject:dict];
    }];
    return result;
}

NSMutableDictionary<NSString *, id> *
serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    NSMutableArray<SentrySample *> *const samples = profileData[@"profile"][@"samples"];
    // We need at least two samples to be able to draw a stack frame for any given function: one
    // sample for the start of the frame and another for the end. Otherwise we would only have a
    // stack frame with 0 duration, which wouldn't make sense.
    if ([samples count] < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile");
        [hub.getClient recordLostEvent:kSentryDataCategoryProfile
                                reason:kSentryDiscardReasonEventProcessor];
        return nil;
    }

    // slice the profile data to only include the samples/metrics within the transaction
    const auto slicedSamples = slicedProfileSamples(samples, startSystemTime, endSystemTime);
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
        [hub.getClient recordLostEvent:kSentryDataCategoryProfile
                                reason:kSentryDiscardReasonEventProcessor];
        return nil;
    }
    const auto payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = serializedSamplesWithRelativeTimestamps(slicedSamples, startSystemTime);
    payload[@"profile"] = profile;

    payload[@"version"] = @"1";
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    for (SentryDebugMeta *debugImage in debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        payload[@"debug_meta"] = @ { @"images" : debugImages };
    }

    payload[@"os"] = @ {
        @"name" : sentry_getOSName(),
        @"version" : sentry_getOSVersion(),
        @"build_number" : sentry_getOSBuildNumber()
    };

    const auto isEmulated = sentry_isSimulatorBuild();
    payload[@"device"] = @{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"locale" : NSLocale.currentLocale.localeIdentifier,
        @"manufacturer" : @"Apple",
        @"model" : isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel()
    };

    payload[@"profile_id"] = [[[SentryId alloc] init] sentryIdString];
    payload[@"truncation_reason"] = truncationReason;
    payload[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment;
    payload[@"release"] = hub.getClient.options.releaseName;

    // add the gathered metrics
    auto metrics = serializedMetrics;

#    if SENTRY_HAS_UIKIT
    const auto mutableMetrics =
        [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
    const auto slowFrames = sliceGPUData(gpuData.slowFrameTimestamps, startSystemTime,
        endSystemTime, /*useMostRecentRecording */ NO);
    if (slowFrames.count > 0) {
        mutableMetrics[@"slow_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : slowFrames };
    }

    const auto frozenFrames
        = sliceGPUData(gpuData.frozenFrameTimestamps, startSystemTime, endSystemTime,
            /*useMostRecentRecording */ NO);
    if (frozenFrames.count > 0) {
        mutableMetrics[@"frozen_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : frozenFrames };
    }

    if (slowFrames.count > 0 || frozenFrames.count > 0) {
        const auto frameRates
            = sliceGPUData(gpuData.frameRateTimestamps, startSystemTime, endSystemTime,
                /*useMostRecentRecording */ YES);
        if (frameRates.count > 0) {
            mutableMetrics[@"screen_frame_rates"] = @ { @"unit" : @"hz", @"values" : frameRates };
        }
    }
    metrics = mutableMetrics;
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

@implementation SentryProfiler {
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryMetricProfiler *_metricProfiler;
    SentryDebugImageProvider *_debugImageProvider;

    SentryProfilerTruncationReason _truncationReason;
    NSTimer *_timeoutTimer;
}

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    _profilerId = [[SentryId alloc] init];

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;

#    if SENTRY_HAS_UIKIT
    // the frame tracker may not be running if SentryOptions.enableAutoPerformanceTracing is NO
    [SentryDependencyContainer.sharedInstance.framesTracker start];
#    endif // SENTRY_HAS_UIKIT

    [self start];
    [self scheduleTimeoutTimer];

#    if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:self
           selector:@selector(backgroundAbort)
               name:UIApplicationWillResignActiveNotification
             object:nil];
#    endif // SENTRY_HAS_UIKIT

    return self;
}

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
- (void)scheduleTimeoutTimer
{
    __weak SentryProfiler *weakSelf = self;

    [SentryThreadWrapper onMainThread:^{
        if (![weakSelf isRunning]) {
            return;
        }

        SentryProfiler *strongSelf = weakSelf;
        strongSelf->_timeoutTimer = [SentryDependencyContainer.sharedInstance.timerFactory
            scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
                                    target:self
                                  selector:@selector(timeoutAbort)
                                  userInfo:nil
                                   repeats:NO];
    }];
}

#    pragma mark - Public

+ (BOOL)startWithTracer:(SentryId *)traceId
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler && [_gCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"A profiler is already running.");
        trackProfilerForTracer(_gCurrentProfiler, traceId);
        // record a new metric sample for every concurrent span start
        [_gCurrentProfiler->_metricProfiler recordMetrics];
        return YES;
    }

    _gCurrentProfiler = [[SentryProfiler alloc] init];
    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
        return NO;
    }

    trackProfilerForTracer(_gCurrentProfiler, traceId);
    return YES;
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
}

+ (void)recordMetrics
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    if (_gCurrentProfiler == nil) {
        return;
    }
    [_gCurrentProfiler->_metricProfiler recordMetrics];
}

+ (nullable SentryEnvelopeItem *)createProfilingEnvelopeItemForTransaction:
    (SentryTransaction *)transaction
{
    const auto payload = [self collectProfileBetween:transaction.startSystemTime
                                                 and:transaction.endSystemTime
                                            forTrace:transaction.trace.internalID
                                               onHub:transaction.trace.hub];
    if (payload == nil) {
        return nil;
    }

    [self updateProfilePayload:payload forTransaction:transaction];
    return [self createEnvelopeItemForProfilePayload:payload];
}

+ (nullable SentryEnvelopeItem *)createEnvelopeItemForProfilePayload:
    (NSDictionary<NSString *, id> *)payload;
{
    const auto JSONData = [SentrySerialization dataWithJSONObject:payload];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    return [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
}

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(SentryId *)traceId
                                                                  onHub:(SentryHub *)hub;
{
    const auto profiler = profilerForFinishedTracer(traceId);
    if (!profiler) {
        return nil;
    }

    const auto payload = [profiler serializeBetween:startSystemTime and:endSystemTime onHub:hub];

#    if defined(TEST) || defined(TESTCI)
    [NSNotificationCenter.defaultCenter postNotificationName:@"SentryProfileCompleteNotification"
                                                      object:nil
                                                    userInfo:payload];
#    endif // defined(TEST) || defined(TESTCI)
    return payload;
}

#    pragma mark - Private

+ (void)updateProfilePayload:(NSMutableDictionary<NSString *, id> *)payload
              forTransaction:(SentryTransaction *)transaction;
{
    payload[@"platform"] = transaction.platform;
    payload[@"transaction"] = @{
        @"id" : transaction.eventId.sentryIdString,
        @"trace_id" : transaction.trace.traceId.sentryIdString,
        @"name" : transaction.transaction,
        @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
    };
    const auto timestamp = transaction.trace.originalStartTimestamp;
    if (UNLIKELY(timestamp == nil)) {
        SENTRY_LOG_WARN(@"There was no start timestamp on the provided transaction. Falling back "
                        @"to old behavior of using the current time.");
        payload[@"timestamp"] =
            [[SentryDependencyContainer.sharedInstance.dateProvider date] sentry_toIso8601String];
    } else {
        payload[@"timestamp"] = [timestamp sentry_toIso8601String];
    }
}

- (NSMutableDictionary<NSString *, id> *)serializeBetween:(uint64_t)startSystemTime
                                                      and:(uint64_t)endSystemTime
                                                    onHub:(SentryHub *)hub;
{
    return serializedProfileData([self._state copyProfilingData], startSystemTime, endSystemTime,
        profilerTruncationReasonName(_truncationReason),
        [_metricProfiler serializeBetween:startSystemTime and:endSystemTime],
        [_debugImageProvider getDebugImagesCrashed:NO], hub
#    if SENTRY_HAS_UIKIT
        ,
        self._screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
}

- (void)timeoutAbort
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", self);
    [self stopForReason:SentryProfilerTruncationReasonTimeout];
}

- (void)backgroundAbort
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to app moving to background.", self);
    [self stopForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

- (void)stopForReason:(SentryProfilerTruncationReason)reason
{
    [_timeoutTimer invalidate];
    [_metricProfiler stop];
    _truncationReason = reason;

    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Profiler is not currently running.");
        return;
    }

#    if SENTRY_HAS_UIKIT
    // if SentryOptions.enableAutoPerformanceTracing is NO, then we need to stop the frames tracker
    // from running outside of profiles because it isn't needed for anything else
    if (![[[[SentrySDK currentHub] getClient] options] enableAutoPerformanceTracing]) {
        [SentryDependencyContainer.sharedInstance.framesTracker stop];
    }
#    endif // SENTRY_HAS_UIKIT

    _profiler->stopSampling();
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);
}

- (void)startMetricProfiler
{
    _metricProfiler = [[SentryMetricProfiler alloc] init];
    [_metricProfiler start];
}

- (void)start
{
    if (threadSanitizerIsPresent()) {
        SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
        return;
    }

    if (_profiler != nullptr) {
        // This theoretically shouldn't be possible as long as we're checking for nil and running
        // profilers in +[start], but technically we should still cover nilness here as well. So,
        // we'll just bail and let the current one continue to do whatever it's already doing:
        // either currently sampling, or waiting to be queried and provide profile data to
        // SentryTracer for upload with transaction envelopes, so as not to lose that data.
        SENTRY_LOG_WARN(
            @"There is already a private profiler instance present, will not start a new one.");
        return;
    }

    // Pop the clang diagnostic to ignore unreachable code for TSAN runs
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
#            pragma clang diagnostic pop
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    SENTRY_LOG_DEBUG(@"Starting profiler.");

    SentryProfilerState *const state = [[SentryProfilerState alloc] init];
    self._state = state;
    _profiler = std::make_shared<SamplingProfiler>(
        [state](auto &backtrace) {
    // in test, we'll overwrite the sample's timestamp to one mocked by SentryCurrentDate
    // etal. Doing this in a unified way between tests and production required extensive
    // changes to the C++ layer, so we opted for this solution to avoid any potential
    // breakages or performance hits there.
#    if defined(TEST) || defined(TESTCI)
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp
                = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
            [state appendBacktrace:backtraceCopy];
#    else
            [state appendBacktrace:backtrace];
#    endif // defined(TEST) || defined(TESTCI)
        },
        kSentryProfilerFrequencyHz);
    _profiler->startSampling();

    [self startMetricProfiler];
}

- (BOOL)isRunning
{
    if (_profiler == nullptr) {
        return NO;
    }
    return _profiler->isSampling();
}

#    pragma mark - Testing helpers

#    if defined(TEST) || defined(TESTCI)
+ (SentryProfiler *)getCurrentProfiler
{
    return _gCurrentProfiler;
}

// this just calls through to SentryProfiledTracerConcurrency.resetConcurrencyTracking(). we have to
// do this through SentryTracer because SentryProfiledTracerConcurrency cannot be included in test
// targets via ObjC bridging headers because it contains C++.
+ (void)resetConcurrencyTracking
{
    resetConcurrencyTracking();
}

+ (NSUInteger)currentProfiledTracers
{
    return currentProfiledTracers();
}
#    endif // defined(TEST) || defined(TESTCI)

@end

#endif
