#import "SentryANRTrackerV2.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCrashWrapper.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFramesTracker.h"
#    import "SentryLogC.h"
#    import "SentrySwift.h"
#    import "SentryThreadWrapper.h"
#    import "SentryTime.h"
#    import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryANRTrackerState) {
    kSentryANRTrackerNotRunning = 1,
    kSentryANRTrackerRunning,
    kSentryANRTrackerStarting,
    kSentryANRTrackerStopping
};

@interface SentryANRTrackerV2 () <SentryANRTracker>

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSHashTable<id<SentryANRTrackerDelegate>> *listeners;
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end

@implementation SentryANRTrackerV2 {
    NSObject *threadLock;
    SentryANRTrackerState state;
}

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
                          framesTracker:(SentryFramesTracker *)framesTracker
{
    if (self = [super init]) {
        self.timeoutInterval = timeoutInterval;
        self.crashWrapper = crashWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.threadWrapper = threadWrapper;
        self.framesTracker = framesTracker;
        self.listeners = [NSHashTable weakObjectsHashTable];
        threadLock = [[NSObject alloc] init];
        state = kSentryANRTrackerNotRunning;
    }
    return self;
}

- (id<SentryANRTracker>)asProtocol
{
    return self;
}

- (void)detectANRs
{
    NSUUID *threadID = [NSUUID UUID];

    @synchronized(threadLock) {
        [self.threadWrapper threadStarted:threadID];

        if (state != kSentryANRTrackerStarting) {
            [self.threadWrapper threadFinished:threadID];
            return;
        }

        NSThread.currentThread.name = @"io.sentry.app-hang-tracker";
        state = kSentryANRTrackerRunning;
    }

    id<SentryCurrentDateProvider> dateProvider
        = SentryDependencyContainer.sharedInstance.dateProvider;

    BOOL reported = NO;

    NSInteger reportThreshold = 5;
    NSTimeInterval sleepInterval = self.timeoutInterval / reportThreshold;
    uint64_t sleepIntervalInNanos = timeIntervalToNanoseconds(sleepInterval);
    uint64_t timeoutIntervalInNanos = timeIntervalToNanoseconds(self.timeoutInterval);

    uint64_t appHangStoppedInterval = timeIntervalToNanoseconds(sleepInterval * 2);
    CFTimeInterval appHangStoppedFrameDelayThreshold
        = nanosecondsToTimeInterval(appHangStoppedInterval) * 0.2;

    uint64_t lastAppHangStoppedSystemTime = dateProvider.systemTime - timeoutIntervalInNanos;
    uint64_t lastAppHangStartedSystemTime = 0;

    // Canceling the thread can take up to sleepInterval.
    while (YES) {
        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        NSDate *sleepDeadline = [[dateProvider date] dateByAddingTimeInterval:self.timeoutInterval];

        [self.threadWrapper sleepForTimeInterval:sleepInterval];

        if (![self.crashWrapper isApplicationInForeground]) {
            SENTRY_LOG_DEBUG(@"Ignoring potential app hangs because the app is in the background");
            continue;
        }

        // The sleepDeadline should be roughly executed after the timeoutInterval even if there is
        // an AppHang. If the app gets suspended this thread could sleep and wake up again. To avoid
        // false positives, we don't report AppHangs if the delta is too big.
        NSTimeInterval deltaFromNowToSleepDeadline =
            [[dateProvider date] timeIntervalSinceDate:sleepDeadline];

        if (deltaFromNowToSleepDeadline >= self.timeoutInterval) {
            SENTRY_LOG_DEBUG(@"Ignoring App Hang because the delta is too big: %f.",
                deltaFromNowToSleepDeadline);
            continue;
        }

        uint64_t nowSystemTime = dateProvider.systemTime;

        if (reported) {

            uint64_t framesDelayStartSystemTime = nowSystemTime - appHangStoppedInterval;

            SentryFramesDelayResult *framesDelay =
                [self.framesTracker getFramesDelay:framesDelayStartSystemTime
                                endSystemTimestamp:nowSystemTime];

            if (framesDelay.delayDuration == -1) {
                continue;
            }

            BOOL appHangStopped = framesDelay.delayDuration < appHangStoppedFrameDelayThreshold;

            if (appHangStopped) {
                SENTRY_LOG_DEBUG(@"App hang stopped.");

                // As we check every sleepInterval if the app is hanging, the app could already be
                // hanging for almost the sleepInterval until we detect it and it could already
                // stopped hanging almost a sleepInterval until we again detect it's not.
                uint64_t appHangDurationNanos
                    = timeoutIntervalInNanos + nowSystemTime - lastAppHangStartedSystemTime;
                NSTimeInterval appHangDurationMinimum
                    = nanosecondsToTimeInterval(appHangDurationNanos - sleepIntervalInNanos);
                NSTimeInterval appHangDurationMaximum
                    = nanosecondsToTimeInterval(appHangDurationNanos + sleepIntervalInNanos);

                // The App Hang stopped, don't block the App Hangs thread or the main thread with
                // calling ANRStopped listeners.
                [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
                    [self ANRStopped:appHangDurationMinimum to:appHangDurationMaximum];
                }];

                lastAppHangStoppedSystemTime = dateProvider.systemTime;
                reported = NO;
            }

            continue;
        }

        uint64_t lastAppHangLongEnoughInPastThreshold
            = lastAppHangStoppedSystemTime + timeoutIntervalInNanos;

        if (dateProvider.systemTime < lastAppHangLongEnoughInPastThreshold) {
            SENTRY_LOG_DEBUG(@"Ignoring app hang cause one happened recently.");
            continue;
        }

        uint64_t frameDelayStartSystemTime = nowSystemTime - timeoutIntervalInNanos;

        SentryFramesDelayResult *framesDelayForTimeInterval =
            [self.framesTracker getFramesDelay:frameDelayStartSystemTime
                            endSystemTimestamp:nowSystemTime];

        if (framesDelayForTimeInterval.delayDuration == -1) {
            continue;
        }

        uint64_t framesDelayForTimeIntervalInNanos
            = timeIntervalToNanoseconds(framesDelayForTimeInterval.delayDuration);

        BOOL isFullyBlocking = framesDelayForTimeInterval.framesContributingToDelayCount == 1;

        if (isFullyBlocking && framesDelayForTimeIntervalInNanos >= timeoutIntervalInNanos) {
            SENTRY_LOG_WARN(@"App Hang detected: fully-blocking.");

            reported = YES;
            lastAppHangStartedSystemTime = dateProvider.systemTime;
            [self ANRDetected:SentryANRTypeFullyBlocking];
        }

        NSTimeInterval nonFullyBlockingFramesDelayThreshold = self.timeoutInterval * 0.99;
        if (!isFullyBlocking
            && framesDelayForTimeInterval.delayDuration > nonFullyBlockingFramesDelayThreshold) {

            SENTRY_LOG_WARN(@"App Hang detected: non-fully-blocking.");

            reported = YES;
            lastAppHangStartedSystemTime = dateProvider.systemTime;
            [self ANRDetected:SentryANRTypeNonFullyBlocking];
        }
    }

    @synchronized(threadLock) {
        state = kSentryANRTrackerNotRunning;
        [self.threadWrapper threadFinished:threadID];
    }
}

- (void)ANRDetected:(enum SentryANRType)type
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerDelegate> target in localListeners) {
        [target anrDetectedWithType:type];
    }
}

- (void)ANRStopped:(NSTimeInterval)hangDurationMinimum to:(NSTimeInterval)hangDurationMaximum
{
    NSArray *targets;
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    SentryANRStoppedResult *result =
        [[SentryANRStoppedResult alloc] initWithMinDuration:hangDurationMinimum
                                                maxDuration:hangDurationMaximum];
    for (id<SentryANRTrackerDelegate> target in targets) {
        [target anrStoppedWithResult:result];
    }
}

- (void)addListener:(id<SentryANRTrackerDelegate>)listener
{
    @synchronized(self.listeners) {
        [self.listeners addObject:listener];

        @synchronized(threadLock) {
            if (self.listeners.count > 0 && state == kSentryANRTrackerNotRunning) {
                if (state == kSentryANRTrackerNotRunning) {
                    state = kSentryANRTrackerStarting;
                    [NSThread detachNewThreadSelector:@selector(detectANRs)
                                             toTarget:self
                                           withObject:nil];
                }
            }
        }
    }
}

- (void)removeListener:(id<SentryANRTrackerDelegate>)listener
{
    @synchronized(self.listeners) {
        [self.listeners removeObject:listener];

        if (self.listeners.count == 0) {
            [self stop];
        }
    }
}

- (void)clear
{
    @synchronized(self.listeners) {
        [self.listeners removeAllObjects];
        [self stop];
    }
}

- (void)stop
{
    @synchronized(threadLock) {
        SENTRY_LOG_INFO(@"Stopping App Hang detection");
        state = kSentryANRTrackerStopping;
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
