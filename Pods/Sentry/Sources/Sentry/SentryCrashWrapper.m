#import "SentryCrashWrapper.h"
#import "SentryCrash.h"
#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashMonitor_AppState.h"
#import "SentryCrashMonitor_System.h"
#import "SentryScope.h"
#import <Foundation/Foundation.h>
#import <SentryCrashCachedData.h>
#import <SentryCrashDebug.h>
#import <SentryCrashMonitor_System.h>
#import <SentryDependencyContainer.h>
#include <mach/mach.h>

#if SENTRY_HAS_UIKIT
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>
#endif

static NSString *const DEVICE_KEY = @"device";
static NSString *const LOCALE_KEY = @"locale";

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashWrapper

+ (instancetype)sharedInstance
{
    static SentryCrashWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        sentrycrashcm_system_getAPI()->setEnabled(YES);
    }
    return self;
}

- (BOOL)crashedLastLaunch
{
    return SentryDependencyContainer.sharedInstance.crashReporter.crashedLastLaunch;
}

- (NSTimeInterval)durationFromCrashStateInitToLastCrash
{
    return sentrycrashstate_currentState()->durationFromCrashStateInitToLastCrash;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryDependencyContainer.sharedInstance.crashReporter.activeDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return sentrycrashdebug_isBeingTraced();
}

- (BOOL)isSimulatorBuild
{
    return sentrycrash_isSimulatorBuild();
}

- (BOOL)isApplicationInForeground
{
    return sentrycrashstate_currentState()->applicationIsInForeground;
}

- (NSDictionary *)systemInfo
{
    static NSDictionary *sharedInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
        ^{ sharedInfo = SentryDependencyContainer.sharedInstance.crashReporter.systemInfo; });
    return sharedInfo;
}

- (bytes)freeMemorySize
{
    return sentrycrashcm_system_freememory_size();
}

- (bytes)appMemorySize
{
    task_vm_info_data_t info;
    mach_msg_type_number_t size = TASK_VM_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.internal + info.compressed;
    }

    return 0;
}

- (void)startBinaryImageCache
{
    sentrycrashbic_startCache();
}

- (void)stopBinaryImageCache
{
    sentrycrashbic_stopCache();
}

- (void)enrichScope:(SentryScope *)scope
{
    // OS
    NSMutableDictionary *osData = [NSMutableDictionary new];

#if SENTRY_TARGET_MACOS
    [osData setValue:@"macOS" forKey:@"name"];
#elif TARGET_OS_IOS
    [osData setValue:@"iOS" forKey:@"name"];
#elif TARGET_OS_TV
    [osData setValue:@"tvOS" forKey:@"name"];
#elif TARGET_OS_WATCH
    [osData setValue:@"watchOS" forKey:@"name"];
#elif TARGET_OS_VISION
    [osData setValue:@"visionOS" forKey:@"name"];
#endif

    // For MacCatalyst the UIDevice returns the current version of MacCatalyst and not the
    // macOSVersion. Therefore we have to use NSProcessInfo.
#if SENTRY_HAS_UIKIT && !TARGET_OS_MACCATALYST
    [osData setValue:[UIDevice currentDevice].systemVersion forKey:@"version"];
#else
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    NSString *systemVersion = [NSString stringWithFormat:@"%d.%d.%d", (int)version.majorVersion,
                                        (int)version.minorVersion, (int)version.patchVersion];
    [osData setValue:systemVersion forKey:@"version"];

#endif

    NSDictionary *systemInfo = [self systemInfo];

    // SystemInfo should only be nil when SentryCrash has not been installed
    if (systemInfo != nil && systemInfo.count != 0) {
        [osData setValue:systemInfo[@"osVersion"] forKey:@"build"];
        [osData setValue:systemInfo[@"kernelVersion"] forKey:@"kernel_version"];
        [osData setValue:systemInfo[@"isJailbroken"] forKey:@"rooted"];
    }

    [scope setContextValue:osData forKey:@"os"];

    // SystemInfo should only be nil when SentryCrash has not been installed
    if (systemInfo == nil || systemInfo.count == 0) {
        return;
    }

    // DEVICE

    NSMutableDictionary *deviceData = [NSMutableDictionary new];

#if TARGET_OS_SIMULATOR
    [deviceData setValue:@(YES) forKey:@"simulator"];
#else
    [deviceData setValue:@(NO) forKey:@"simulator"];
#endif

    NSString *family = [[systemInfo[@"systemName"]
        componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];

#if TARGET_OS_MACCATALYST
    // This would be iOS. Set it to macOS instead.
    family = @"macOS";
#endif

    [deviceData setValue:family forKey:@"family"];
    [deviceData setValue:systemInfo[@"cpuArchitecture"] forKey:@"arch"];
    [deviceData setValue:systemInfo[@"machine"] forKey:@"model"];
    [deviceData setValue:systemInfo[@"model"] forKey:@"model_id"];
    [deviceData setValue:systemInfo[@"freeMemorySize"] forKey:SentryDeviceContextFreeMemoryKey];
    [deviceData setValue:systemInfo[@"usableMemorySize"] forKey:@"usable_memory"];
    [deviceData setValue:systemInfo[@"memorySize"] forKey:@"memory_size"];

    NSString *locale = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleIdentifier];
    [deviceData setValue:locale forKey:LOCALE_KEY];

// The UIWindowScene is unavailable on visionOS
#if SENTRY_TARGET_REPLAY_SUPPORTED

    NSArray<UIWindow *> *appWindows = SentryDependencyContainer.sharedInstance.application.windows;
    if ([appWindows count] > 0) {
        UIScreen *appScreen = appWindows.firstObject.screen;
        if (appScreen != nil) {
            [deviceData setValue:@(appScreen.bounds.size.height) forKey:@"screen_height_pixels"];
            [deviceData setValue:@(appScreen.bounds.size.width) forKey:@"screen_width_pixels"];
        }
    }

#endif

    [scope setContextValue:deviceData forKey:DEVICE_KEY];

    // APP
    NSMutableDictionary *appData = [NSMutableDictionary new];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];

    [appData setValue:infoDict[@"CFBundleIdentifier"] forKey:@"app_identifier"];
    [appData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];
    [appData setValue:infoDict[@"CFBundleVersion"] forKey:@"app_build"];
    [appData setValue:infoDict[@"CFBundleShortVersionString"] forKey:@"app_version"];

    [appData setValue:systemInfo[@"appStartTime"] forKey:@"app_start_time"];
    [appData setValue:systemInfo[@"deviceAppHash"] forKey:@"device_app_hash"];
    [appData setValue:systemInfo[@"appID"] forKey:@"app_id"];
    [appData setValue:systemInfo[@"buildType"] forKey:@"build_type"];

    [scope setContextValue:appData forKey:@"app"];
}

@end

NS_ASSUME_NONNULL_END
