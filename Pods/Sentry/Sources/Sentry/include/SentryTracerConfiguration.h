#if __has_include(<Sentry/PrivatesHeader.h>)
#    import <Sentry/PrivatesHeader.h>
#else
#    import "PrivatesHeader.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;
@class SentryProfileOptions;
@class SentrySamplerDecision;

@interface SentryTracerConfiguration : NSObject

/**
 * Return an instance of SentryTracerConfiguration with default values.
 */
@property (class, readonly) SentryTracerConfiguration *defaultConfiguration;

/**
 * Indicates whether the tracer will be finished only if all children have been finished.
 * If this property is YES and the finish function is called before all children are finished
 * the tracer will automatically finish when the last child finishes.
 *
 * Default is NO.
 */
@property (nonatomic) BOOL waitForChildren;

/**
 * This flag indicates whether the trace should be captured when the timeout triggers.
 * If Yes, this tracer will be discarded in case the timeout triggers.
 * Default @c NO
 */
@property (nonatomic) BOOL finishMustBeCalled;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Whether a profile is sampled for this trace.
 * @note This can be set for either launch profiles (trace-based via @c
 * SentryOptions.profilesSampleRate/SentryOptions.profilesSampler or trace lifecycle ui/v2 profiles
 * via @c SentryProfilingOptions.sessionSampleRate) or non-launch trace-based profiles.
 */
@property (nonatomic, strong, nullable) SentrySamplerDecision *profilesSamplerDecision;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED"

/**
 * The idle time to wait until to finish the transaction
 *
 * Default is 0 seconds
 */
@property (nonatomic) NSTimeInterval idleTimeout;

+ (SentryTracerConfiguration *)configurationWithBlock:
    (void (^)(SentryTracerConfiguration *configuration))block;

@end

NS_ASSUME_NONNULL_END
