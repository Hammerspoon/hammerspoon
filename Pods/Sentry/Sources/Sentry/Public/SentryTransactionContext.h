#import "SentrySampleDecision.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

NS_SWIFT_NAME(TransactionContext)
@interface SentryTransactionContext : SentrySpanContext
SENTRY_NO_INIT

/**
 * Transaction name
 */
@property (nonatomic, readonly) NSString *name;

/**
 * Parent sampled
 */
@property (nonatomic) SentrySampleDecision parentSampled;

/**
 * Init a SentryTransactionContext with given name and set other fields by default
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Init a SentryTransactionContext with given name and set other fields by default
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled;

/**
 * Init a SentryTransactionContext with given name, traceId, SpanId, parentSpanId and whether the
 * parent is sampled.
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentSpanId Parent span id
 * @param parentSampled Whether the parent is sampled
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

@end

NS_ASSUME_NONNULL_END
