#import "SentryProfilerSerialization.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryDateUtils.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemHeader.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryEvent+Private.h"
#    import "SentryFormatter.h"
#    import "SentryHub.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryOptions.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization+Test.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySample.h"
#    import "SentryScope+Private.h"
#    import "SentrySerialization.h"
#    import "SentrySwift.h"
#    import "SentryThread.h"
#    import "SentryTime.h"
#    import "SentryTracer+Private.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"

NSString *const kSentryProfilerSerializationKeySlowFrameRenders = @"slow_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders = @"frozen_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrameRates = @"screen_frame_rates";

#    pragma mark - Private

namespace {

/**
 * Given an array of samples with absolute timestamps, return the serialized JSON mapping with
 * their data, with timestamps normalized relative to the provided transaction's start time.
 * */
NSArray<NSDictionary *> *
_sentry_serializedTraceProfileSamplesWithRelativeTimestamps(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime)
{
    const auto result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        // This shouldn't happen as we would've filtered out any such samples, but we should still
        // guard against it before calling getDurationNs as a defensive measure
        if (!orderedChronologically(startSystemTime, sample.absoluteTimestamp)) {
            SENTRY_LOG_WARN(@"Filtering sample as it came before start time to begin slicing.");
            return;
        }
        const auto dict = [NSMutableDictionary dictionary];
        const auto durationNs = getDurationNs(startSystemTime, sample.absoluteTimestamp);
        dict[@"elapsed_since_start_ns"] = sentry_stringForUInt64(durationNs);

        dict[@"thread_id"] = sentry_stringForUInt64(sample.threadID);
        dict[@"stack_id"] = sample.stackIndex;

        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }

        [result addObject:dict];
    }];
    return result;
}

/**
 * Given an array of continuous profile samples with absolute NSDate timestamps, return the
 * serialized JSON mapping with their data.
 * */
NSArray<NSDictionary *> *
_sentry_serializedContinuousProfileSamples(NSArray<SentrySample *> *samples)
{
    const auto result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto dict = [NSMutableDictionary dictionary];
        dict[@"timestamp"] = @(sample.absoluteNSDateInterval);
        dict[@"thread_id"] = sentry_stringForUInt64(sample.threadID);
        dict[@"stack_id"] = sample.stackIndex;
        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }
        [result addObject:dict];
    }];
    return result;
}

} // namespace

#    pragma mark - Exported for tests

NSString *
sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason)
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

NSMutableDictionary<NSString *, id> *
sentry_serializedTraceProfileData(
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
    const auto slicedSamples = sentry_slicedProfileSamples(samples, startSystemTime, endSystemTime);
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
        [hub.getClient recordLostEvent:kSentryDataCategoryProfile
                                reason:kSentryDiscardReasonEventProcessor];
        return nil;
    }
    const auto payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = _sentry_serializedTraceProfileSamplesWithRelativeTimestamps(
        slicedSamples, startSystemTime);
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
    const auto slowFrames = sentry_sliceTraceProfileGPUData(gpuData.slowFrameTimestamps,
        startSystemTime, endSystemTime, /*useMostRecentFrameRate */ NO);
    if (slowFrames.count > 0) {
        mutableMetrics[kSentryProfilerSerializationKeySlowFrameRenders] =
            @ { @"unit" : @"nanosecond", @"values" : slowFrames };
    }

    const auto frozenFrames = sentry_sliceTraceProfileGPUData(gpuData.frozenFrameTimestamps,
        startSystemTime, endSystemTime,
        /*useMostRecentFrameRate */ NO);
    if (frozenFrames.count > 0) {
        mutableMetrics[kSentryProfilerSerializationKeyFrozenFrameRenders] =
            @ { @"unit" : @"nanosecond", @"values" : frozenFrames };
    }

    if (slowFrames.count > 0 || frozenFrames.count > 0) {
        const auto frameRates = sentry_sliceTraceProfileGPUData(gpuData.frameRateTimestamps,
            startSystemTime, endSystemTime,
            /*useMostRecentFrameRate */ YES);
        if (frameRates.count > 0) {
            mutableMetrics[kSentryProfilerSerializationKeyFrameRates] =
                @ { @"unit" : @"hz", @"values" : frameRates };
        }
    }
    metrics = mutableMetrics;
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

NSMutableDictionary<NSString *, id> *
sentry_serializedContinuousProfileChunk(SentryId *profileID, SentryId *chunkID,
    NSDictionary<NSString *, id> *profileData, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    NSMutableArray<SentrySample *> *const samples = profileData[@"profile"][@"samples"];
    // !!!: assumption: in trace profiling, we would avoid sending a payload with less than 2
    // samples. now, we may have previously sent a chunk with many samples, and then this chunk may
    // be the last of the continuous profiling session and it only has 1 sample. assuming we'll want
    // to keep that sample. let the backend decide, or, keep track of some statistics of the
    // profiling session, to count the number of total samples sent so far, to decide whether or not
    // a 1-sample chunk is acceptable.

    const auto payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = _sentry_serializedContinuousProfileSamples(samples);

    payload[@"profile"] = profile;

    payload[@"version"] = @"2";
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    for (SentryDebugMeta *debugImage in debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        payload[@"debug_meta"] = @ { @"images" : debugImages };
    }

    payload[@"chunk_id"] = [chunkID sentryIdString];
    payload[@"profiler_id"] = profileID.sentryIdString;
    payload[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment;
    payload[@"release"] = hub.getClient.options.releaseName;
    payload[@"platform"] = SentryPlatformName;

    // add the gathered metrics
    auto metrics = serializedMetrics;

#    if SENTRY_HAS_UIKIT
    const auto mutableMetrics =
        [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
    if (gpuData.slowFrameTimestamps.count > 0) {
        const auto values = [NSMutableDictionary dictionary];
        values[@"unit"] = @"nanosecond";
        values[@"values"] = gpuData.slowFrameTimestamps;
        mutableMetrics[kSentryProfilerSerializationKeySlowFrameRenders] = values;
    }

    if (gpuData.frozenFrameTimestamps.count > 0) {
        const auto values = [NSMutableDictionary dictionary];
        values[@"unit"] = @"nanosecond";
        values[@"values"] = gpuData.frozenFrameTimestamps;
        mutableMetrics[kSentryProfilerSerializationKeyFrozenFrameRenders] = values;
    }

    if (gpuData.slowFrameTimestamps.count > 0 || gpuData.frozenFrameTimestamps.count > 0) {
        if (gpuData.frameRateTimestamps.count > 0) {
            const auto values = [NSMutableDictionary dictionary];
            values[@"unit"] = @"hz";
            values[@"values"] = gpuData.frameRateTimestamps;
            mutableMetrics[kSentryProfilerSerializationKeyFrameRates] = values;
        }
    }
    metrics = mutableMetrics;
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

#    pragma mark - Public

SentryEnvelope *_Nullable sentry_continuousProfileChunkEnvelope(
    SentryId *profileID, NSDictionary *profileState, NSDictionary *metricProfilerState
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    const auto chunkID = [[SentryId alloc] init];
    const auto payload = sentry_serializedContinuousProfileChunk(
        profileID, chunkID, profileState, metricProfilerState,
        [SentryDependencyContainer.sharedInstance.debugImageProvider getDebugImagesCrashed:NO],
        SentrySDK.currentHub
#    if SENTRY_HAS_UIKIT
        ,
        gpuData
#    endif // SENTRY_HAS_UIKIT
    );

    if (payload == nil) {
        SENTRY_LOG_DEBUG(@"Payload was empty, will not create a profiling envelope item.");
        return nil;
    }

    const auto JSONData = [SentrySerialization dataWithJSONObject:payload];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

#    if defined(TEST) || defined(TESTCI)
    // only write profile payloads to disk for UI tests
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] != nil) {
        sentry_writeProfileFile(JSONData);
    }
#    endif // defined(TEST) || defined(TESTCI)

    const auto header =
        [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfileChunk
                                                length:JSONData.length];
    const auto envelopeItem = [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];

    return [[SentryEnvelope alloc] initWithId:chunkID singleItem:envelopeItem];
}

SentryEnvelopeItem *_Nullable sentry_traceProfileEnvelopeItem(
    SentryTransaction *transaction, NSDate *startTimestamp)
{
    SENTRY_LOG_DEBUG(@"Creating profiling envelope item");
    const auto profiler = sentry_profilerForFinishedTracer(transaction.trace.internalID);
    if (!profiler) {
        return nil;
    }

    const auto payload = sentry_serializedTraceProfileData(
        [profiler.state copyProfilingData], transaction.startSystemTime, transaction.endSystemTime,
        sentry_profilerTruncationReasonName(profiler.truncationReason),
        [profiler.metricProfiler serializeTraceProfileMetricsBetween:transaction.startSystemTime
                                                                 and:transaction.endSystemTime],
        [SentryDependencyContainer.sharedInstance.debugImageProvider getDebugImagesCrashed:NO],
        transaction.trace.hub
#    if SENTRY_HAS_UIKIT
        ,
        profiler.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );

    if (payload == nil) {
        SENTRY_LOG_DEBUG(@"Payload was empty, will not create a profiling envelope item.");
        return nil;
    }

    payload[@"platform"] = SentryPlatformName;
    payload[@"transaction"] = @ {
        @"id" : transaction.eventId.sentryIdString,
        @"trace_id" : transaction.trace.traceId.sentryIdString,
        @"name" : transaction.transaction,
        @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
    };
    payload[@"timestamp"] = sentry_toIso8601String(startTimestamp);

    const auto JSONData = [SentrySerialization dataWithJSONObject:payload];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

#    if defined(TEST) || defined(TESTCI)
    sentry_writeProfileFile(JSONData);
#    endif // defined(TEST) || defined(TESTCI)

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    return [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
}

NSMutableDictionary<NSString *, id> *_Nullable sentry_collectProfileDataHybridSDK(
    uint64_t startSystemTime, uint64_t endSystemTime, SentryId *traceId, SentryHub *hub)
{
    const auto profiler = sentry_profilerForFinishedTracer(traceId);
    if (!profiler) {
        return nil;
    }

    return sentry_serializedTraceProfileData([profiler.state copyProfilingData], startSystemTime,
        endSystemTime, sentry_profilerTruncationReasonName(profiler.truncationReason),
        [profiler.metricProfiler serializeTraceProfileMetricsBetween:startSystemTime
                                                                 and:endSystemTime],
        [SentryDependencyContainer.sharedInstance.debugImageProvider getDebugImagesCrashed:NO], hub
#    if SENTRY_HAS_UIKIT
        ,
        profiler.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
