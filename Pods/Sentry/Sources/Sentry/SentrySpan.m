#import "SentrySpan.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryCurrentDate.h"
#import "SentryFrame.h"
#import "SentryId.h"
#import "SentryLog.h"
#import "SentryMeasurementValue.h"
#import "SentryNoOpSpan.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTime.h"
#import "SentryTraceHeader.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpan ()
@end

@implementation SentrySpan {
    NSMutableDictionary<NSString *, id> *_data;
    NSMutableDictionary<NSString *, id> *_tags;
    BOOL _isFinished;
}

- (instancetype)initWithContext:(SentrySpanContext *)context
{
    if (self = [super init]) {
        SENTRY_LOG_DEBUG(@"Created span %@", context.spanId.sentrySpanIdString);
        self.startTimestamp = [SentryCurrentDate date];
        _data = [[NSMutableDictionary alloc] init];
        _tags = [[NSMutableDictionary alloc] init];
        _isFinished = NO;

        _status = kSentrySpanStatusUndefined;
        _parentSpanId = context.parentSpanId;
        _traceId = context.traceId;
        _operation = context.operation;
        _spanDescription = context.spanDescription;
        _spanId = context.spanId;
        _sampled = context.sampled;
    }
    return self;
}

- (instancetype)initWithTracer:(SentryTracer *)tracer context:(SentrySpanContext *)context
{
    if (self = [self initWithContext:context]) {
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
    return _isFinished;
}

- (void)finish
{
    SENTRY_LOG_DEBUG(@"Attempting to finish span with id %@", self.spanId.sentrySpanIdString);
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    self.status = status;
    _isFinished = YES;
    if (self.timestamp == nil) {
        self.timestamp = [SentryCurrentDate date];
        SENTRY_LOG_DEBUG(@"Setting span timestamp: %@ at system time %llu", self.timestamp,
            (unsigned long long)getAbsoluteTime());
    }
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

- (NSDictionary *)serialize
{
    NSMutableDictionary *mutableDictionary = @{
        @"type" : SENTRY_TRACE_TYPE,
        @"span_id" : self.spanId.sentrySpanIdString,
        @"trace_id" : self.traceId.sentryIdString,
        @"op" : self.operation
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
        [mutableDictionary setValue:nameForSentrySampleDecision(self.sampled) forKey:@"sampled"];
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
            mutableDictionary[@"data"] = [data.copy sentry_sanitize];
        }
    }

    @synchronized(_tags) {
        if (_tags.count > 0) {
            mutableDictionary[@"tags"] = _tags.copy;
        }
    }

    return mutableDictionary;
}

@end

NS_ASSUME_NONNULL_END
