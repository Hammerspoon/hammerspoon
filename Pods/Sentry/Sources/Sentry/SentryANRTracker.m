#import "SentryANRTracker.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentrySwift.h"
#import "SentryThreadWrapper.h"
#import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryANRTrackerState) {
    kSentryANRTrackerNotRunning = 1,
    kSentryANRTrackerRunning,
    kSentryANRTrackerStarting,
    kSentryANRTrackerStopping
};

@interface
SentryANRTracker ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSHashTable<id<SentryANRTrackerDelegate>> *listeners;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end

@implementation SentryANRTracker {
    NSObject *threadLock;
    SentryANRTrackerState state;
}

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
{
    if (self = [super init]) {
        self.timeoutInterval = timeoutInterval;
        self.crashWrapper = crashWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.threadWrapper = threadWrapper;
        self.listeners = [NSHashTable weakObjectsHashTable];
        threadLock = [[NSObject alloc] init];
        state = kSentryANRTrackerNotRunning;
    }
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

    __block atomic_int ticksSinceUiUpdate = 0;
    __block BOOL reported = NO;

    NSInteger reportThreshold = 5;
    NSTimeInterval sleepInterval = self.timeoutInterval / reportThreshold;

    SentryCurrentDateProvider *dateProvider = SentryDependencyContainer.sharedInstance.dateProvider;

    // Canceling the thread can take up to sleepInterval.
    while (YES) {
        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        NSDate *blockDeadline = [[dateProvider date] dateByAddingTimeInterval:self.timeoutInterval];

        atomic_fetch_add_explicit(&ticksSinceUiUpdate, 1, memory_order_relaxed);

        [self.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
            atomic_store_explicit(&ticksSinceUiUpdate, 0, memory_order_relaxed);

            if (reported) {
                SENTRY_LOG_WARN(@"ANR stopped.");

                // The ANR stopped, don't block the main thread with calling ANRStopped listeners.
                // While the ANR code reports an ANR and collects the stack trace, the ANR might
                // stop simultaneously. In that case, the ANRs stack trace would contain the
                // following code running on the main thread. To avoid this, we offload work to a
                // background thread.
                [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{ [self ANRStopped]; }];
            }

            reported = NO;
        }];

        [self.threadWrapper sleepForTimeInterval:sleepInterval];

        // The blockDeadline should be roughly executed after the timeoutInterval even if there is
        // an ANR. If the app gets suspended this thread could sleep and wake up again. To avoid
        // false positives, we don't report ANRs if the delta is too big.
        NSTimeInterval deltaFromNowToBlockDeadline =
            [[dateProvider date] timeIntervalSinceDate:blockDeadline];

        if (deltaFromNowToBlockDeadline >= self.timeoutInterval) {
            SENTRY_LOG_DEBUG(
                @"Ignoring ANR because the delta is too big: %f.", deltaFromNowToBlockDeadline);
            continue;
        }

        if (atomic_load_explicit(&ticksSinceUiUpdate, memory_order_relaxed) >= reportThreshold
            && !reported) {
            reported = YES;

            if (![self.crashWrapper isApplicationInForeground]) {
                SENTRY_LOG_DEBUG(@"Ignoring ANR because the app is in the background");
                continue;
            }

            SENTRY_LOG_WARN(@"ANR detected.");
            [self ANRDetected];
        }
    }

    @synchronized(threadLock) {
        state = kSentryANRTrackerNotRunning;
        [self.threadWrapper threadFinished:threadID];
    }
}

- (void)ANRDetected
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerDelegate> target in localListeners) {
        [target anrDetected];
    }
}

- (void)ANRStopped
{
    NSArray *targets;
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerDelegate> target in targets) {
        [target anrStopped];
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
        SENTRY_LOG_INFO(@"Stopping ANR detection");
        state = kSentryANRTrackerStopping;
    }
}

@end

NS_ASSUME_NONNULL_END
