#import "SentrySDK+Private.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryClient+Private.h>
#import <SentryCrashAdapter.h>
#import <SentryFileManager.h>
#import <SentryHub.h>
#import <SentryOptions.h>
#import <SentryOutOfMemoryLogic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@interface
SentryOutOfMemoryLogic ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;

@end

@implementation SentryOutOfMemoryLogic : NSObject

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
{
    if (self = [super init]) {
        self.options = options;
        self.crashAdapter = crashAdatper;
    }
    return self;
}

- (BOOL)isOOM
{
    if (!self.options.enableOutOfMemoryTracking) {
        return NO;
    }

#if SENTRY_HAS_UIKIT
    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppState *previousAppState = [fileManager readAppState];

    SentryAppState *currentAppState = [self buildCurrentAppState];

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

#if SENTRY_HAS_UIKIT
- (SentryAppState *)buildCurrentAppState
{
    // Is the current process being traced or not? If it is a debugger is attached.
    bool isDebugging = self.crashAdapter.isBeingTraced;

    return [[SentryAppState alloc] initWithReleaseName:self.options.releaseName
                                             osVersion:UIDevice.currentDevice.systemVersion
                                           isDebugging:isDebugging];
}
#endif

@end
