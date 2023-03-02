#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@interface SentrySpan : NSObject <SentrySpan, SentrySerializable>
SENTRY_NO_INIT

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
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * The Transaction this span is associated with.
 */
@property (nullable, nonatomic, readonly, weak) SentryTracer *transaction;

/**
 * Init a SentrySpan with given transaction and context.
 *
 * @param transaction The Transaction this span is associated with.
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithTransaction:(SentryTracer *)transaction
                            context:(SentrySpanContext *)context;

@end

NS_ASSUME_NONNULL_END
