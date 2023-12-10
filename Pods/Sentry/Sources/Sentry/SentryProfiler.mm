#import "SentryProfiler+Test.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "NSDate+SentryExtras.h"
#    import "SentryBacktrace.hpp"
#    import "SentryClient+Private.h"
#    import "SentryCurrentDate.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryEvent+Private.h"
#    import "SentryFramesTracker.h"
#    import "SentryHexAddressFormatter.h"
#    import "SentryHub+Private.h"
#    import "SentryId.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryNSTimerWrapper.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentryScreenFrames.h"
#    import "SentrySerialization.h"
#    import "SentrySpanId.h"
#    import "SentrySystemWrapper.h"
#    import "SentryThread.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

#    import <cstdint>
#    import <memory>

#    if TARGET_OS_IOS
#        import <UIKit/UIKit.h>
#    endif

const int kSentryProfilerFrequencyHz = 101;
NSString *const kTestStringConst = @"test";
NSTimeInterval kSentryProfilerTimeoutInterval = 30;

NSString *const kSentryProfilerSerializationKeySlowFrameRenders = @"slow_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders = @"frozen_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrameRates = @"screen_frame_rates";

using namespace sentry::profiling;

NSString *
parseBacktraceSymbolsFunctionName(const char *symbol)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression
            regularExpressionWithPattern:@"\\d+\\s+\\S+\\s+0[xX][0-9a-fA-F]+\\s+(.+)\\s+\\+\\s+\\d+"
                                 options:0
                                   error:nil];
    });
    const auto symbolNSStr = [NSString stringWithUTF8String:symbol];
    const auto match = [regex firstMatchInString:symbolNSStr
                                         options:0
                                           range:NSMakeRange(0, [symbolNSStr length])];
    if (match == nil) {
        return symbolNSStr;
    }
    return [symbolNSStr substringWithRange:[match rangeAtIndex:1]];
}

void
processBacktrace(const Backtrace &backtrace,
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata,
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata,
    NSMutableArray<SentrySample *> *samples, NSMutableArray<NSMutableArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup,
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup)
{
    const auto threadID = [@(backtrace.threadMetadata.threadID) stringValue];

    NSString *queueAddress = nil;
    if (backtrace.queueMetadata.address != 0) {
        queueAddress = sentry_formatHexAddress(@(backtrace.queueMetadata.address));
    }
    NSMutableDictionary<NSString *, id> *metadata = threadMetadata[threadID];
    if (metadata == nil) {
        metadata = [NSMutableDictionary<NSString *, id> dictionary];
        threadMetadata[threadID] = metadata;
    }
    if (!backtrace.threadMetadata.name.empty() && metadata[@"name"] == nil) {
        metadata[@"name"] = [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
    }
    if (backtrace.threadMetadata.priority != -1 && metadata[@"priority"] == nil) {
        metadata[@"priority"] = @(backtrace.threadMetadata.priority);
    }
    if (queueAddress != nil && queueMetadata[queueAddress] == nil
        && backtrace.queueMetadata.label != nullptr) {
        queueMetadata[queueAddress] =
            @ { @"label" : [NSString stringWithUTF8String:backtrace.queueMetadata.label->c_str()] };
    }
#    if defined(DEBUG)
    const auto symbols
        = backtrace_symbols(reinterpret_cast<void *const *>(backtrace.addresses.data()),
            static_cast<int>(backtrace.addresses.size()));
#    endif

    const auto stack = [NSMutableArray<NSNumber *> array];
    for (std::vector<uintptr_t>::size_type backtraceAddressIdx = 0;
         backtraceAddressIdx < backtrace.addresses.size(); backtraceAddressIdx++) {
        const auto instructionAddress
            = sentry_formatHexAddress(@(backtrace.addresses[backtraceAddressIdx]));

        const auto frameIndex = frameIndexLookup[instructionAddress];
        if (frameIndex == nil) {
            const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
            frame[@"instruction_addr"] = instructionAddress;
#    if defined(DEBUG)
            frame[@"function"] = parseBacktraceSymbolsFunctionName(symbols[backtraceAddressIdx]);
#    endif
            [stack addObject:@(frames.count)];
            frameIndexLookup[instructionAddress] = @(frames.count);
            [frames addObject:frame];
        } else {
            [stack addObject:frameIndex];
        }
    }

    const auto sample = [[SentrySample alloc] init];
    sample.absoluteTimestamp = backtrace.absoluteTimestamp;
    sample.threadID = backtrace.threadMetadata.threadID;
    if (queueAddress != nil) {
        sample.queueAddress = queueAddress;
    }
    const auto stackKey = [stack componentsJoinedByString:@"|"];
    const auto stackIndex = stackIndexLookup[stackKey];
    if (stackIndex) {
        sample.stackIndex = stackIndex;
    } else {
        const auto nextStackIndex = @(stacks.count);
        sample.stackIndex = nextStackIndex;
        stackIndexLookup[stackKey] = nextStackIndex;
        [stacks addObject:stack];
    }

    [samples addObject:sample];
}

std::mutex _gProfilerLock;
SentryProfiler *_Nullable _gCurrentProfiler;
SentryNSProcessInfoWrapper *_gCurrentProcessInfoWrapper;
SentrySystemWrapper *_gCurrentSystemWrapper;
SentryNSTimerWrapper *_gCurrentTimerWrapper;
#    if SENTRY_HAS_UIKIT
SentryFramesTracker *_gCurrentFramesTracker;
#    endif // SENTRY_HAS_UIKIT

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

NSString *
serializedUnsigned64BitInteger(uint64_t value)
{
    return [NSString stringWithFormat:@"%llu", value];
}

#    if SENTRY_HAS_UIKIT
/**
 * Convert the data structure that records timestamps for GPU frame render info from
 * SentryFramesTracker to the structure expected for profiling metrics, and throw out any that
 * didn't occur within the profile time.
 */
NSArray<SentrySerializedMetricReading *> *
processFrameRenders(SentryFrameInfoTimeSeries *frameInfo, SentryTransaction *transaction)
{
    auto relativeFrameInfo = [NSMutableArray<SentrySerializedMetricEntry *> array];
    [frameInfo enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto frameRenderStart = obj[@"start_timestamp"].unsignedLongLongValue;

        if (!orderedChronologically(transaction.startSystemTime, frameRenderStart)) {
            SENTRY_LOG_DEBUG(@"GPU frame render started before profile start, will not report it.");
            return;
        }
        const auto frameRenderEnd = obj[@"end_timestamp"].unsignedLongLongValue;
        if (orderedChronologically(transaction.endSystemTime, frameRenderEnd)) {
            SENTRY_LOG_DEBUG(@"Frame render finished after transaction finished, won't record.");
            return;
        }
        const auto relativeFrameRenderStart
            = getDurationNs(transaction.startSystemTime, frameRenderStart);
        const auto relativeFrameRenderEnd
            = getDurationNs(transaction.startSystemTime, frameRenderEnd);

        // this probably won't happen, but doesn't hurt to have one last defensive check before
        // calling getDurationNs
        if (!orderedChronologically(relativeFrameRenderStart, relativeFrameRenderEnd)) {
            SENTRY_LOG_WARN(
                @"Computed relative start and end timestamps are not chronologically ordered.");
            return;
        }
        const auto frameRenderDurationNs
            = getDurationNs(relativeFrameRenderStart, relativeFrameRenderEnd);

        [relativeFrameInfo addObject:@{
            @"elapsed_since_start_ns" : serializedUnsigned64BitInteger(relativeFrameRenderStart),
            @"value" : @(frameRenderDurationNs),
        }];
    }];
    return relativeFrameInfo;
}

/**
 * Convert the data structure that records timestamps for GPU frame rate info from
 * SentryFramesTracker to the structure expected for profiling metrics.
 */
NSArray<NSDictionary *> *
processFrameRates(SentryFrameInfoTimeSeries *frameRates, SentryTransaction *transaction)
{
    auto relativeFrameRates = [NSMutableArray array];
    [frameRates enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto timestamp = obj[@"timestamp"].unsignedLongLongValue;
        const auto refreshRate = obj[@"frame_rate"];

        if (!orderedChronologically(transaction.startSystemTime, timestamp)) {
            return;
        }
        if (orderedChronologically(transaction.endSystemTime, timestamp)) {
            return;
        }

        const auto relativeTimestamp = getDurationNs(transaction.startSystemTime, timestamp);

        [relativeFrameRates addObject:@ {
            @"elapsed_since_start_ns" : serializedUnsigned64BitInteger(relativeTimestamp),
            @"value" : refreshRate,
        }];
    }];
    return relativeFrameRates;
}
#    endif // SENTRY_HAS_UIKIT

/** Given an array of samples with absolute timestamps, return the serialized JSON mapping with
 * their data, with timestamps normalized relative to the provided transaction's start time. */
NSArray<NSDictionary *> *
serializedSamplesWithRelativeTimestamps(
    NSArray<SentrySample *> *samples, SentryTransaction *transaction)
{
    const auto result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        // This shouldn't happen as we would've filtered out any such samples, but we should still
        // guard against it before calling getDurationNs as a defensive measure
        if (!orderedChronologically(transaction.startSystemTime, sample.absoluteTimestamp)) {
            SENTRY_LOG_WARN(@"Filtered sample not chronological with transaction.");
            return;
        }
        const auto dict = [NSMutableDictionary dictionaryWithDictionary:@ {
            @"elapsed_since_start_ns" : serializedUnsigned64BitInteger(
                getDurationNs(transaction.startSystemTime, sample.absoluteTimestamp)),
            @"thread_id" : serializedUnsigned64BitInteger(sample.threadID),
            @"stack_id" : sample.stackIndex,
        }];
        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }

        [result addObject:dict];
    }];
    return result;
}

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profileData;
    uint64_t _startTimestamp;
    NSDate *_startDate;
    NSDate *_endDate;
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryMetricProfiler *_metricProfiler;
    SentryDebugImageProvider *_debugImageProvider;
    thread::TIDType _mainThreadID;

    SentryProfilerTruncationReason _truncationReason;
    NSTimer *_timeoutTimer;
    SentryHub *__weak _hub;
}

- (instancetype)initWithHub:(SentryHub *)hub
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
    _hub = hub;
    _mainThreadID = ThreadHandle::current()->tid();
    return self;
}

#    pragma mark - Public

+ (void)startWithHub:(SentryHub *)hub
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler && [_gCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"A profiler is already running.");
        return;
    }

    _gCurrentProfiler = [[SentryProfiler alloc] initWithHub:hub];
    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
        return;
    }

#    if SENTRY_HAS_UIKIT
    [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT

    [_gCurrentProfiler start];

    _gCurrentProfiler->_timeoutTimer =
        [NSTimer scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
                                         target:self
                                       selector:@selector(timeoutAbort)
                                       userInfo:nil
                                        repeats:NO];
#    if SENTRY_HAS_UIKIT
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundAbort)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
#    endif // SENTRY_HAS_UIKIT
}

+ (void)stop
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    [self stopProfilerForReason:SentryProfilerTruncationReasonNormal];
}

+ (BOOL)isRunning
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
}

+ (SentryEnvelopeItem *)createProfilingEnvelopeItemForTransaction:(SentryTransaction *)transaction
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler from which to receive data.");
        return nil;
    }

    const auto payload = [NSMutableDictionary<NSString *, id> dictionary];

    NSArray<SentrySample *> *samples = _gCurrentProfiler->_profileData[@"profile"][@"samples"];

    // We need at least two samples to be able to draw a stack frame for any given function: one
    // sample for the start of the frame and another for the end. Otherwise we would only have a
    // stack frame with 0 duration, which wouldn't make sense.
    if ([samples count] < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile");
        return nil;
    }

    // slice the profile data to only include the samples/metrics within the transaction
    const auto slicedSamples = [self slicedSamples:samples transaction:transaction];
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
        return nil;
    }

    payload[@"profile"] = @{
        @"samples" : serializedSamplesWithRelativeTimestamps(slicedSamples, transaction),
        @"stacks" : _gCurrentProfiler->_profileData[@"profile"][@"stacks"],
        @"frames" : _gCurrentProfiler->_profileData[@"profile"][@"frames"],
        @"thread_metadata" : _gCurrentProfiler->_profileData[@"profile"][@"thread_metadata"],
        @"queue_metadata" : _gCurrentProfiler->_profileData[@"profile"][@"queue_metadata"],
    };

    // add the serialized info for the associated transaction
    const auto firstSampleTimestamp = slicedSamples.firstObject.absoluteTimestamp;
    const auto profileDuration = getDurationNs(firstSampleTimestamp, getAbsoluteTime());

    const auto transactionInfo = [self serializeInfoForTransaction:transaction
                                                   profileDuration:profileDuration];
    if (!transactionInfo) {
        SENTRY_LOG_WARN(@"Could not find any associated transaction for the profile.");
        return nil;
    }
    payload[@"transactions"] = @[ transactionInfo ];

    // add the gathered metrics
    const auto metrics = [_gCurrentProfiler->_metricProfiler serializeForTransaction:transaction];

#    if SENTRY_HAS_UIKIT
    const auto slowFrames = processFrameRenders(
        _gCurrentFramesTracker.currentFrames.slowFrameTimestamps, transaction);
    if (slowFrames.count > 0) {
        metrics[@"slow_frame_renders"] = @{ @"unit" : @"nanosecond", @"values" : slowFrames };
    }

    const auto frozenFrames = processFrameRenders(
        _gCurrentFramesTracker.currentFrames.frozenFrameTimestamps, transaction);
    if (frozenFrames.count > 0) {
        metrics[@"frozen_frame_renders"] = @{ @"unit" : @"nanosecond", @"values" : frozenFrames };
    }

    const auto frameRates
        = processFrameRates(_gCurrentFramesTracker.currentFrames.frameRateTimestamps, transaction);
    if (frameRates.count > 0) {
        metrics[@"screen_frame_rates"] = @{ @"unit" : @"hz", @"values" : frameRates };
    }
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    // add the remaining basic metadata for the profile
    const auto profileID = [[SentryId alloc] init];
    [self serializeBasicProfileInfo:payload
                    profileDuration:profileDuration
                          profileID:profileID
                           platform:transaction.platform];

    return [self envelopeItemForProfileData:payload profileID:profileID];
}

#    pragma mark - Testing

+ (void)useSystemWrapper:(SentrySystemWrapper *)systemWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentSystemWrapper = systemWrapper;
}

+ (void)useProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentProcessInfoWrapper = processInfoWrapper;
}

+ (void)useTimerWrapper:(SentryNSTimerWrapper *)timerWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentTimerWrapper = timerWrapper;
}

#    if SENTRY_HAS_UIKIT
+ (void)useFramesTracker:(SentryFramesTracker *)framesTracker
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentFramesTracker = framesTracker;
}
#    endif // SENTRY_HAS_UIKIT

#    pragma mark - Private

+ (nullable NSArray<SentrySample *> *)slicedSamples:(NSArray<SentrySample *> *)samples
                                        transaction:(SentryTransaction *)transaction
{
    if (samples.count == 0) {
        return nil;
    }

    const auto firstIndex = [samples indexOfObjectPassingTest:^BOOL(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        *stop = sample.absoluteTimestamp >= transaction.startSystemTime;
        return *stop;
    }];

    if (firstIndex == NSNotFound) {
        [self logSlicingFailureWithArray:samples transaction:transaction start:YES];
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found first slice sample at index %lu", firstIndex);
    }

    const auto lastIndex =
        [samples indexOfObjectWithOptions:NSEnumerationReverse
                              passingTest:^BOOL(SentrySample *_Nonnull sample, NSUInteger idx,
                                  BOOL *_Nonnull stop) {
                                  *stop = sample.absoluteTimestamp <= transaction.endSystemTime;
                                  return *stop;
                              }];

    if (lastIndex == NSNotFound) {
        [self logSlicingFailureWithArray:samples transaction:transaction start:NO];
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found last slice sample at index %lu", lastIndex);
    }

    const auto range = NSMakeRange(firstIndex, (lastIndex - firstIndex) + 1);
    const auto indices = [NSIndexSet indexSetWithIndexesInRange:range];
    return [samples objectsAtIndexes:indices];
}

/**
 * Print a debug log to help diagnose slicing errors.
 * @param start @c YES if this is an attempt to find the start of the sliced data based on the
 * transaction start; @c NO if it's trying to find the end of the sliced data based on the
 * transaction's end, to accurately describe what's happening in the log statement.
 */
+ (void)logSlicingFailureWithArray:(NSArray<SentrySample *> *)array
                       transaction:(SentryTransaction *)transaction
                             start:(BOOL)start
{
    if (!SENTRY_ASSERT(array.count > 0, @"Should not have attempted to slice an empty array.")) {
        return;
    }

    if (![SentryLog willLogAtLevel:kSentryLevelDebug]) {
        return;
    }

    const auto firstSampleAbsoluteTime = array.firstObject.absoluteTimestamp;
    const auto lastSampleAbsoluteTime = array.lastObject.absoluteTimestamp;
    const auto firstSampleRelativeToTransactionStart
        = firstSampleAbsoluteTime - transaction.startSystemTime;
    const auto lastSampleRelativeToTransactionStart
        = lastSampleAbsoluteTime - transaction.startSystemTime;
    SENTRY_LOG_DEBUG(@"[slice %@] Could not find any%@ sample taken during the transaction "
                     @"(first sample taken at: %llu; last: %llu; transaction start: %llu; end: "
                     @"%llu; first sample relative to transaction start: %lld; last: %lld).",
        start ? @"start" : @"end", start ? @"" : @" other", firstSampleAbsoluteTime,
        lastSampleAbsoluteTime, transaction.startSystemTime, transaction.endSystemTime,
        firstSampleRelativeToTransactionStart, lastSampleRelativeToTransactionStart);
}

+ (void)timeoutAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonTimeout];
}

+ (void)backgroundAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

+ (void)stopProfilerForReason:(SentryProfilerTruncationReason)reason
{
    [_gCurrentProfiler->_timeoutTimer invalidate];
    [_gCurrentProfiler stop];
    _gCurrentProfiler->_truncationReason = reason;
#    if SENTRY_HAS_UIKIT
    [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
}

- (void)startMetricProfiler
{
    if (_gCurrentSystemWrapper == nil) {
        _gCurrentSystemWrapper = [[SentrySystemWrapper alloc] init];
    }
    if (_gCurrentProcessInfoWrapper == nil) {
        _gCurrentProcessInfoWrapper = [[SentryNSProcessInfoWrapper alloc] init];
    }
    if (_gCurrentTimerWrapper == nil) {
        _gCurrentTimerWrapper = [[SentryNSTimerWrapper alloc] init];
    }
    _metricProfiler =
        [[SentryMetricProfiler alloc] initWithProcessInfoWrapper:_gCurrentProcessInfoWrapper
                                                   systemWrapper:_gCurrentSystemWrapper
                                                    timerWrapper:_gCurrentTimerWrapper];
    [_metricProfiler start];
}

- (void)start
{
// Disable profiling when running with TSAN because it produces a TSAN false
// positive, similar to the situation described here:
// https://github.com/envoyproxy/envoy/issues/2561
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
    return;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

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

    _profileData = [NSMutableDictionary<NSString *, id> dictionary];
    const auto sampledProfile = [NSMutableDictionary<NSString *, id> dictionary];

    /*
     * Maintain an index of unique frames to avoid duplicating large amounts of data. Every
     * unique frame is stored in an array, and every time a stack trace is captured for a
     * sample, the stack is stored as an array of integers indexing into the array of frames.
     * Stacks are thusly also stored as unique elements in their own index, an array of arrays
     * of frame indices, and each sample references a stack by index, to deduplicate common
     * stacks between samples, such as when the same deep function call runs across multiple
     * samples.
     *
     * E.g. if we have the following samples in the following function call stacks:
     *
     *              v sample1    v sample2               v sample3    v sample4
     * |-foo--------|------------|-----|    |-abc--------|------------|-----|
     *    |-bar-----|------------|--|          |-def-----|------------|--|
     *      |-baz---|------------|-|             |-ghi---|------------|-|
     *
     * Then we'd wind up with the following structures:
     *
     * frames: [
     *   { function: foo, instruction_addr: ... },
     *   { function: bar, instruction_addr: ... },
     *   { function: baz, instruction_addr: ... },
     *   { function: abc, instruction_addr: ... },
     *   { function: def, instruction_addr: ... },
     *   { function: ghi, instruction_addr: ... }
     * ]
     * stacks: [ [0, 1, 2], [3, 4, 5] ]
     * samples: [
     *   { stack_id: 0, ... },
     *   { stack_id: 0, ... },
     *   { stack_id: 1, ... },
     *   { stack_id: 1, ... }
     * ]
     */
    const auto samples = [NSMutableArray<SentrySample *> array];
    const auto stacks = [NSMutableArray<NSMutableArray<NSNumber *> *> array];
    const auto frames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
    const auto frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    const auto stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    sampledProfile[@"samples"] = samples;
    sampledProfile[@"stacks"] = stacks;
    sampledProfile[@"frames"] = frames;

    const auto threadMetadata = [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
    const auto queueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    sampledProfile[@"thread_metadata"] = threadMetadata;
    sampledProfile[@"queue_metadata"] = queueMetadata;
    _profileData[@"profile"] = sampledProfile;
    _startTimestamp = getAbsoluteTime();
    _startDate = [SentryCurrentDate date];

    __weak const auto weakSelf = self;
    _profiler = std::make_shared<SamplingProfiler>(
        [weakSelf, threadMetadata, queueMetadata, samples, mainThreadID = _mainThreadID, frames,
            frameIndexLookup, stacks, stackIndexLookup](auto &backtrace) {
            const auto strongSelf = weakSelf;
            if (strongSelf == nil) {
                SENTRY_LOG_WARN(@"Profiler instance no longer exists, cannot process next sample.");
                return;
            }
            processBacktrace(backtrace, threadMetadata, queueMetadata, samples, stacks, frames,
                frameIndexLookup, stackIndexLookup);
        },
        kSentryProfilerFrequencyHz);
    _profiler->startSampling();

    [self startMetricProfiler];
}

- (void)stop
{
    if (_profiler == nullptr) {
        SENTRY_LOG_WARN(@"No profiler instance found.");
        return;
    }
    if (!_profiler->isSampling()) {
        SENTRY_LOG_WARN(@"Profiler is not currently sampling.");
        return;
    }

    _profiler->stopSampling();
    [_metricProfiler stop];
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);
}

+ (void)serializeBasicProfileInfo:(NSMutableDictionary<NSString *, id> *)profile
                  profileDuration:(const unsigned long long &)profileDuration
                        profileID:(SentryId *const &)profileID
                         platform:(NSString *)platform
{
    profile[@"version"] = @"1";
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    const auto debugMeta = [_gCurrentProfiler->_debugImageProvider getDebugImages];
    for (SentryDebugMeta *debugImage in debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        profile[@"debug_meta"] = @{ @"images" : debugImages };
    }

    profile[@"os"] = @{
        @"name" : sentry_getOSName(),
        @"version" : sentry_getOSVersion(),
        @"build_number" : sentry_getOSBuildNumber()
    };

    const auto isEmulated = sentry_isSimulatorBuild();
    profile[@"device"] = @{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"locale" : NSLocale.currentLocale.localeIdentifier,
        @"manufacturer" : @"Apple",
        @"model" : isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel()
    };

    profile[@"profile_id"] = profileID.sentryIdString;
    profile[@"duration_ns"] = [@(profileDuration) stringValue];
    profile[@"truncation_reason"]
        = profilerTruncationReasonName(_gCurrentProfiler->_truncationReason);
    profile[@"platform"] = platform;
    profile[@"environment"] = _gCurrentProfiler->_hub.scope.environmentString
        ?: _gCurrentProfiler->_hub.getClient.options.environment;
    profile[@"timestamp"] = [[SentryCurrentDate date] sentry_toIso8601String];
    profile[@"release"] = _gCurrentProfiler->_hub.getClient.options.releaseName;
}

/** @return serialize info corresponding to the specified transaction. */
+ (NSDictionary *)serializeInfoForTransaction:(SentryTransaction *)transaction
                              profileDuration:(uint64_t)profileDuration
{

    SENTRY_LOG_DEBUG(@"Profile start timestamp: %@ absolute time: %llu",
        _gCurrentProfiler->_startDate, (unsigned long long)_gCurrentProfiler->_startTimestamp);

    const auto relativeStart = [NSString
        stringWithFormat:@"%llu",
        [transaction.startTimestamp compare:_gCurrentProfiler->_startDate] == NSOrderedAscending
            ? 0
            : timeIntervalToNanoseconds(
                [transaction.startTimestamp timeIntervalSinceDate:_gCurrentProfiler->_startDate])];

    NSString *relativeEnd;
    if ([transaction.timestamp compare:_gCurrentProfiler->_endDate] == NSOrderedDescending) {
        relativeEnd = serializedUnsigned64BitInteger(profileDuration);
    } else {
        const auto profileStartToTransactionEnd_ns = timeIntervalToNanoseconds(
            [transaction.timestamp timeIntervalSinceDate:_gCurrentProfiler->_startDate]);
        if (profileStartToTransactionEnd_ns < 0) {
            SENTRY_LOG_DEBUG(@"Transaction %@ ended before the profiler started, won't "
                             @"associate it with this profile.",
                transaction.trace.traceId.sentryIdString);
            return nil;
        } else {
            relativeEnd = [NSString
                stringWithFormat:@"%llu", (unsigned long long)profileStartToTransactionEnd_ns];
        }
    }
    return @{
        @"id" : transaction.eventId.sentryIdString,
        @"trace_id" : transaction.trace.traceId.sentryIdString,
        @"name" : transaction.transaction,
        @"relative_start_ns" : relativeStart,
        @"relative_end_ns" : relativeEnd,
        @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
    };
}

+ (SentryEnvelopeItem *)envelopeItemForProfileData:(NSMutableDictionary<NSString *, id> *)profile
                                         profileID:(SentryId *)profileID
{
    NSError *error = nil;
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile error:&error];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON: %@", error);
        return nil;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    return [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
}

- (BOOL)isRunning
{
    if (_profiler == nullptr) {
        return NO;
    }
    return _profiler->isSampling();
}

@end

#endif
