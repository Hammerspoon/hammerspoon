#import "SentryDefines.h"
#import "SentrySpanStatus.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

/**
 * Tracks performance synchronizing span with its childs.
 * A span will be finished only when all its children are finished.
 */
@interface SentryPerformanceTracker : NSObject

/**
 * A static instance of performance tracker.
 */
+ (instancetype)shared;

/**
 * Starts a new span if no span is active,
 * then bind it to the scope if no span is binded.
 * If there`s an active span, starts a child of the active span.
 *
 * @param name Span name.
 * @param operation Span operation.
 *
 * @return The span id.
 */
- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Activate the span with `spanId`
 * to create any call to startSpan as a child.
 * If the there is no span with the fiven spanId
 * block is executed anyway.
 *
 * @param spanId Id of the span to activate
 * @param block Block to invoke while span is active
 */
- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

/**
 * Measure the given block execution.
 *
 * @param description The description of the span.
 * @param operation Span operation.
 * @param block Block to be measured.
 */
- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                           inBlock:(void (^)(void))block;

/**
 * Measure the given block execution
 * adding it as a child of given parent span.
 * If parentSpanId does not exist this
 * measurement is not performed.
 *
 * @param description The description of the span.
 * @param operation Span operation.
 * @param parentSpanId Id of the span to use as parent.
 * @param block Block to be measured.
 */
- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block;

/**
 * Gets the active span id.
 */
- (nullable SentrySpanId *)activeSpanId;

/**
 * Marks a span to be finished.
 * If the given span has no child it is finished immediately,
 * otherwise it waits until all children are finished.
 *
 * @param spanId Id of the span to finish.
 */
- (void)finishSpan:(SentrySpanId *)spanId;

/**
 * Marks a span to be finished with given status.
 * If the given span has no child it is finished immediately,
 * otherwise it waits until all children are finished.
 *
 * @param spanId Id of the span to finish.
 * @param status Span finish status.
 */
- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status;

/**
 * Checks if given span is waiting to be finished.
 *
 * @param spanId Id of the span to be checked.
 *
 * @return A boolean value indicating whether the span still waiting to be finished.
 */
- (BOOL)isSpanAlive:(SentrySpanId *)spanId;

/**
 * Return the SentrySpan associated with the given spanId.
 *
 * @param spanId Id of the span to return.
 *
 * @return SentrySpan
 */
- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

@end

NS_ASSUME_NONNULL_END
