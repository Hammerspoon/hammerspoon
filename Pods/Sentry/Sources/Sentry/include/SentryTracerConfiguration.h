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
 * If Yes, this tracer will be discarced in case the timeout triggers.
 * Default @c NO
 */
@property (nonatomic) BOOL finishMustBeCalled;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Whether to sample a profile corresponding to this transaction
 */
@property (nonatomic, strong, nullable) SentrySamplerDecision *profilesSamplerDecision;

/**
 * For launch continuous v2 profiles that must start for trace lifecycle, we must explicitly be able
 * to indicate that to the tracer here, since there's no hub or options attached to it for the
 * profiler system to know whether it's a old-style trace profile or a trace continuous v2 profile.
 */
@property (nonatomic, strong, nullable) SentryProfileOptions *profileOptions;
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
