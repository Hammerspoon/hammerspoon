#import "SentrySamplingContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySamplingContext

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
{
    if (self = [super init]) {
        _transactionContext = transactionContext;
    }
    return self;
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    self = [self initWithTransactionContext:transactionContext];
    _customSamplingContext = customSamplingContext;
    return self;
}

@end

NS_ASSUME_NONNULL_END
