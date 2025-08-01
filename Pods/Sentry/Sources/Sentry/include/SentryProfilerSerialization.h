#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"

@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHub;
@class SentryId;
@class SentryScreenFrames;
@class SentryTransaction;
@class SentryProfiler;

NS_ASSUME_NONNULL_BEGIN

#    if defined(__cplusplus)
extern "C" {
#    endif

SENTRY_EXTERN SentryEnvelopeItem *_Nullable sentry_traceProfileEnvelopeItem(SentryHub *hub,
    SentryProfiler *profiler, NSDictionary<NSString *, id> *profilingData,
    SentryTransaction *transaction, NSDate *startTimestamp);

SentryEnvelope *_Nullable sentry_continuousProfileChunkEnvelope(
    SentryId *profileID, NSDictionary *profileState, NSDictionary *metricProfilerState
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

/** Alternative affordance for use by PrivateSentrySDKOnly for hybrid SDKs. */
NSMutableDictionary<NSString *, id> *_Nullable sentry_collectProfileDataHybridSDK(
    uint64_t startSystemTime, uint64_t endSystemTime, SentryId *traceId, SentryHub *hub);

#    if defined(__cplusplus)
}
#    endif

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
