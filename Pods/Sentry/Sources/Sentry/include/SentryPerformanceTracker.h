#import "SentryDefines.h"
#import "SentrySpanStatus.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

/**
 * Tracks performance synchronizing span with its child's.
 * @note A span will be finished only when all its children are finished.
 */
@interface SentryPerformanceTracker : NSObject

/**
 * A static instance of performance tracker.
 */
@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

/**
 * Starts a new span if no span is active, then bind it to the scope if no span is bound.
 * @note If there's an active span, starts a child of the active span.
 * @param name Span name.
 * @param source the transaction name source.
 * @param operation Span operation.
 * @return The span id.
 */
- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation
                             origin:(NSString *)origin;

/**
 * Activate the span with @c spanId to create any call to @c startSpan as a child.
 * @note If the there is no span with @c spanId , @c block is executed anyway.
 * @param spanId Id of the span to activate
 * @param block Block to invoke while span is active
 */
- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

/**
 * Measure the given @c block execution.
 * @param description The description of the span.
 * @param source the transaction name source.
 * @param operation Span operation.
 * @param block Block to be measured.
 */
- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                           inBlock:(void (^)(void))block;

/**
 * Measure the given @c block execution adding it as a child of given parent span.
 * @note If @c parentSpanId does not exist this measurement is not performed.
 * @param description The description of the span.
 * @param source the transaction name source.
 * @param operation Span operation.
 * @param parentSpanId Id of the span to use as parent.
 * @param block Block to be measured.
 */
- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block;

/**
 * Gets the active span id.
 */
- (nullable SentrySpanId *)activeSpanId;

/**
 * Marks a span to be finished.
 * If the given span has no child it is finished immediately, otherwise it waits until all children
 * are finished.
 * @param spanId Id of the span to finish.
 */
- (void)finishSpan:(SentrySpanId *)spanId;

/**
 * Marks a span to be finished with given status.
 * If the given span has no child it is finished immediately, otherwise it waits until all children
 * are finished.
 * @param spanId Id of the span to finish.
 * @param status Span finish status.
 */
- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status;

/**
 * Checks if given span is waiting to be finished.
 * @param spanId Id of the span to be checked.
 * @return A boolean value indicating whether the span still waiting to be finished.
 */
- (BOOL)isSpanAlive:(SentrySpanId *)spanId;

/**
 * Return the SentrySpan associated with the given spanId.
 * @param spanId Id of the span to return.
 * @return SentrySpan
 */
- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId;

- (void)popActiveSpan;

@end

NS_ASSUME_NONNULL_END
