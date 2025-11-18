#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryOptions.h>
#else
#    import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface SentryOptions ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;

#    if !SDK_V9
/**
 * If continuous profiling mode v1 ("beta") is enabled.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
- (BOOL)isContinuousProfilingEnabled;
#    endif // !SDK_V9

/**
 * If UI profiling mode ("continuous v2") is enabled.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
- (BOOL)isContinuousProfilingV2Enabled;

/**
 * Whether or not the SDK was configured with a profile mode that automatically starts and tracks
 * profiles with traces.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
- (BOOL)isProfilingCorrelatedToTraces;

/**
 * UI Profiling options set on SDK start.
 * @note Not for use with launch profiles. See functions in @c SentryLaunchProfiling .
 */
@property (nonatomic, nullable, strong) SentryProfileOptions *profiling;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#if SENTRY_TARGET_REPLAY_SUPPORTED

- (BOOL)enableViewRendererV2;

- (BOOL)enableFastViewRendering;

#endif // # SENTRY_TARGET_REPLAY_SUPPORTED

@property (nonatomic, strong, nullable)
    SentryUserFeedbackConfiguration *userFeedbackConfiguration API_AVAILABLE(ios(13.0));

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

#if SENTRY_HAS_UIKIT
- (BOOL)isAppHangTrackingV2Disabled;
#endif // SENTRY_HAS_UIKIT
@end

NS_ASSUME_NONNULL_END
