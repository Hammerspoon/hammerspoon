#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#if SENTRY_HAS_UIKIT

#    if __has_include(<Sentry/SentryProfilingConditionals.h>)
#        import <Sentry/SentryProfilingConditionals.h>
#    else
#        import "SentryProfilingConditionals.h"
#    endif

@class SentryDisplayLinkWrapper;
@protocol SentryCurrentDateProvider;
@class SentryDispatchQueueWrapper;
@class SentryNSNotificationCenterWrapper;
@class SentryScreenFrames;
@class SentryFramesDelayResult;

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@protocol SentryFramesTrackerListener

- (void)framesTrackerHasNewFrame:(NSDate *)newFrameDate;

@end

/**
 * Tracks total, frozen and slow frames for iOS, tvOS, and Mac Catalyst.
 *
 * @discussion This class ignores a couple of methods for the thread sanitizer. We intentionally
 * accept several data races in this class, a decision that is driven by the fact that the code
 * always writes on the main thread. This approach, while it may not provide 100% correct frame
 * statistic for background spans, significantly reduces the overhead of synchronization, thereby
 * enhancing performance.
 */
@interface SentryFramesTracker : NSObject

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
                              dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                      dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                        notificationCenter:(SentryNSNotificationCenterWrapper *)notificationCenter
                 keepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration;

- (SentryScreenFrames *)currentFrames;
@property (nonatomic, assign, readonly) BOOL isRunning;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** Remove previously recorded timestamps in preparation for a later profiled transaction. */
- (void)resetProfilingTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start;
- (void)stop;

- (SentryFramesDelayResult *)getFramesDelay:(uint64_t)startSystemTimestamp
                         endSystemTimestamp:(uint64_t)endSystemTimestamp;

- (void)addListener:(id<SentryFramesTrackerListener>)listener;

- (void)removeListener:(id<SentryFramesTrackerListener>)listener;

@end

BOOL sentryShouldAddSlowFrozenFramesData(
    NSInteger totalFrames, NSInteger slowFrames, NSInteger frozenFrames);

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
