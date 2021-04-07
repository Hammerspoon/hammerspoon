#import "SentryTransactionContext.h"

@implementation SentryTransactionContext

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation
{
    if (self = [super initWithOperation:operation]) {
        _name = [NSString stringWithString:name];
        self.parentSampled = false;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
{
    if (self = [super initWithOperation:operation sampled:sampled]) {
        _name = [NSString stringWithString:name];
        self.parentSampled = false;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                   operation:(nonnull NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
{
    if ([super initWithTraceId:traceId
                        spanId:spanId
                      parentId:parentSpanId
                     operation:operation
                       sampled:false]) {
        _name = [NSString stringWithString:name];
        self.parentSampled = parentSampled;
    }
    return self;
}

@end
