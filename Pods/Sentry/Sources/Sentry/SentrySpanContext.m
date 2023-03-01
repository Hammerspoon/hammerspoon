#import "SentrySpanContext.h"
#import "SentryId.h"
#import "SentryLog.h"
#import "SentrySpanId.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySpanContext

- (instancetype)initWithOperation:(NSString *)operation
{
    return [self initWithOperation:operation sampled:false];
}

- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                       operation:operation
                         sampled:sampled];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                 spanDescription:nil
                         sampled:sampled];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled
{
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
        _parentSpanId = parentId;
        _sampled = sampled;
        _operation = operation;
        _spanDescription = description;

        SENTRY_LOG_DEBUG(
            @"Created span context with trace ID %@; span ID %@; parent span ID %@; operation %@",
            traceId.sentryIdString, spanId.sentrySpanIdString, parentId.sentrySpanIdString,
            operation);
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *mutabledictionary = @{
        @"type" : SENTRY_TRACE_TYPE,
        @"span_id" : self.spanId.sentrySpanIdString,
        @"trace_id" : self.traceId.sentryIdString,
        @"op" : self.operation
    }
                                                 .mutableCopy;

    // Since we guard for 'undecided', we'll
    // either send it if it's 'true' or 'false'.
    if (self.sampled != kSentrySampleDecisionUndecided) {
        [mutabledictionary setValue:nameForSentrySampleDecision(self.sampled) forKey:@"sampled"];
    }

    if (self.spanDescription != nil) {
        [mutabledictionary setValue:self.spanDescription forKey:@"description"];
    }

    if (self.parentSpanId != nil) {
        [mutabledictionary setValue:self.parentSpanId.sentrySpanIdString forKey:@"parent_span_id"];
    }

    return mutabledictionary;
}
@end

NS_ASSUME_NONNULL_END
