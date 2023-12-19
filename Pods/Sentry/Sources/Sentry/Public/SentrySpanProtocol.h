#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId, SentryId, SentryTraceHeader, SentryMeasurementUnit;

NS_SWIFT_NAME(Span)
@protocol SentrySpan <SentrySerializable>

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic, strong) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic, strong) SentrySpanId *spanId;

/**
 * The id of the parent span.
 */
@property (nullable, nonatomic, strong) SentrySpanId *parentSpanId;

/**
 * The sampling decision of the trace.
 */
@property (nonatomic) SentrySampleDecision sampled;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nonatomic, copy) NSString *operation;

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
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nullable, nonatomic, copy) NSString *spanDescription;

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
 * An arbitrary mapping of additional metadata of the span.
 */
@property (readonly) NSDictionary<NSString *, id> *data;

/**
 * key-value pairs holding additional data about the span.
 */
@property (readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Starts a child span.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
    NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Sets a value to data.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key NS_SWIFT_NAME(setData(value:key:));

/**
 * Use @c setDataValue instead. This method calls @c setDataValue, was added by mistake, and will be
 * removed in a future version.
 */
- (void)setExtraValue:(nullable id)value
               forKey:(NSString *)key DEPRECATED_ATTRIBUTE NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Removes a data value.
 */
- (void)removeDataForKey:(NSString *)key NS_SWIFT_NAME(removeData(key:));

/**
 * Sets a tag value.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Removes a tag value.
 */
- (void)removeTagForKey:(NSString *)key NS_SWIFT_NAME(removeTag(key:));

/**
 * Set a measurement without unit. When setting the measurement without the unit, no formatting
 * will be applied to the measurement value in the Sentry product, and the value will be shown as
 * is.
 * @discussion Setting a measurement with the same name on the same transaction multiple times only
 * keeps the last value.
 * @param name the name of the measurement
 * @param value the value of the measurement
 */
- (void)setMeasurement:(NSString *)name
                 value:(NSNumber *)value NS_SWIFT_NAME(setMeasurement(name:value:));

/**
 * Set a measurement with specific unit.
 * @discussion Setting a measurement with the same name on the same transaction multiple times only
 * keeps the last value.
 * @param name the name of the measurement
 * @param value the value of the measurement
 * @param unit the unit the value is measured in
 */
- (void)setMeasurement:(NSString *)name
                 value:(NSNumber *)value
                  unit:(SentryMeasurementUnit *)unit
    NS_SWIFT_NAME(setMeasurement(name:value:unit:));

/**
 * Finishes the span by setting the end time.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 * @param status The status of this span
 *  */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

/**
 * Returns the trace information that could be sent as a sentry-trace header.
 * @return SentryTraceHeader.
 */
- (SentryTraceHeader *)toTraceHeader;

@end

NS_ASSUME_NONNULL_END
