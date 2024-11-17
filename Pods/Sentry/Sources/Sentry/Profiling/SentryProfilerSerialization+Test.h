#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

#        import "SentryDefines.h"
#        import "SentryProfiler+Private.h"
#        import <Foundation/Foundation.h>

@class SentryDebugMeta;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;

SENTRY_EXTERN NSString *sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/**
 * An intermediate function that can serve requests from either the native SDK or hybrid SDKs; they
 * will have different structures/objects available, these parameters are the common elements
 * needed to construct the payload dictionary.
 */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *sentry_serializedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#        if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#        endif // SENTRY_HAS_UIKIT
);

NS_ASSUME_NONNULL_END

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
