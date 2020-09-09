#import "SentrySessionTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

@interface
SentrySessionTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (atomic, strong) NSDate *lastInForeground;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.options = options;
        self.currentDateProvider = currentDateProvider;
    }
    return self;
}

/**
 * Can also be called when the system launches an app for a background task. We don't want to track
 * sessions if an app is only in the background. Therefore we must not start a session in here. Such
 * apps must do session tracking manually, see
 * https://docs.sentry.io/workflow/releases/health/#session
 */
- (void)start
{
    // We don't want to use WillEnterForeground because tvOS doesn't call it when it launches an app
    // the first time. It only calls it when the app was open and the user navigates back to it.
    // DidEnterBackground is called when the app launches a background task so we would need to
    // check if DidBecomeActive was called before to not track sessions in the background.
    // DidBecomeActive and WillResignActive are not called when the app launches a background task.
    // WillTerminate is called no matter if started from the background or launched into the
    // foreground.

#if SENTRY_HAS_UIKIT
    NSNotificationName didBecomeActiveNotificationName = UIApplicationDidBecomeActiveNotification;
    NSNotificationName willResignActiveNotificationName = UIApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotificationName = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName didBecomeActiveNotificationName = NSApplicationDidBecomeActiveNotification;
    NSNotificationName willResignActiveNotificationName = NSApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotificationName = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
                              @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST

    // Call before subscribing to the notifications to avoid that didBecomeActive gets called before
    // ending the cached session.
    [self endCachedSession];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:didBecomeActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willResignActive)
                                               name:willResignActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willTerminate)
                                               name:willTerminateNotificationName
                                             object:nil];
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    [NSNotificationCenter.defaultCenter removeObserver:self];
#endif
}

/**
 * End previously cached sessions. We never can be sure that WillResignActive or WillTerminate
 are called due to a crash or unexpected behavior. Still, we don't want to lose such sessions and
 end them.
 */
- (void)endCachedSession
{
    SentryHub *hub = [SentrySDK currentHub];
    NSDate *_Nullable lastInForeground =
        [[[hub getClient] fileManager] readTimestampLastInForeground];
    if (nil != lastInForeground) {
        [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    }

    [hub closeCachedSessionWithTimestamp:lastInForeground];
}

/**
 * Is only called when an app is receiving events / it is in the foreground.
 */
- (void)didBecomeActive
{
    SentryHub *hub = [SentrySDK currentHub];
    self.lastInForeground = [[[hub getClient] fileManager] readTimestampLastInForeground];

    if (nil == self.lastInForeground) {
        // Cause we don't want to track sessions if the app is in the background we need to wait
        // until the app is in the foreground to start a session.
        [hub startSession];
    } else {
        // When the app was already in the foreground we have to decide whether it was long enough
        // in the background to start a new session or to keep the session open. We don't want a new
        // session if the user switches to another app for just a few seconds.
        NSTimeInterval secondsInBackground =
            [[self.currentDateProvider date] timeIntervalSinceDate:self.lastInForeground];

        if (secondsInBackground * 1000 >= (double)(self.options.sessionTrackingIntervalMillis)) {
            [hub endSessionWithTimestamp:self.lastInForeground];
            [hub startSession];
        }
    }
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    self.lastInForeground = nil;
}

/**
 * The app is about to lose focus / going to the background. This is only called when an app was
 * receiving events / was is in the foreground. We can't end a session here because we don't how
 * long the app is going to be in the background. If it is just for a few seconds we want to keep
 * the session open.
 */
- (void)willResignActive
{
    self.lastInForeground = [self.currentDateProvider date];
    SentryHub *hub = [SentrySDK currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
}

/**
 * We always end the session when the app is terminated.
 */
- (void)willTerminate
{
    NSDate *sessionEnded
        = nil == self.lastInForeground ? [self.currentDateProvider date] : self.lastInForeground;
    SentryHub *hub = [SentrySDK currentHub];
    [hub endSessionWithTimestamp:sessionEnded];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

@end
