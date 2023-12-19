#import "SentryProfileTimeseries.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryEvent+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentrySample.h"
#    import "SentryTransaction.h"

/**
 * Print a debug log to help diagnose slicing errors.
 * @param start @c YES if this is an attempt to find the start of the sliced data based on the
 * transaction start; @c NO if it's trying to find the end of the sliced data based on the
 * transaction's end, to accurately describe what's happening in the log statement.
 */
void
logSlicingFailureWithArray(
    NSArray<SentrySample *> *array, uint64_t startSystemTime, uint64_t endSystemTime, BOOL start)
{
    if (!SENTRY_CASSERT_RETURN(
            array.count > 0, @"Should not have attempted to slice an empty array.")) {
        return;
    }

    if (![SentryLog willLogAtLevel:kSentryLevelDebug]) {
        return;
    }

    const auto firstSampleAbsoluteTime = array.firstObject.absoluteTimestamp;
    const auto lastSampleAbsoluteTime = array.lastObject.absoluteTimestamp;
    const auto firstSampleRelativeToTransactionStart = firstSampleAbsoluteTime - startSystemTime;
    const auto lastSampleRelativeToTransactionStart = lastSampleAbsoluteTime - startSystemTime;
    SENTRY_LOG_DEBUG(@"[slice %@] Could not find any%@ sample taken during the transaction "
                     @"(first sample taken at: %llu; last: %llu; transaction start: %llu; end: "
                     @"%llu; first sample relative to transaction start: %lld; last: %lld).",
        start ? @"start" : @"end", start ? @"" : @" other", firstSampleAbsoluteTime,
        lastSampleAbsoluteTime, startSystemTime, endSystemTime,
        firstSampleRelativeToTransactionStart, lastSampleRelativeToTransactionStart);
}

NSArray<SentrySample *> *_Nullable slicedProfileSamples(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime, uint64_t endSystemTime)
{
    if (samples.count == 0) {
        return nil;
    }

    const auto firstIndex =
        [samples indexOfObjectWithOptions:NSEnumerationConcurrent
                              passingTest:^BOOL(SentrySample *_Nonnull sample, NSUInteger idx,
                                  BOOL *_Nonnull stop) {
                                  *stop = sample.absoluteTimestamp >= startSystemTime;
                                  return *stop;
                              }];

    if (firstIndex == NSNotFound) {
        logSlicingFailureWithArray(samples, startSystemTime, endSystemTime, /*start*/ YES);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found first slice sample at index %lu", firstIndex);
    }

    const auto lastIndex =
        [samples indexOfObjectWithOptions:NSEnumerationConcurrent | NSEnumerationReverse
                              passingTest:^BOOL(SentrySample *_Nonnull sample, NSUInteger idx,
                                  BOOL *_Nonnull stop) {
                                  *stop = sample.absoluteTimestamp <= endSystemTime;
                                  return *stop;
                              }];

    if (lastIndex == NSNotFound) {
        logSlicingFailureWithArray(samples, startSystemTime, endSystemTime, /*start*/ NO);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found last slice sample at index %lu", lastIndex);
    }

    const auto range = NSMakeRange(firstIndex, (lastIndex - firstIndex) + 1);
    const auto indices = [NSIndexSet indexSetWithIndexesInRange:range];
    return [samples objectsAtIndexes:indices];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
