#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import "SentryTracerConfiguration.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;
@class SentryHub;
@class SentryMeasurementValue;
@class SentryNSTimerFactory;
@class SentryTraceContext;
@class SentryTraceHeader;
@class SentryTracer;
@class SentryTransactionContext;

static NSTimeInterval const SentryTracerDefaultTimeout = 3.0;

static const NSTimeInterval SENTRY_AUTO_TRANSACTION_MAX_DURATION = 500.0;

@protocol SentryTracerDelegate

/**
 * Return the active span of given tracer.
 * This function is used to determine which span will be used to create a new child.
 */
- (nullable id<SentrySpan>)activeSpanForTracer:(SentryTracer *)tracer;

/**
 * Report that the tracer has finished.
 */
- (void)tracerDidFinish:(SentryTracer *)tracer;

@end

@interface SentryTracer : SentrySpan

@property (nonatomic, strong) SentryTransactionContext *transactionContext;

@property (nullable, nonatomic, copy) void (^finishCallback)(SentryTracer *);

@property (nullable, nonatomic, copy) BOOL (^shouldIgnoreWaitForChildrenCallback)(id<SentrySpan>);

/**
 * Retrieves a trace context from this tracer.
 */
@property (nonatomic, readonly) SentryTraceContext *traceContext;

/**
 * All the spans that where created with this tracer but rootSpan.
 */
@property (nonatomic, readonly) NSArray<id<SentrySpan>> *children;

/**
 * A delegate that provides extra information for the transaction.
 */
@property (nullable, nonatomic, weak) id<SentryTracerDelegate> delegate;

@property (nonatomic, readonly) NSDictionary<NSString *, SentryMeasurementValue *> *measurements;

/**
 * Init a @c SentryTracer with given transaction context and hub and set other fields by default
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub;

/**
 * Init a SentryTracer with given transaction context and hub and set other fields by default
 *
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 * @param configuration Configuration on how SentryTracer will behave
 *
 * @return SentryTracer
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                             configuration:(SentryTracerConfiguration *)configuration;

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(parentId:operation:description:));

/**
 * A method to inform the tracer that a span finished.
 */
- (void)spanFinished:(id<SentrySpan>)finishedSpan;

/**
 * Get the tracer from a span.
 */
+ (nullable SentryTracer *)getTracer:(id<SentrySpan>)span;

- (void)dispatchIdleTimeout;

@end

NS_ASSUME_NONNULL_END
