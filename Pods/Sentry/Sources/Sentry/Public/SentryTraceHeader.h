#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySampleDecision)

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_TRACE_HEADER = @"sentry-trace";

NS_SWIFT_NAME(TraceHeader)
@interface SentryTraceHeader : NSObject
SENTRY_NO_INIT
/**
 * Trace ID.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Span ID.
 */
@property (nonatomic, readonly) SentrySpanId *spanId;

/**
 * The trace sample decision.
 */
@property (nonatomic, readonly) SentrySampleDecision sampled;

/**
 * @param traceId The trace id.
 * @param spanId The span id.
 * @param sampled The decision made to sample the trace related to this header.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                        sampled:(SentrySampleDecision)sampled;

/**
 * Return the value to use in a request header.
 */
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
