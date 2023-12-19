#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryTransactionContext;

NS_SWIFT_NAME(SamplingContext)
@interface SentrySamplingContext : NSObject

/**
 * Transaction context.
 */
@property (nonatomic, readonly) SentryTransactionContext *transactionContext;

/**
 * Custom data used for sampling.
 */
@property (nullable, nonatomic, readonly) NSDictionary<NSString *, id> *customSamplingContext;

/**
 * Init a SentryTransactionSamplingContext.
 * @param transactionContext The context of the transaction being sampled.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext;

/**
 * Init a SentryTransactionSamplingContext.
 * @param transactionContext The context of the transaction being sampled.
 * @param customSamplingContext Custom data used for sampling.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@end

NS_ASSUME_NONNULL_END
