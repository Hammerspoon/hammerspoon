#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHub;
@class SentryId;
@class SentryScreenFrames;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN SentryEnvelopeItem *_Nullable sentry_traceProfileEnvelopeItem(
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

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
