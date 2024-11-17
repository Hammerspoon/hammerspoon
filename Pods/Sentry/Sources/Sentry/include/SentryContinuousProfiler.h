#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kSentryNotificationContinuousProfileStarted
    = @"io.sentry.notification.continuous-profile-started";

/**
 * An interface to the new continuous profiling implementation.
 */
@interface SentryContinuousProfiler : NSObject

/** Start a continuous  profiling session if one doesn't already exist. */
+ (void)start;

+ (BOOL)isCurrentlyProfiling;

/** Stop a continuous profiling session if there is one ongoing. */
+ (void)stop;

+ (nullable SentryId *)currentProfilerID;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
