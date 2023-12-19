#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugMeta;
@class SentryId;
@class SentryProfilerState;
@class SentrySample;
@class SentryHub;
#    if SENTRY_HAS_UIKIT
@class SentryScreenFrames;
#    endif // SENTRY_HAS_UIKIT
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSMutableDictionary<NSString *, id> *serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

@interface
SentryProfiler ()

@property (strong, nonatomic) SentryProfilerState *_state;
#    if SENTRY_HAS_UIKIT
@property (strong, nonatomic) SentryScreenFrames *_screenFrameData;
#    endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
