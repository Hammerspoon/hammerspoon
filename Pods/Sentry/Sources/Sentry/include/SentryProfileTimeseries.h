#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentrySample;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSArray<SentrySample *> *_Nullable slicedProfileSamples(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime, uint64_t endSystemTime);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
