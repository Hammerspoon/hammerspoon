#import <SentryWatchdogTerminationLogic.h>

#if SENTRY_HAS_UIKIT

#    import <Foundation/Foundation.h>
#    import <SentryAppState.h>
#    import <SentryAppStateManager.h>
#    import <SentryCrashWrapper.h>
#    import <SentryOptions.h>
#    import <SentrySDK+Private.h>

@interface
SentryWatchdogTerminationLogic ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashWrapper *crashAdapter;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;

@end

@implementation SentryWatchdogTerminationLogic

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashWrapper *)crashAdapter
                appStateManager:(SentryAppStateManager *)appStateManager
{
    if (self = [super init]) {
        self.options = options;
        self.crashAdapter = crashAdapter;
        self.appStateManager = appStateManager;
    }
    return self;
}

- (BOOL)isWatchdogTermination
{
    if (!self.options.enableWatchdogTerminationTracking) {
        return NO;
    }

    SentryAppState *previousAppState = [self.appStateManager loadPreviousAppState];
    SentryAppState *currentAppState = [self.appStateManager buildCurrentAppState];

    // If there is no previous app state, we can't do anything.
    if (previousAppState == nil) {
        return NO;
    }

    if (self.crashAdapter.isSimulatorBuild) {
        return NO;
    }

    // If the release name is different we assume it's an upgrade
    if (currentAppState.releaseName != nil && previousAppState.releaseName != nil
        && ![currentAppState.releaseName isEqualToString:previousAppState.releaseName]) {
        return NO;
    }

    // The OS was upgraded
    if (![currentAppState.osVersion isEqualToString:previousAppState.osVersion]) {
        return NO;
    }

    // The app may have been terminated due to device reboot
    if (previousAppState.systemBootTimestamp != currentAppState.systemBootTimestamp) {
        return NO;
    }

    // This value can change when installing test builds using Xcode or when installing an app
    // on a device using ad-hoc distribution.
    if (![currentAppState.vendorId isEqualToString:previousAppState.vendorId]) {
        return NO;
    }

    // Restarting the app in development is a termination we can't catch and would falsely
    // report OOMs.
    if (previousAppState.isDebugging) {
        return NO;
    }

    // The app was terminated normally
    if (previousAppState.wasTerminated) {
        return NO;
    }

    // The app crashed on the previous run. No Watchdog Termination.
    if (self.crashAdapter.crashedLastLaunch) {
        return NO;
    }

    // The SDK wasn't running, so *any* crash after the SDK got closed would be seen as a Watchdog
    // Termination.
    if (!previousAppState.isSDKRunning) {
        return NO;
    }

    // Was the app in foreground/active ?
    // If the app was in background we can't reliably tell if it was a Watchdog Termination or not.
    if (!previousAppState.isActive) {
        return NO;
    }

    if (previousAppState.isANROngoing) {
        return NO;
    }

    // When calling SentrySDK.start twice we would wrongly report a Watchdog Termination. We can
    // only report a Watchdog Termination when the SDK is started the first time.
    if (SentrySDK.startInvocations != 1) {
        return NO;
    }

    return YES;
}

@end

#endif // SENTRY_HAS_UIKIT
