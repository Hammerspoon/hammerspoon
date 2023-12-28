#import "SentryPropagationContext.h"
#import "SentryDsn.h"
#import "SentryHub+Private.h"
#import "SentryId.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpanId.h"
#import "SentryTraceContext.h"
#import "SentryTraceHeader.h"
#import "SentryUser+Private.h"

@implementation SentryPropagationContext

- (instancetype)init
{
    if (self = [super init]) {
        self.traceId = [[SentryId alloc] init];
        self.spanId = [[SentrySpanId alloc] init];
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
