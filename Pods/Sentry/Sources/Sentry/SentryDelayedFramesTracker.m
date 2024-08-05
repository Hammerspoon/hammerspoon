#import "SentryDelayedFramesTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDelayedFrame.h"
#    import "SentryLog.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDelayedFramesTracker ()

@property (nonatomic, assign) CFTimeInterval keepDelayedFramesDuration;
@property (nonatomic, strong, readonly) SentryCurrentDateProvider *dateProvider;
@property (nonatomic, strong) NSMutableArray<SentryDelayedFrame *> *delayedFrames;

@end

@implementation SentryDelayedFramesTracker

- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(SentryCurrentDateProvider *)dateProvider
{
    if (self = [super init]) {
        _keepDelayedFramesDuration = keepDelayedFramesDuration;
        _dateProvider = dateProvider;
        [self resetDelayedFramesTimeStamps];
    }
    return self;
}

- (void)resetDelayedFramesTimeStamps
{
    _delayedFrames = [NSMutableArray array];
    SentryDelayedFrame *initialFrame =
        [[SentryDelayedFrame alloc] initWithStartTimestamp:[self.dateProvider systemTime]
                                          expectedDuration:0
                                            actualDuration:0];
    [_delayedFrames addObject:initialFrame];
}

- (void)recordDelayedFrame:(uint64_t)startSystemTimestamp
          expectedDuration:(CFTimeInterval)expectedDuration
            actualDuration:(CFTimeInterval)actualDuration
{
    @synchronized(self.delayedFrames) {
        [self removeOldDelayedFrames];

        SentryDelayedFrame *delayedFrame =
            [[SentryDelayedFrame alloc] initWithStartTimestamp:startSystemTimestamp
                                              expectedDuration:expectedDuration
                                                actualDuration:actualDuration];
        [self.delayedFrames addObject:delayedFrame];
    }
}

/**
 * Removes delayed frame that are older than current time minus `keepDelayedFramesDuration`.
 * @note Make sure to call this in a @synchronized block.
 */
- (void)removeOldDelayedFrames
{
    u_int64_t transactionMaxDurationNS = timeIntervalToNanoseconds(_keepDelayedFramesDuration);

    uint64_t removeFramesBeforeSystemTimeStamp
        = _dateProvider.systemTime - transactionMaxDurationNS;
    if (_dateProvider.systemTime < transactionMaxDurationNS) {
        removeFramesBeforeSystemTimeStamp = 0;
    }

    NSUInteger left = 0;
    NSUInteger right = self.delayedFrames.count;

    while (left < right) {
        NSUInteger mid = (left + right) / 2;
        SentryDelayedFrame *midFrame = self.delayedFrames[mid];

        uint64_t frameEndSystemTimeStamp
            = midFrame.startSystemTimestamp + timeIntervalToNanoseconds(midFrame.actualDuration);
        if (frameEndSystemTimeStamp >= removeFramesBeforeSystemTimeStamp) {
            right = mid;
        } else {
            left = mid + 1;
        }
    }

    [self.delayedFrames removeObjectsInRange:NSMakeRange(0, left)];
}

- (CFTimeInterval)getFramesDelay:(uint64_t)startSystemTimestamp
              endSystemTimestamp:(uint64_t)endSystemTimestamp
                       isRunning:(BOOL)isRunning
    previousFrameSystemTimestamp:(uint64_t)previousFrameSystemTimestamp
              slowFrameThreshold:(CFTimeInterval)slowFrameThreshold
{
    CFTimeInterval cantCalculateFrameDelayReturnValue = -1.0;

    if (isRunning == NO) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because frames tracker isn't running.");
        return cantCalculateFrameDelayReturnValue;
    }

    if (startSystemTimestamp >= endSystemTimestamp) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because startSystemTimestamp is before  "
                         @"endSystemTimestamp");
        return cantCalculateFrameDelayReturnValue;
    }

    if (endSystemTimestamp > self.dateProvider.systemTime) {
        SENTRY_LOG_DEBUG(
            @"Not calculating frames delay because endSystemTimestamp is in the future.");
        return cantCalculateFrameDelayReturnValue;
    }

    if (previousFrameSystemTimestamp == 0) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because no frames yet recorded.");
        return cantCalculateFrameDelayReturnValue;
    }

    NSMutableArray<SentryDelayedFrame *> *frames;
    @synchronized(self.delayedFrames) {
        uint64_t oldestDelayedFrameStartTimestamp = UINT64_MAX;
        SentryDelayedFrame *oldestDelayedFrame = self.delayedFrames.firstObject;
        if (oldestDelayedFrame != nil) {
            oldestDelayedFrameStartTimestamp = oldestDelayedFrame.startSystemTimestamp;
        }

        if (oldestDelayedFrameStartTimestamp > startSystemTimestamp) {
            SENTRY_LOG_DEBUG(@"Not calculating frames delay because the record of delayed frames "
                             @"doesn't go back enough in time.");
            return cantCalculateFrameDelayReturnValue;
        }

        // Copy as late as possible to avoid allocating unnecessary memory.
        frames = self.delayedFrames.mutableCopy;
    }

    // Add a delayed frame for a potentially ongoing but not recorded delayed frame
    SentryDelayedFrame *currentFrameDelay = [[SentryDelayedFrame alloc]
        initWithStartTimestamp:previousFrameSystemTimestamp
              expectedDuration:slowFrameThreshold
                actualDuration:nanosecondsToTimeInterval(
                                   endSystemTimestamp - previousFrameSystemTimestamp)];

    [frames addObject:currentFrameDelay];

    // We need to calculate the intersections of the queried TimestampInterval
    // (startSystemTimestamp - endSystemTimestamp) with the recorded frame delays. Doing that
    // with NSDateInterval makes things easier. Therefore, we convert the system timestamps to
    // NSDate objects, although they don't represent the correct dates. We only need to know how
    // long the intersections are to calculate the frame delay and not precisely when.

    NSDate *startDate = [NSDate
        dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(startSystemTimestamp)];
    NSDate *endDate = [NSDate
        dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(endSystemTimestamp)];
    NSDateInterval *queryDateInterval = [[NSDateInterval alloc] initWithStartDate:startDate
                                                                          endDate:endDate];

    CFTimeInterval delay = 0.0;

    // Iterate in reverse order, as younger frame delays are more likely to match the queried
    // period.
    for (SentryDelayedFrame *frame in frames.reverseObjectEnumerator) {

        uint64_t frameEndSystemTimeStamp
            = frame.startSystemTimestamp + timeIntervalToNanoseconds(frame.actualDuration);
        if (frameEndSystemTimeStamp < startSystemTimestamp) {
            break;
        }

        delay = delay + [self calculateDelay:frame queryDateInterval:queryDateInterval];
    }

    return delay;
}

- (CFTimeInterval)calculateDelay:(SentryDelayedFrame *)delayedFrame
               queryDateInterval:(NSDateInterval *)queryDateInterval
{
    CFTimeInterval delayStartTime = nanosecondsToTimeInterval(delayedFrame.startSystemTimestamp)
        + delayedFrame.expectedDuration;
    NSDate *frameDelayStartDate = [NSDate dateWithTimeIntervalSinceReferenceDate:delayStartTime];

    NSTimeInterval duration = delayedFrame.actualDuration - delayedFrame.expectedDuration;
    if (duration < 0) {
        return 0.0;
    }

    NSDateInterval *frameDelayDateInterval =
        [[NSDateInterval alloc] initWithStartDate:frameDelayStartDate duration:duration];

    if ([queryDateInterval intersectsDateInterval:frameDelayDateInterval]) {
        NSDateInterval *intersection =
            [queryDateInterval intersectionWithDateInterval:frameDelayDateInterval];
        return intersection.duration;
    } else {
        return 0.0;
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
