#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryProfilingConditionals.h"

@class SentryOptions, SentryDisplayLinkWrapper, SentryScreenFrames;

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@protocol SentryFramesTrackerListener

- (void)framesTrackerHasNewFrame;

@end

/**
 * Tracks total, frozen and slow frames for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryFramesTracker : NSObject

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

@property (nonatomic, assign, readonly) SentryScreenFrames *currentFrames;
@property (nonatomic, assign, readonly) BOOL isRunning;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** Remove previously recorded timestamps in preparation for a later profiled transaction. */
- (void)resetProfilingTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start;
- (void)stop;

- (void)addListener:(id<SentryFramesTrackerListener>)listener;

- (void)removeListener:(id<SentryFramesTrackerListener>)listener;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
