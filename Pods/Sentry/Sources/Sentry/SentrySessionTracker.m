#import "SentrySessionTracker.h"
#import "SentryClient+Private.h"
#import "SentryClient.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryInternalNotificationNames.h"
#import "SentryLog.h"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_MACOS_HAS_UI
#    import <Cocoa/Cocoa.h>
#endif

@interface
SentrySessionTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (atomic, strong) NSDate *lastInForeground;
@property (nonatomic, assign) BOOL wasDidBecomeActiveCalled;
@property (nonatomic, assign) BOOL subscribedToNotifications;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenter;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options
             notificationCenter:(SentryNSNotificationCenterWrapper *)notificationCenter;
{
    if (self = [super init]) {
        self.options = options;
        self.wasDidBecomeActiveCalled = NO;
        self.notificationCenter = notificationCenter;
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

#if SENTRY_HAS_UIKIT || SENTRY_TARGET_MACOS_HAS_UI

    // Call before subscribing to the notifications to avoid that didBecomeActive gets called before
    // ending the cached session.
    [self endCachedSession];

    [self.notificationCenter
        addObserver:self
           selector:@selector(didBecomeActive)
               name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName];

    [self.notificationCenter addObserver:self
                                selector:@selector(didBecomeActive)
                                    name:SentryHybridSdkDidBecomeActiveNotificationName];

    [self.notificationCenter
        addObserver:self
           selector:@selector(willResignActive)
               name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName];

    [self.notificationCenter
        addObserver:self
           selector:@selector(willTerminate)
               name:SentryNSNotificationCenterWrapper.willTerminateNotificationName];
#else
    SENTRY_LOG_DEBUG(@"NO UIKit -> SentrySessionTracker will not track sessions automatically.");
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT || SENTRY_TARGET_MACOS_HAS_UI
    // Remove the observers with the most specific detail possible, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [self.notificationCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName];
    [self.notificationCenter removeObserver:self
                                       name:SentryHybridSdkDidBecomeActiveNotificationName];
    [self.notificationCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName];
    [self.notificationCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.willTerminateNotificationName];
#endif
}

- (void)dealloc
{
    [self stop];
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [self.notificationCenter removeObserver:self];
}

/**
 * End previously cached sessions. We never can be sure that WillResignActive or WillTerminate are
 * called due to a crash or unexpected behavior. Still, we don't want to lose such sessions and end
 * them.
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
 * It is called when an App. is receiving events / It is in the foreground and when we receive a
 * @c SentryHybridSdkDidBecomeActiveNotification. There is no guarantee that this method is called
 * once or twice. We need to ensure that we execute it only once.
 * @discussion This also works when using SwiftUI or Scenes, as UIKit posts a
 * @c didBecomeActiveNotification regardless of whether your app uses scenes, see
 * https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622956-applicationdidbecomeactive.
 * @warning Hybrid SDKs must only post this notification if they are running in the foreground
 * because the auto session tracking logic doesn't support background tasks. Posting the
 * notification from the background would mess up the session stats. Hybrid SDKs must only post this
 * notification if they are running in the foreground because the auto session tracking logic
 * doesn't support background tasks. Posting the notification from the background would mess up the
 * session stats.
 */
- (void)didBecomeActive
{
    // We don't know if the hybrid SDKs post the notification from a background thread, so we
    // synchronize to be safe.
    @synchronized(self) {
        if (self.wasDidBecomeActiveCalled) {
            return;
        }
        self.wasDidBecomeActiveCalled = YES;
    }

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
            [[SentryDependencyContainer.sharedInstance.dateProvider date]
                timeIntervalSinceDate:self.lastInForeground];

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
    self.lastInForeground = [SentryDependencyContainer.sharedInstance.dateProvider date];
    SentryHub *hub = [SentrySDK currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
    self.wasDidBecomeActiveCalled = NO;
}

/**
 * We always end the session when the app is terminated.
 */
- (void)willTerminate
{
    NSDate *sessionEnded = nil == self.lastInForeground
        ? [SentryDependencyContainer.sharedInstance.dateProvider date]
        : self.lastInForeground;
    SentryHub *hub = [SentrySDK currentHub];
    [hub endSessionWithTimestamp:sessionEnded];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    self.wasDidBecomeActiveCalled = NO;
}

@end
