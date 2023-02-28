#include "SentryProfilingConditionals.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransactionContext (Private)

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(nonnull NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
                     sampled:(SentrySampleDecision)sampled
               parentSampled:(SentrySampleDecision)parentSampled;

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (SentryThread *)sentry_threadInfo;
#endif

@end

NS_ASSUME_NONNULL_END
