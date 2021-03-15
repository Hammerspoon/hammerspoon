#import "SentrySamplingContext.h"

@implementation SentrySamplingContext

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:
                         (nullable NSDictionary<NSString *, id> *)customSamplingContext
{
    if (self = [super init]) {
        _transactionContext = transactionContext;
        _customSamplingContext = customSamplingContext;
    }
    return self;
}

@end
