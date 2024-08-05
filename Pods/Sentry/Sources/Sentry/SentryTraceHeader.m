#import "SentryTraceHeader.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTraceHeader

@synthesize traceId = _traceId;
@synthesize spanId = _spanId;
@synthesize sampled = _sampled;

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                        sampled:(SentrySampleDecision)sampleDecision
{
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
        _sampled = sampleDecision;
    }
    return self;
}

- (NSString *)value
{
    return _sampled != kSentrySampleDecisionUndecided
        ? [NSString stringWithFormat:@"%@-%@-%i", _traceId.sentryIdString,
                    _spanId.sentrySpanIdString, _sampled == kSentrySampleDecisionYes ? 1 : 0]
        : [NSString stringWithFormat:@"%@-%@", _traceId.sentryIdString, _spanId.sentrySpanIdString];
}

@end

NS_ASSUME_NONNULL_END
