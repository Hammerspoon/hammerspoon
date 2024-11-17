#import "SentrySampleDecision.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;
@class SentryThread;

NS_SWIFT_NAME(TransactionContext)
@interface SentryTransactionContext : SentrySpanContext
SENTRY_NO_INIT

/**
 * Transaction name
 */
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SentryTransactionNameSource nameSource;

/**
 * Parent sampled
 */
@property (nonatomic) SentrySampleDecision parentSampled;

/**
 * Sample rate used for this transaction
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * If app launch profiling is enabled via @c SentryOptions.enableAppLaunchProfiling and
 * @c SentryOptions.tracesSampler and/or @c SentryOptions.profilesSampler are defined,
 * @c SentrySDK.startWithOptions will call the sampler function with this property set to @c YES ,
 * and the returned value will be stored to disk for the next launch to calculate a sampling
 * decision on whether or not to run the profiler.
 */
@property (nonatomic, assign) BOOL forNextAppLaunch;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentSpanId Parent span id
 * @param parentSampled Whether the parent is sampled
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

@end

NS_ASSUME_NONNULL_END
