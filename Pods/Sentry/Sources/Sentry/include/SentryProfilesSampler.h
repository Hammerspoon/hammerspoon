#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryRandom.h"
#    import "SentrySampleDecision.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentrySamplingContext, SentryTracesSamplerDecision;

@interface SentryProfilesSamplerDecision : NSObject

@property (nonatomic, readonly) SentrySampleDecision decision;

@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRate;

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate;

@end

@interface SentryProfilesSampler : NSObject

/**
 *  A random number generator
 */
@property (nonatomic, strong) id<SentryRandom> random;

/**
 * Init a ProfilesSampler with given options and random generator.
 * @param options Sentry options with sampling configuration
 * @param random A random number generator
 */
- (instancetype)initWithOptions:(SentryOptions *)options random:(id<SentryRandom>)random;

/**
 * Init a ProfilesSampler with given options and a default Random generator.
 * @param options Sentry options with sampling configuration
 */
- (instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Determines whether a profile should be sampled based on the context, options, and
 * whether the trace corresponding to the profile was sampled.
 */
- (SentryProfilesSamplerDecision *)sample:(SentrySamplingContext *)context
                    tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
