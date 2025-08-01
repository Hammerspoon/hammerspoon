#import "SentryPropagationContext.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"
#import "SentryTraceHeader.h"

@implementation SentryPropagationContext

- (instancetype)init
{
    if (self = [super init]) {
        _traceId = [[SentryId alloc] init];
        _spanId = [[SentrySpanId alloc] init];
    }
    return self;
}

- (instancetype)initWithTraceId:(SentryId *)traceId spanId:(SentrySpanId *)spanId
{
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
    }
    return self;
}

- (SentryTraceHeader *)traceHeader
{
    return [[SentryTraceHeader alloc] initWithTraceId:self.traceId
                                               spanId:self.spanId
                                              sampled:kSentrySampleDecisionNo];
}

- (NSDictionary<NSString *, NSString *> *)traceContextForEvent
{
    return
        @{ @"span_id" : self.spanId.sentrySpanIdString, @"trace_id" : self.traceId.sentryIdString };
}

@end
