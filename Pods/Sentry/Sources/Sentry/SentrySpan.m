#import "SentryCrashThread.h"
#import "SentryDependencyContainer.h"
#import "SentryFrame.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryMeasurementValue.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryNoOpSpan.h"
#import "SentrySampleDecision+Private.h"
#import "SentrySpan+Private.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"
#import "SentryThreadInspector.h"
#import "SentryTime.h"
#import "SentryTraceHeader.h"
#import "SentryTracer.h"

#if SENTRY_HAS_UIKIT
#    import <SentryFramesTracker.h>
#    import <SentryScreenFrames.h>
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfilingConditionals.h"
#    import "SentrySDK+Private.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpan ()
@end

@implementation SentrySpan {
    NSMutableDictionary<NSString *, id> *_data;
    NSMutableDictionary<NSString *, id> *_tags;
    NSObject *_stateLock;
    BOOL _isFinished;
    uint64_t _startSystemTime;
    LocalMetricsAggregator *localMetricsAggregator;
#if SENTRY_HAS_UIKIT
    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
    SentryFramesTracker *_framesTracker;
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_PROFILING_SUPPORTED
    BOOL _isContinuousProfiling;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED
}

- (instancetype)initWithContext:(SentrySpanContext *)context
#if SENTRY_HAS_UIKIT
                  framesTracker:(nullable SentryFramesTracker *)framesTracker;
#endif // SENTRY_HAS_UIKIT
{
    if (self = [super init]) {
        _startSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
        self.startTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
        _data = [[NSMutableDictionary alloc] init];

        SentryCrashThread currentThread = sentrycrashthread_self();
        _data[SPAN_DATA_THREAD_ID] = @(currentThread);

        if ([NSThread isMainThread]) {
            _data[SPAN_DATA_THREAD_NAME] = @"main";
        } else {
            _data[SPAN_DATA_THREAD_NAME] = [SentryDependencyContainer.sharedInstance.threadInspector
                getThreadName:currentThread];
        }

#if SENTRY_HAS_UIKIT
        _framesTracker = framesTracker;
        if (_framesTracker.isRunning) {
            SentryScreenFrames *currentFrames = _framesTracker.currentFrames;
            initTotalFrames = currentFrames.total;
            initSlowFrames = currentFrames.slow;
            initFrozenFrames = currentFrames.frozen;
        }
#endif // SENTRY_HAS_UIKIT

        _tags = [[NSMutableDictionary alloc] init];
        _stateLock = [[NSObject alloc] init];
        _isFinished = NO;

        _status = kSentrySpanStatusUndefined;
        _parentSpanId = context.parentSpanId;
        _traceId = context.traceId;
        _operation = context.operation;
        _spanDescription = context.spanDescription;
        _spanId = context.spanId;
        _sampled = context.sampled;
        _origin = context.origin;

#if SENTRY_TARGET_PROFILING_SUPPORTED
        _isContinuousProfiling = [SentrySDK.options isContinuousProfilingEnabled];
        if (_isContinuousProfiling) {
            _profileSessionID = SentryContinuousProfiler.currentProfilerID.sentryIdString;
            if (_profileSessionID == nil) {
                [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
                    addObserver:self
                       selector:@selector(linkProfiler)
                           name:kSentryNotificationContinuousProfileStarted];
            }
        }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }
    return self;
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)dealloc
{
    [self stopObservingContinuousProfiling];
}

- (void)linkProfiler
{
    _profileSessionID = SentryContinuousProfiler.currentProfilerID.sentryIdString;
    [self stopObservingContinuousProfiling];
}

- (void)stopObservingContinuousProfiling
{
    if (_isContinuousProfiling) {
        [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
            removeObserver:self
                      name:kSentryNotificationContinuousProfileStarted];
    }
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (instancetype)initWithTracer:(SentryTracer *)tracer
                       context:(SentrySpanContext *)context
#if SENTRY_HAS_UIKIT
                 framesTracker:(nullable SentryFramesTracker *)framesTracker
{
    if (self = [self initWithContext:context framesTracker:framesTracker]) {
#else
{
    if (self = [self initWithContext:context]) {
#endif // SENTRY_HAS_UIKIT

        _tracer = tracer;
    }
    return self;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
{
    return [self startChildWithOperation:operation description:nil];
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
{
    if (self.tracer == nil) {
        SENTRY_LOG_DEBUG(@"No tracer, returning no-op span");
        return [SentryNoOpSpan shared];
    }

    return [self.tracer startChildWithParentId:self.spanId
                                     operation:operation
                                   description:description];
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
    @synchronized(_data) {
        [_data setValue:value forKey:key];
    }
}

- (void)setExtraValue:(nullable id)value forKey:(NSString *)key
{
    [self setDataValue:value forKey:key];
}

- (void)removeDataForKey:(NSString *)key
{
    @synchronized(_data) {
        [_data removeObjectForKey:key];
    }
}

- (NSDictionary<NSString *, id> *)data
{
    @synchronized(_data) {
        return [_data copy];
    }
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags setValue:value forKey:key];
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags removeObjectForKey:key];
    }
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value
{
    [self.tracer setMeasurement:name value:value];
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit
{
    [self.tracer setMeasurement:name value:value unit:unit];
}

- (NSDictionary<NSString *, id> *)tags
{
    @synchronized(_tags) {
        return [_tags copy];
    }
}

- (BOOL)isFinished
{
    @synchronized(_stateLock) {
        return _isFinished;
    }
}

- (void)finish
{
    SENTRY_LOG_DEBUG(@"Attempting to finish span with id %@", self.spanId.sentrySpanIdString);
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    [self stopObservingContinuousProfiling];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    self.status = status;
    @synchronized(_stateLock) {
        _isFinished = YES;
    }
    if (self.timestamp == nil) {
        self.timestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
        SENTRY_LOG_DEBUG(@"Setting span timestamp: %@ at system time %llu", self.timestamp,
            (unsigned long long)SentryDependencyContainer.sharedInstance.dateProvider.systemTime);
    }

#if SENTRY_HAS_UIKIT
    if (_framesTracker.isRunning) {

        CFTimeInterval framesDelay = [_framesTracker
                getFramesDelay:_startSystemTime
            endSystemTimestamp:SentryDependencyContainer.sharedInstance.dateProvider.systemTime];

        if (framesDelay >= 0) {
            [self setDataValue:@(framesDelay) forKey:@"frames.delay"];
        }

        SentryScreenFrames *currentFrames = _framesTracker.currentFrames;
        NSInteger totalFrames = currentFrames.total - initTotalFrames;
        NSInteger slowFrames = currentFrames.slow - initSlowFrames;
        NSInteger frozenFrames = currentFrames.frozen - initFrozenFrames;

        if (sentryShouldAddSlowFrozenFramesData(totalFrames, slowFrames, frozenFrames)) {
            [self setDataValue:@(totalFrames) forKey:@"frames.total"];
            [self setDataValue:@(slowFrames) forKey:@"frames.slow"];
            [self setDataValue:@(frozenFrames) forKey:@"frames.frozen"];

            SENTRY_LOG_DEBUG(@"Frames for span \"%@\" Total:%ld Slow:%ld Frozen:%ld",
                self.operation, (long)totalFrames, (long)slowFrames, (long)frozenFrames);
        }
    }

#endif // SENTRY_HAS_UIKIT

    if (self.tracer == nil) {
        SENTRY_LOG_DEBUG(
            @"No tracer associated with span with id %@", self.spanId.sentrySpanIdString);
        return;
    }
    [self.tracer spanFinished:self];
}

- (SentryTraceHeader *)toTraceHeader
{
    return [[SentryTraceHeader alloc] initWithTraceId:self.traceId
                                               spanId:self.spanId
                                              sampled:self.sampled];
}

- (LocalMetricsAggregator *)getLocalMetricsAggregator
{
    if (localMetricsAggregator == nil) {
        localMetricsAggregator = [[LocalMetricsAggregator alloc] init];
    }
    return localMetricsAggregator;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *mutableDictionary = @{
        @"type" : SENTRY_TRACE_TYPE,
        @"span_id" : self.spanId.sentrySpanIdString,
        @"trace_id" : self.traceId.sentryIdString,
        @"op" : self.operation,
        @"origin" : self.origin
    }
                                                 .mutableCopy;

    @synchronized(_tags) {
        if (_tags.count > 0) {
            mutableDictionary[@"tags"] = _tags.copy;
        }
    }

    // Since we guard for 'undecided', we'll
    // either send it if it's 'true' or 'false'.
    if (self.sampled != kSentrySampleDecisionUndecided) {
        [mutableDictionary setValue:valueForSentrySampleDecision(self.sampled) forKey:@"sampled"];
    }

    if (self.spanDescription != nil) {
        [mutableDictionary setValue:self.spanDescription forKey:@"description"];
    }

    if (self.parentSpanId != nil) {
        [mutableDictionary setValue:self.parentSpanId.sentrySpanIdString forKey:@"parent_span_id"];
    }

    if (self.status != kSentrySpanStatusUndefined) {
        [mutableDictionary setValue:nameForSentrySpanStatus(self.status) forKey:@"status"];
    }

    [mutableDictionary setValue:@(self.timestamp.timeIntervalSince1970) forKey:@"timestamp"];

    [mutableDictionary setValue:@(self.startTimestamp.timeIntervalSince1970)
                         forKey:@"start_timestamp"];

    if (localMetricsAggregator != nil) {
        mutableDictionary[@"_metrics_summary"] = [localMetricsAggregator serialize];
    }

    @synchronized(_data) {
        NSMutableDictionary *data = _data.mutableCopy;

        if (self.frames && self.frames.count > 0) {
            NSMutableArray *frames = [[NSMutableArray alloc] initWithCapacity:self.frames.count];

            for (SentryFrame *frame in self.frames) {
                [frames addObject:[frame serialize]];
            }

            data[@"call_stack"] = frames;
        }

        if (data.count > 0) {
            mutableDictionary[@"data"] = sentry_sanitize(data.copy);
        }
    }

    @synchronized(_tags) {
        if (_tags.count > 0) {
            mutableDictionary[@"tags"] = _tags.copy;
        }
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (_profileSessionID != nil) {
        mutableDictionary[@"profiler_id"] = _profileSessionID;
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    return mutableDictionary;
}

@end

NS_ASSUME_NONNULL_END
