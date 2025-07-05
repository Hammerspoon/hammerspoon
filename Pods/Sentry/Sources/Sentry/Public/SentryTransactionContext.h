#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySampleDecision)
#import SENTRY_HEADER(SentrySpanContext)

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
 * Rate of sampling
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * Random value used to determine if the span is sampled.
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRand;

/**
 * Parent sampled
 */
@property (nonatomic) SentrySampleDecision parentSampled;

/**
 * Parent sample rate used for this transaction
 */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;

/**
 * Parent random value used to determine if the trace is sampled.
 */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;

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
                     sampled:(SentrySampleDecision)sampled
    DEPRECATED_MSG_ATTRIBUTE("Use initWithName:operation:sampled:sampleRate:sampleRand instead");

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;

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
               parentSampled:(SentrySampleDecision)parentSampled
    DEPRECATED_MSG_ATTRIBUTE("Use "
                             "initWithName:operation:traceId:spanId:parentSpanId:parentSampled:"
                             "parentSampleRate:parentSampleRand instead");

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
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@end

NS_ASSUME_NONNULL_END
