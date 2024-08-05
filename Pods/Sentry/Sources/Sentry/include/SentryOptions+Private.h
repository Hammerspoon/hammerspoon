#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryOptions.h>
#else
#    import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface
SentryOptions ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
- (BOOL)isContinuousProfilingEnabled;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

SENTRY_EXTERN BOOL sentry_isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
