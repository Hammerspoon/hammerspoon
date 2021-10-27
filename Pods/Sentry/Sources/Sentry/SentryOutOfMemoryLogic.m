#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryCrashAdapter.h>
#import <SentryOptions.h>
#import <SentryOutOfMemoryLogic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@interface
SentryOutOfMemoryLogic ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;

@end

@implementation SentryOutOfMemoryLogic

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
                appStateManager:(SentryAppStateManager *)appStateManager
{
    if (self = [super init]) {
        self.options = options;
        self.crashAdapter = crashAdatper;
        self.appStateManager = appStateManager;
    }
    return self;
}

- (BOOL)isOOM
{
    if (!self.options.enableOutOfMemoryTracking) {
        return NO;
    }

#if SENTRY_HAS_UIKIT
    SentryAppState *previousAppState = [self.appStateManager loadCurrentAppState];
    SentryAppState *currentAppState = [self.appStateManager buildCurrentAppState];

    // If there is no previous app state, we can't do anything.
    if (nil == previousAppState) {
        return NO;
    }

    // If the release name is different we assume it's an upgrade
    if (![currentAppState.releaseName isEqualToString:previousAppState.releaseName]) {
        return NO;
    }

    // The OS was upgraded
    if (![currentAppState.osVersion isEqualToString:previousAppState.osVersion]) {
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

    // The app crashed on the previous run. No OOM.
    if (self.crashAdapter.crashedLastLaunch) {
        return NO;
    }

    // Was the app in foreground/active ?
    // If the app was in background we can't reliably tell if it was an OOM or not.
    if (!previousAppState.isActive) {
        return NO;
    }

    return YES;
#else
    // We can only track OOMs for iOS, tvOS and macCatalyst. Therefore we return NO for other
    // platforms.
    return NO;
#endif
}

@end
