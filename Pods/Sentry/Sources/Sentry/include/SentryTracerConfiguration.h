#if __has_include(<Sentry/PrivatesHeader.h>)
#    import <Sentry/PrivatesHeader.h>
#else
#    import "PrivatesHeader.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;
@class SentryNSTimerFactory;
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

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Whether to sample a profile corresponding to this transaction
 */
@property (nonatomic, strong, nullable) SentrySamplerDecision *profilesSamplerDecision;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED"

/**
 * The idle time to wait until to finish the transaction
 *
 * Default is 0 seconds
 */
@property (nonatomic) NSTimeInterval idleTimeout;

/**
 * A writer around NSTimer, to make it testable
 */
@property (nonatomic, strong, nullable) SentryNSTimerFactory *timerFactory;

+ (SentryTracerConfiguration *)configurationWithBlock:
    (void (^)(SentryTracerConfiguration *configuration))block;

@end

NS_ASSUME_NONNULL_END
