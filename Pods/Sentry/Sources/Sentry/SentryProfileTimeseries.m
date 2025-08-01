#import "SentryProfileTimeseries.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryEvent+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentrySample.h"
#    import "SentryTransaction.h"
#    if SENTRY_HAS_UIKIT
#        import "SentryFormatter.h"
#        import "SentryTime.h"
#    endif // SENTRY_HAS_UIKIT
#    import "SentrySwift.h"

/**
 * Print a debug log to help diagnose slicing errors.
 * @param start @c YES if this is an attempt to find the start of the sliced data based on the
 * transaction start; @c NO if it's trying to find the end of the sliced data based on the
 * transaction's end, to accurately describe what's happening in the log statement.
 */
void
_sentry_logSlicingFailureWithArray(
    NSArray<SentrySample *> *array, uint64_t startSystemTime, uint64_t endSystemTime, BOOL start)
{
    if (!SENTRY_CASSERT_RETURN(
            array.count > 0, @"Should not have attempted to slice an empty array.")) {
        return;
    }

    if (![SentrySDKLog willLogAtLevel:kSentryLevelDebug]) {
        return;
    }

    uint64_t firstSampleAbsoluteTime = array.firstObject.absoluteTimestamp;
    uint64_t lastSampleAbsoluteTime = array.lastObject.absoluteTimestamp;
    uint64_t firstSampleRelativeToTransactionStart = firstSampleAbsoluteTime - startSystemTime;
    uint64_t lastSampleRelativeToTransactionStart = lastSampleAbsoluteTime - startSystemTime;
    SENTRY_LOG_DEBUG(@"[slice %@] Could not find any%@ sample taken during the transaction "
                     @"(first sample taken at: %llu; last: %llu; transaction start: %llu; end: "
                     @"%llu; first sample relative to transaction start: %lld; last: %lld).",
        start ? @"start" : @"end", start ? @"" : @" other", firstSampleAbsoluteTime,
        lastSampleAbsoluteTime, startSystemTime, endSystemTime,
        firstSampleRelativeToTransactionStart, lastSampleRelativeToTransactionStart);
}

NSArray<SentrySample *> *_Nullable sentry_slicedProfileSamples(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime, uint64_t endSystemTime)
{
    if (samples.count == 0) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Finding relevant samples from %lu total.", (unsigned long)samples.count);

    NSUInteger firstIndex = [samples indexOfObjectPassingTest:^BOOL(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        *stop = sample.absoluteTimestamp >= startSystemTime;
        return *stop;
    }];

    if (firstIndex == NSNotFound) {
        _sentry_logSlicingFailureWithArray(samples, startSystemTime, endSystemTime, /*start*/ YES);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found first slice sample at index %lu", firstIndex);
    }

    NSUInteger lastIndex =
        [samples indexOfObjectWithOptions:NSEnumerationReverse
                              passingTest:^BOOL(SentrySample *_Nonnull sample, NSUInteger idx,
                                  BOOL *_Nonnull stop) {
                                  *stop = sample.absoluteTimestamp <= endSystemTime;
                                  return *stop;
                              }];

    if (lastIndex == NSNotFound) {
        _sentry_logSlicingFailureWithArray(samples, startSystemTime, endSystemTime, /*start*/ NO);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found last slice sample at index %lu", lastIndex);
    }

    NSRange range = NSMakeRange(firstIndex, (lastIndex - firstIndex) + 1);
    NSIndexSet *indices = [NSIndexSet indexSetWithIndexesInRange:range];
    return [samples objectsAtIndexes:indices];
}

#    if SENTRY_HAS_UIKIT
NSArray<SentrySerializedMetricEntry *> *
sentry_sliceTraceProfileGPUData(SentryFrameInfoTimeSeries *frameInfo, uint64_t startSystemTime,
    uint64_t endSystemTime, BOOL useMostRecentRecording)
{
    NSMutableArray<SentrySerializedMetricEntry *> *slicedGPUEntries =
        [NSMutableArray<SentrySerializedMetricEntry *> array];
    __block NSNumber *nearestPredecessorValue;
    [frameInfo enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        unsigned long long timestamp = obj[@"timestamp"].unsignedLongLongValue;

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
        uint64_t relativeTimestamp = getDurationNs(startSystemTime, timestamp);

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

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
