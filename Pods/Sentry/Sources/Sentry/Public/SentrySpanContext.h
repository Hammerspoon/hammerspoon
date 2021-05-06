#import "SentryDefines.h"
#import "SentrySampleDecision.h"
#import "SentrySerializable.h"
#import "SentrySpanStatus.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId, SentrySpanId;

NS_SWIFT_NAME(SpanContext)
@interface SentrySpanContext : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic, readonly) SentrySpanId *spanId;

/**
 * Id of a parent span.
 */
@property (nullable, nonatomic, readonly) SentrySpanId *parentSpanId;

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
 * Describes the status of the Transaction.
 */
@property (nonatomic) SentrySpanStatus status;

/**
 * A map or list of tags for this event. Each tag must be less than 200 characters.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Init a SentryContext with an operation code,
 * traceId and spanId with be randomly created,
 * sampled by default is false.
 *
 * @return SentryContext
 */
- (instancetype)initWithOperation:(NSString *)operation;

/**
 * Init a SentryContext with an operation code and mark it as sampled or not.
 * TraceId and SpanId with be randomly created.
 *
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 *
 * @return SentryContext
 */

- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled;

/**
 * Init a SentryContext with given traceId, spanId and parentId.
 *
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id
 * @param operation The operation this span is measuring.
 * @param parentId Id of a parent span.
 * @param sampled Determines whether the trace should be sampled.
 *
 * @return SentryContext
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled;

/**
 * Sets a tag with given value.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Removes a tag.
 */
- (void)removeTagForKey:(NSString *)key NS_SWIFT_NAME(removeTag(key:));

@property (class, nonatomic, readonly, copy) NSString *type;

@end

NS_ASSUME_NONNULL_END
