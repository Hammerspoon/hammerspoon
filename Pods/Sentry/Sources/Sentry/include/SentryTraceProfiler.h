#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryId;

@interface SentryTraceProfiler : NSObject

/**
 * Start a profiler, if one isn't already running.
 */
+ (BOOL)startWithTracer:(SentryId *)traceId;

/**
 * Whether there is any profiler that is currently running. A convenience method to query for this
 * information from other SDK components that don't have access to specific @c SentryProfiler
 * instances.
 */
+ (BOOL)isCurrentlyProfiling;

/**
 * Immediately record a sample of profiling metrics. Helps get full coverage of concurrent spans
 * when they're ended.
 */
+ (void)recordMetrics;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
