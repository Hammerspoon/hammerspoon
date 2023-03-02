#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId, SentryId, SentryTraceHeader;

NS_SWIFT_NAME(Span)
@protocol SentrySpan <SentrySerializable>

/**
 * The context information of the span.
 */
@property (nonatomic, readonly) SentrySpanContext *context;

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
@property (nullable, readonly) NSDictionary<NSString *, id> *data;

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
 *
 * @param operation Short code identifying the type of operation the span is measuring.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
    NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Sets a value to data.
 */
- (void)setDataValue:(nullable id)value
              forKey:(NSString *)key NS_SWIFT_NAME(setData(value:key:));

/**
 * Use setDataValue instead. This method calls setDataValue, was added by mistake, and will be
 * deprecated in a future version.
 */
- (void)setExtraValue:(nullable id)value
               forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

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
 * Finishes the span by setting the end time.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 *
 * @param status The status of this span
 *  */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

/**
 * Returns the trace information that could be sent as a sentry-trace header.
 *
 * @return SentryTraceHeader.
 */
- (SentryTraceHeader *)toTraceHeader;

@end

NS_ASSUME_NONNULL_END
