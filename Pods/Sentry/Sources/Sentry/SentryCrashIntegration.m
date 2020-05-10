#import "SentryCrashIntegration.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentryGlobalEventProcessor.h"
#import "SentrySDK.h"
#import "SentryScope.h"
#import "SentryScope+Private.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

static SentryCrashInstallationReporter *installation = nil;

@interface SentryCrashIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryCrashIntegration

/**
 * Wrapper for `SentryCrash.sharedInstance.systemInfo`, to cash the result.
 *
 * @return NSDictionary system info.
 */
+ (NSDictionary *)systemInfo {
    static NSDictionary *sharedInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInfo = SentryCrash.sharedInstance.systemInfo;
    });
    return sharedInfo;
}

- (void)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self startCrashHandler];
    [self configureScope];
}

- (void)startCrashHandler {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[SentryCrashInstallationReporter alloc] init];
        [installation install];
        [installation sendAllReports];
    });
}

- (void)configureScope {
    // We need to make sure to set always the scope to KSCrash so we have it in case of a crash
    NSString *integrationName = NSStringFromClass(SentryCrashIntegration.class);
    if (nil != [SentrySDK.currentHub getIntegration:integrationName]) {
        [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull outerScope) {
            // OS
            NSMutableDictionary *osData = [NSMutableDictionary new];

            #if TARGET_OS_OSX || TARGET_OS_MACCATALYST
            [osData setValue:@"macOS" forKey:@"name"];
            #elif TARGET_OS_IOS
            [osData setValue:@"iOS" forKey:@"name"];
            #elif TARGET_OS_TV
            [osData setValue:@"tvOS" forKey:@"name"];
            #elif TARGET_OS_WATCH
            [osData setValue:@"watchOS" forKey:@"name"];
            #endif

            #if SENTRY_HAS_UIDEVICE
            [osData setValue:[UIDevice currentDevice].systemVersion forKey:@"version"];
            #else
            NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
            NSString *systemVersion = [NSString stringWithFormat:@"%d.%d.%d", (int) version.majorVersion, (int) version.minorVersion, (int) version.patchVersion];
            [osData setValue:systemVersion forKey:@"version"];
            #endif

            NSDictionary *systemInfo = [SentryCrashIntegration systemInfo];
            [osData setValue:systemInfo[@"osVersion"] forKey:@"build"];
            [osData setValue:systemInfo[@"kernelVersion"] forKey:@"kernel_version"];
            [osData setValue:systemInfo[@"isJailbroken"] forKey:@"rooted"];

            [outerScope setContextValue:osData forKey:@"os"];

            // DEVICE

            NSMutableDictionary *deviceData = [NSMutableDictionary new];

            #if TARGET_OS_SIMULATOR
            [deviceData setValue:@(YES) forKey:@"simulator"];
            #endif

            NSString *family = [[systemInfo[@"systemName"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];

            [deviceData setValue:family forKey:@"family"];
            [deviceData setValue:systemInfo[@"cpuArchitecture"] forKey:@"arch"];
            [deviceData setValue:systemInfo[@"machine"] forKey:@"model"];
            [deviceData setValue:systemInfo[@"model"] forKey:@"model_id"];
            [deviceData setValue:systemInfo[@"freeMemory"] forKey:@"free_memory"];
            [deviceData setValue:systemInfo[@"usableMemory"] forKey:@"usable_memory"];
            [deviceData setValue:systemInfo[@"memorySize"] forKey:@"memory_size"];
            [deviceData setValue:systemInfo[@"storageSize"] forKey:@"storage_size"];
            [deviceData setValue:systemInfo[@"bootTime"] forKey:@"boot_time"];
            [deviceData setValue:systemInfo[@"timezone"] forKey:@"timezone"];

            [outerScope setContextValue:deviceData forKey:@"device"];

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

            [outerScope setContextValue:appData forKey:@"app"];
            
            [outerScope addScopeListener:^(SentryScope * _Nonnull scope) {
                [SentryCrash.sharedInstance setUserInfo:[scope serialize]];
            }];
        }];
    }
}

@end
