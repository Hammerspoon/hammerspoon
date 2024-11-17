#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer, SentryId, SentrySpanId, SentryFrame, SentrySpanContext;
@class LocalMetricsAggregator;

#if SENTRY_HAS_UIKIT
@class SentryFramesTracker;
#endif // SENTRY_HAS_UIKIT

@interface SentrySpan : NSObject <SentrySpan, SentrySerializable>
SENTRY_NO_INIT

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic) SentrySpanId *spanId;

/**
 * Id of a parent span.
 */
@property (nullable, nonatomic) SentrySpanId *parentSpanId;

/**
 * If trace is sampled.
 */
@property (nonatomic) SentrySampleDecision sampled;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nonatomic, copy) NSString *operation;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nullable, nonatomic, copy) NSString *spanDescription;

/**
 * The origin of the span indicates what created the span.
 *
 * @note Gets set by the SDK. It is not expected to be set manually by users. Although the protocol
 * allows this value to be optional, we make it nonnullable as we always send the value.
 *
 * @see <https://develop.sentry.dev/sdk/performance/trace-origin>
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Describes the status of the Transaction.
 */
@property (nonatomic) SentrySpanStatus status;

/**
 * The timestamp of which the span ended.
 */
@property (nullable, nonatomic, strong) NSDate *timestamp;

/**
 * The start time of the span.
 */
@property (nullable, nonatomic, strong) NSDate *startTimestamp;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * The Transaction this span is associated with.
 */
@property (nullable, nonatomic, readonly, weak) SentryTracer *tracer;

/**
 * Frames of the stack trace associated with the span.
 */
@property (nullable, nonatomic, strong) NSArray<SentryFrame *> *frames;

- (LocalMetricsAggregator *)getLocalMetricsAggregator;

/**
 * Init a @c SentrySpan with given transaction and context.
 * @param transaction The @c SentryTracer managing the transaction this span is associated with.
 * @param context This span context information.
 */
- (instancetype)initWithTracer:(SentryTracer *)transaction
                       context:(SentrySpanContext *)context
#if SENTRY_HAS_UIKIT
                 framesTracker:(nullable SentryFramesTracker *)framesTracker;
#endif // SENTRY_HAS_UIKIT
;

/**
 * Init a @c SentrySpan with given context.
 * @param context This span context information.
 */
- (instancetype)initWithContext:(SentrySpanContext *)context
#if SENTRY_HAS_UIKIT
                  framesTracker:(nullable SentryFramesTracker *)framesTracker;
#endif // SENTRY_HAS_UIKIT
;

- (void)setExtraValue:(nullable id)value forKey:(NSString *)key DEPRECATED_ATTRIBUTE;
@end

NS_ASSUME_NONNULL_END
