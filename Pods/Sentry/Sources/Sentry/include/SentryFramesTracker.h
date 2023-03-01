#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

@class SentryOptions, SentryDisplayLinkWrapper, SentryScreenFrames;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@class SentryTracer;

/**
 * Tracks total, frozen and slow frames for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryFramesTracker : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

@property (nonatomic, assign, readonly) SentryScreenFrames *currentFrames;
@property (nonatomic, assign, readonly) BOOL isRunning;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** Remove previously recorded timestamps in preparation for a later profiled transaction. */
- (void)resetProfilingTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start;
- (void)stop;

@end

#endif

NS_ASSUME_NONNULL_END
