#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDelayedFramesTracker : NSObject
SENTRY_NO_INIT

/**
 * Initializes a @c SentryDelayedFramesTracker. This class keeps track of information on delayed
 * frames. Whenever a new delayed frame is recorded, it removes recorded delayed frames older than
 * the current time minus the @c keepDelayedFramesDuration.
 *
 * @param keepDelayedFramesDuration The maximum duration to keep delayed frames records in memory.
 * @param dateProvider The instance of a date provider.
 */
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(SentryCurrentDateProvider *)dateProvider;

- (void)resetDelayedFramesTimeStamps;

- (void)recordDelayedFrame:(uint64_t)startSystemTimestamp
          expectedDuration:(CFTimeInterval)expectedDuration
            actualDuration:(CFTimeInterval)actualDuration;

/**
 * This method returns the duration of all delayed frames between startSystemTimestamp and
 * endSystemTimestamp.
 *
 * @discussion The frames delay for one recorded delayed frame is the intersection of the delayed
 * part with the queried time interval of startSystemTimestamp and endSystemTimestamp. For example,
 * the expected frame duration is 16.67 ms, and the frame took 20 ms to render. The frame delay is
 * 20 ms - 16.67 ms = 3.33 ms. Parts of the delay may occur before the queried time interval. For
 * example, of the 3.33 ms of a recorded frames delay only 2 ms intersect with the queried time
 * interval. In that case, the frames delay is only 2 ms. This method also considers when there is
 * no recorded frame information for the queried time interval, but there should be, meaning it
 * includes ongoing, not yet recorded frames as frames delay.
 *
 *
 * @param startSystemTimestamp The start system time stamp for the time interval to query frames
 * delay.
 * @param endSystemTimestamp The end system time stamp for the time interval to query frames delay.
 * @param isRunning Wether the frames tracker is running or not.
 * @param previousFrameSystemTimestamp The system timestamp of the previous frame.
 * @param slowFrameThreshold The threshold for a slow frame. For 60 fps this is roughly 16.67 ms.
 *
 * @return the frames delay duration or -1 if it can't calculate the frames delay.
 */
- (CFTimeInterval)getFramesDelay:(uint64_t)startSystemTimestamp
              endSystemTimestamp:(uint64_t)endSystemTimestamp
                       isRunning:(BOOL)isRunning
    previousFrameSystemTimestamp:(uint64_t)previousFrameSystemTimestamp
              slowFrameThreshold:(CFTimeInterval)slowFrameThreshold;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
