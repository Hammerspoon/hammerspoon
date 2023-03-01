#import "SentryProfiler.h"

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
    NSMutableArray<NSDictionary<NSString *, id> *> *samples,
    NSMutableArray<NSMutableArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup, uint64_t startTimestamp,
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

    const auto sample = [NSMutableDictionary<NSString *, id> dictionary];
    sample[@"elapsed_since_start_ns"] =
        [@(getDurationNs(startTimestamp, backtrace.absoluteTimestamp)) stringValue];
    sample[@"thread_id"] = threadID;
    if (queueAddress != nil) {
        sample[@"queue_address"] = queueAddress;
    }

    const auto stackKey = [stack componentsJoinedByString:@"|"];
    const auto stackIndex = stackIndexLookup[stackKey];
    if (stackIndex) {
        sample[@"stack_id"] = stackIndex;
    } else {
        const auto nextStackIndex = @(stacks.count);
        sample[@"stack_id"] = nextStackIndex;
        stackIndexLookup[stackKey] = nextStackIndex;
        [stacks addObject:stack];
    }

    [samples addObject:sample];
}

std::mutex _gProfilerLock;
NSMutableDictionary<SentrySpanId *, SentryProfiler *> *_gProfilersPerSpanID;
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

#    if SENTRY_HAS_UIKIT
NSArray *
processFrameRenders(
    SentryFrameInfoTimeSeries *frameInfo, uint64_t profileStart, uint64_t profileDuration)
{
    auto relativeFrameInfo = [NSMutableArray array];
    [frameInfo enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto frameRenderStart
            = timeIntervalToNanoseconds(obj[@"start_timestamp"].doubleValue);

#        if defined(TEST) || defined(TESTCI)
        // we don't currently validate the timestamps in tests, and the mock doesn't provide
        // realistic ones, so they'd fail the checks below. just write them directly into the data
        // structure so we can count *how many* were recorded
        [relativeFrameInfo addObject:@{
            @"elapsed_since_start_ns" : @(frameRenderStart),
            @"value" : @(frameRenderStart),
        }];
        return;
#        else // if not testing, ie, development or production
        if (frameRenderStart < profileStart) {
            return;
        }
        const auto frameRenderEnd = timeIntervalToNanoseconds(obj[@"end_timestamp"].doubleValue);
        const auto frameRenderEndRelativeToProfileStart = getDurationNs(profileStart, frameRenderEnd);
        if (frameRenderEndRelativeToProfileStart > profileDuration) {
            SENTRY_LOG_DEBUG(@"The last slow/frozen frame extended past the end of the profile, "
                             @"will not report it.");
            return;
        }
        const auto frameRenderStartRelativeToProfileStartNs = getDurationNs(profileStart, frameRenderStart);
        const auto frameRenderDurationNs = frameRenderEndRelativeToProfileStart - frameRenderStartRelativeToProfileStartNs;
        [relativeFrameInfo addObject:@{
            @"elapsed_since_start_ns" : @(frameRenderStartRelativeToProfileStartNs),
            @"value" : @(frameRenderDurationNs),
        }];
#        endif // defined(TEST) || defined(TESTCI)
    }];
    return relativeFrameInfo;
}

NSArray<NSDictionary *> *
processFrameRates(SentryFrameInfoTimeSeries *frameRates, uint64_t start)
{
    if (frameRates.count == 0) {
        return nil;
    }
    auto relativeFrameRates = [NSMutableArray array];
    [frameRates enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto timestamp = (uint64_t)(obj[@"timestamp"].doubleValue * 1e9);
        const auto refreshRate = obj[@"frame_rate"];
        uint64_t relativeTimestamp = 0;
        if (timestamp >= start) {
            relativeTimestamp = getDurationNs(start, timestamp);
        }
        [relativeFrameRates addObject:@{
            @"elapsed_since_start_ns" : @(relativeTimestamp),
            @"value" : refreshRate,
        }];
    }];
    return relativeFrameRates;
}
#    endif // SENTRY_HAS_UIKIT

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profile;
    uint64_t _startTimestamp;
    NSDate *_startDate;
    uint64_t _endTimestamp;
    NSDate *_endDate;
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryMetricProfiler *_metricProfiler;
    SentryDebugImageProvider *_debugImageProvider;
    thread::TIDType _mainThreadID;

    NSMutableArray<SentrySpanId *> *_spansInFlight;
    NSMutableArray<SentryTransaction *> *_transactions;
    SentryProfilerTruncationReason _truncationReason;
    SentryScreenFrames *_frameInfo;
    NSTimer *_timeoutTimer;
    SentryHub *__weak _hub;
}

+ (void)initialize
{
    if (self == [SentryProfiler class]) {
        _gProfilersPerSpanID = [NSMutableDictionary<SentrySpanId *, SentryProfiler *> dictionary];
    }
}

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
    _mainThreadID = ThreadHandle::current()->tid();
    _spansInFlight = [NSMutableArray<SentrySpanId *> array];
    _transactions = [NSMutableArray<SentryTransaction *> array];
    return self;
}

#    pragma mark - Public

+ (void)startForSpanID:(SentrySpanId *)spanID hub:(SentryHub *)hub
{
    NSTimeInterval timeoutInterval = 30;
#    if defined(TEST) || defined(TESTCI)
    timeoutInterval = 1;
#    endif
    [self startForSpanID:spanID hub:hub timeoutInterval:timeoutInterval];
}

+ (void)startForSpanID:(SentrySpanId *)spanID
                   hub:(SentryHub *)hub
       timeoutInterval:(NSTimeInterval)timeoutInterval
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        _gCurrentProfiler = [[SentryProfiler alloc] init];
        if (_gCurrentProfiler == nil) {
            SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
            return;
        }
#    if SENTRY_HAS_UIKIT
        [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
        [_gCurrentProfiler start];
        _gCurrentProfiler->_timeoutTimer =
            [NSTimer scheduledTimerWithTimeInterval:timeoutInterval
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
        _gCurrentProfiler->_hub = hub;
    }

    SENTRY_LOG_DEBUG(
        @"Tracking span with ID %@ with profiler %@", spanID.sentrySpanIdString, _gCurrentProfiler);
    [_gCurrentProfiler->_spansInFlight addObject:spanID];
    _gProfilersPerSpanID[spanID] = _gCurrentProfiler;
}

+ (void)stopProfilingSpan:(id<SentrySpan>)span
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", span.spanId.sentrySpanIdString);
        return;
    }

    [_gCurrentProfiler->_spansInFlight removeObject:span.spanId];
    if (_gCurrentProfiler->_spansInFlight.count == 0) {
        SENTRY_LOG_DEBUG(@"Stopping profiler %@ because span with id %@ was last being profiled.",
            _gCurrentProfiler, span.spanId.sentrySpanIdString);
        [self stopProfilerForReason:SentryProfilerTruncationReasonNormal];
    }
}

+ (void)dropTransaction:(SentryTransaction *)transaction
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.spanId;
    const auto profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

    [self captureEnvelopeIfFinished:profiler spanID:spanID];
}

+ (void)linkTransaction:(SentryTransaction *)transaction
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.spanId;
    SentryProfiler *profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

    SENTRY_LOG_DEBUG(@"Found profiler waiting for span with ID %@: %@",
        transaction.trace.spanId.sentrySpanIdString, profiler);
    [profiler addTransaction:transaction];

    [self captureEnvelopeIfFinished:profiler spanID:spanID];
}

+ (BOOL)isRunning
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
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

+ (void)captureEnvelopeIfFinished:(SentryProfiler *)profiler spanID:(SentrySpanId *)spanID
{
    [_gProfilersPerSpanID removeObjectForKey:spanID];
    [profiler->_spansInFlight removeObject:spanID];
    if (profiler->_spansInFlight.count == 0) {
        [profiler captureEnvelope];
        [profiler->_transactions removeAllObjects];
        SENTRY_LOG_DEBUG(@"Span %@ was last being tracked.", spanID.sentrySpanIdString);
    } else {
        SENTRY_LOG_DEBUG(@"Profiler %@ is waiting for more spans to complete: %@.", profiler,
            profiler->_spansInFlight);
    }
}

+ (void)timeoutAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonTimeout];
}

+ (void)backgroundAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
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
    _gCurrentProfiler->_frameInfo = _gCurrentFramesTracker.currentFrames;
    [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
    _gCurrentProfiler = nil;
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
        [[SentryMetricProfiler alloc] initWithProfileStartTime:_startTimestamp
                                            processInfoWrapper:_gCurrentProcessInfoWrapper
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
#        endif
#    endif
    @synchronized(self) {
#    pragma clang diagnostic pop
        if (_profiler != nullptr) {
            _profiler->stopSampling();
        }
        _profile = [NSMutableDictionary<NSString *, id> dictionary];
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
        const auto samples = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        const auto stacks = [NSMutableArray<NSMutableArray<NSNumber *> *> array];
        const auto frames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        const auto frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        const auto stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        sampledProfile[@"samples"] = samples;
        sampledProfile[@"stacks"] = stacks;
        sampledProfile[@"frames"] = frames;

        const auto threadMetadata =
            [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
        const auto queueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        sampledProfile[@"thread_metadata"] = threadMetadata;
        sampledProfile[@"queue_metadata"] = queueMetadata;
        _profile[@"profile"] = sampledProfile;
        _startTimestamp = getAbsoluteTime();
        _startDate = [SentryCurrentDate date];

        SENTRY_LOG_DEBUG(@"Starting profiler %@ at system time %llu.", self, _startTimestamp);

        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>(
            [weakSelf, threadMetadata, queueMetadata, samples, mainThreadID = _mainThreadID, frames,
                frameIndexLookup, stacks, stackIndexLookup](auto &backtrace) {
                const auto strongSelf = weakSelf;
                if (strongSelf == nil) {
                    SENTRY_LOG_WARN(
                        @"Profiler instance no longer exists, cannot process next sample.");
                    return;
                }
                processBacktrace(backtrace, threadMetadata, queueMetadata, samples, stacks, frames,
                    frameIndexLookup, strongSelf->_startTimestamp, stackIndexLookup);
            },
            kSentryProfilerFrequencyHz);
        _profiler->startSampling();

        [self startMetricProfiler];
    }
}

- (void)addTransaction:(nonnull SentryTransaction *)transaction
{
    NSParameterAssert(transaction);
    if (transaction == nil) {
        SENTRY_LOG_WARN(@"Received nil transaction!");
        return;
    }

    SENTRY_LOG_DEBUG(@"Adding transaction %@ to list of profiled transactions for profiler %@.",
        transaction, self);
    if (_transactions == nil) {
        _transactions = [NSMutableArray<SentryTransaction *> array];
    }
    [_transactions addObject:transaction];
}

- (void)stop
{
    @synchronized(self) {
        if (_profiler == nullptr || !_profiler->isSampling()) {
            return;
        }

        _profiler->stopSampling();
        _endTimestamp = getAbsoluteTime();
        _endDate = [SentryCurrentDate date];
        [_metricProfiler stop];
        SENTRY_LOG_DEBUG(@"Stopped profiler %@ at system time: %llu.", self, _endTimestamp);
    }
}

- (void)captureEnvelope
{
    NSMutableDictionary<NSString *, id> *profile = nil;
    NSMutableDictionary<NSString *, id> *metrics;
    @synchronized(self) {
        profile = [_profile mutableCopy];
        metrics = [_metricProfiler serialize];
    }

    if ([((NSArray *)profile[@"profile"][@"samples"]) count] < 2) {
        SENTRY_LOG_DEBUG(@"No samples located in profile");
        return;
    }

    profile[@"version"] = @"1";
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    const auto debugMeta = [_debugImageProvider getDebugImages];
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

    const auto profileID = [[SentryId alloc] init];
    profile[@"profile_id"] = profileID.sentryIdString;
    const auto profileDuration = getDurationNs(_startTimestamp, _endTimestamp);
    profile[@"duration_ns"] = [@(profileDuration) stringValue];
    profile[@"truncation_reason"] = profilerTruncationReasonName(_truncationReason);
    profile[@"platform"] = _transactions.firstObject.platform;
    profile[@"environment"] = _hub.scope.environmentString ?: _hub.getClient.options.environment;
    profile[@"timestamp"] = [[SentryCurrentDate date] sentry_toIso8601String];
    profile[@"release"] = _hub.getClient.options.releaseName;

    profile[@"measurements"] = metrics;

#    if SENTRY_HAS_UIKIT
    const auto slowTimestamps
        = processFrameRenders(_frameInfo.slowFrameTimestamps, _startTimestamp, profileDuration);
    if (slowTimestamps.count > 0) {
        metrics[kSentryProfilerSerializationKeySlowFrameRenders] =
            @{ @"unit" : @"nanosecond", @"values" : slowTimestamps };
    }

    const auto frozenTimestamps
        = processFrameRenders(_frameInfo.frozenFrameTimestamps, _startTimestamp, profileDuration);
    if (frozenTimestamps.count > 0) {
        metrics[kSentryProfilerSerializationKeyFrozenFrameRenders] =
            @{ @"unit" : @"nanosecond", @"values" : frozenTimestamps };
    }

    const auto frameRates = processFrameRates(_frameInfo.frameRateTimestamps, _startTimestamp);
    if (frameRates.count > 0) {
        metrics[kSentryProfilerSerializationKeyFrameRates] =
            @{ @"unit" : @"hz", @"values" : frameRates };
    }
#    endif // SENTRY_HAS_UIKIT

    // populate info from all transactions that occurred while profiler was running
    auto transactionsInfo = [NSMutableArray array];
    SENTRY_LOG_DEBUG(@"Profile start timestamp: %@ absolute time: %llu", _startDate,
        (unsigned long long)_startTimestamp);
    SENTRY_LOG_DEBUG(@"Profile end timestamp: %@ absolute time: %llu", _endDate,
        (unsigned long long)_endTimestamp);
    for (SentryTransaction *transaction in _transactions) {
        SENTRY_LOG_DEBUG(@"Transaction %@ start timestamp: %@", transaction.trace.traceId,
            transaction.startTimestamp);
        SENTRY_LOG_DEBUG(
            @"Transaction %@ end timestamp: %@", transaction.trace.traceId, transaction.timestamp);
        const auto relativeStart =
            [NSString stringWithFormat:@"%llu",
                      [transaction.startTimestamp compare:_startDate] == NSOrderedAscending
                          ? 0
                          : timeIntervalToNanoseconds(
                              [transaction.startTimestamp timeIntervalSinceDate:_startDate])];

        NSString *relativeEnd;
        if ([transaction.timestamp compare:_endDate] == NSOrderedDescending) {
            relativeEnd = [NSString stringWithFormat:@"%llu", profileDuration];
        } else {
            const auto profileStartToTransactionEndInterval =
                [transaction.timestamp timeIntervalSinceDate:_startDate];
            if (profileStartToTransactionEndInterval < 0) {
                SENTRY_LOG_DEBUG(@"Transaction %@ ended before the profiler started, won't "
                                 @"associate it with this profile.",
                    transaction.trace.traceId.sentryIdString);
                continue;
            } else {
                const auto profileStartToTransactionEnd_ns
                    = timeIntervalToNanoseconds(profileStartToTransactionEndInterval);
                relativeEnd = [NSString
                    stringWithFormat:@"%llu", (unsigned long long)profileStartToTransactionEnd_ns];
            }
        }
        [transactionsInfo addObject:@{
            @"id" : transaction.eventId.sentryIdString,
            @"trace_id" : transaction.trace.traceId.sentryIdString,
            @"name" : transaction.transaction,
            @"relative_start_ns" : relativeStart,
            @"relative_end_ns" : relativeEnd,
            @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
        }];
    }

    if (transactionsInfo.count == 0) {
        SENTRY_LOG_DEBUG(@"No transactions to associate with this profile, will not upload.");
        return;
    }
    profile[@"transactions"] = transactionsInfo;

    NSError *error = nil;
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile error:&error];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON: %@", error);
        return;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    const auto item = [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
    const auto envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:profileID];
    const auto envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader singleItem:item];

    SENTRY_LOG_DEBUG(@"Capturing profile envelope.");
    [_hub captureEnvelope:envelope];
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
