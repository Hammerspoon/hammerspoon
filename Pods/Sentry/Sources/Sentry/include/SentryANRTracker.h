#import "SentryDefines.h"

@class SentryOptions, SentryCrashWrapper, SentryDispatchQueueWrapper, SentryThreadWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryANRTrackerDelegate;

/**
 * This class detects ANRs with a dedicated watchdog thread. The thread schedules a simple block to
 * run on the main thread, sleeps for the configured timeout interval, and checks if the main thread
 * executed this block.
 * @discussion We decided against using a @c CFRunLoopObserver or the @c CADisplayLink, which the
 * @c SentryFramesTracker already uses, because they come with two disadvantages. First, the
 * solution is expensive. Quick benchmarks showed that hooking into the main thread's run loop and
 * checking for every event to process if the main thread executes it in time added around 0,5 % of
 * CPU overhead. Furthermore, if the main thread runs all scheduled events in time, it doesn't mean
 * that there is no ANR ongoing. It could be that the run loop of the main thread is busy for 20
 * seconds, and it executes all events in time. Instead, what matters is how long the main thread
 * needs to execute a newly added event to the run loop.
 */
@interface SentryANRTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper;

- (void)addListener:(id<SentryANRTrackerDelegate>)listener;

- (void)removeListener:(id<SentryANRTrackerDelegate>)listener;

// Function used for tests
- (void)clear;

@end

/**
 * The ``SentryANRTracker`` calls the methods from background threads.
 */
@protocol SentryANRTrackerDelegate <NSObject>

- (void)anrDetected;

- (void)anrStopped;

@end

NS_ASSUME_NONNULL_END
