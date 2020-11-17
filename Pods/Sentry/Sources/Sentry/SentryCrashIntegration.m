#import "SentryCrashIntegration.h"
#import "SentryCrashAdapter.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentryScope+Private.h"
#import "SentrySessionCrashedHandler.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

static SentryCrashInstallationReporter *installation = nil;

@interface
SentryCrashIntegration ()

@property (nonatomic, weak) SentryOptions *options;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentrySessionCrashedHandler *crashedSessionHandler;

@end

@implementation SentryCrashIntegration

- (instancetype)init
{
    if (self = [super init]) {
        SentryCrashAdapter *crashWrapper = [[SentryCrashAdapter alloc] init];
        self.dispatchQueueWrapper = [[SentryDispatchQueueWrapper alloc] init];
        self.crashedSessionHandler =
            [[SentrySessionCrashedHandler alloc] initWithCrashWrapper:crashWrapper];
    }
    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithCrashWrapper:(SentryCrashAdapter *)crashWrapper
             andDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    self = [self init];
    self.dispatchQueueWrapper = dispatchQueueWrapper;
    self.crashedSessionHandler =
        [[SentrySessionCrashedHandler alloc] initWithCrashWrapper:crashWrapper];

    return self;
}

/**
 * Wrapper for `SentryCrash.sharedInstance.systemInfo`, to cash the result.
 *
 * @return NSDictionary system info.
 */
+ (NSDictionary *)systemInfo
{
    static NSDictionary *sharedInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInfo = SentryCrash.sharedInstance.systemInfo; });
    return sharedInfo;
}

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self startCrashHandler];
    [self configureScope];
}

- (void)startCrashHandler
{
    static dispatch_once_t onceToken = 0;
    void (^block)(void) = ^{
        installation = [[SentryCrashInstallationReporter alloc] init];
        [installation install];

        // We need to send the crashed event together with the crashed session in the same envelope
        // to have proper statistics in release health. To achieve this we need both synchronously
        // in the hub. The crashed event is converted from a SentryCrashReport to an event in
        // SentryCrashReportSink and then passed to the SDK on a background thread. This process is
        // started with installing this integration. We need to end and delete the previous session
        // before being able to start a new session for the AutoSessionTrackingIntegration. The
        // SentryCrashIntegration is installed before the AutoSessionTrackingIntegration so there is
        // no guarantee if the crashed event is created before or after the
        // AutoSessionTrackingIntegration. By ending the previous session and storing it as crashed
        // in here we have the guarantee once the crashed event is sent to the hub it is already
        // there and the AutoSessionTrackingIntegration can work properly.
        //
        // This is a pragmatic and not the most optimal place for this logic.
        [self.crashedSessionHandler endCurrentSessionAsCrashedWhenCrashed];

        [installation sendAllReports];
    };
    [self.dispatchQueueWrapper dispatchOnce:&onceToken block:block];
}

- (void)configureScope
{
    // We need to make sure to set always the scope to KSCrash so we have it in
    // case of a crash
    NSString *integrationName = NSStringFromClass(SentryCrashIntegration.class);
    if (nil != [SentrySDK.currentHub getIntegration:integrationName]) {
        [SentrySDK.currentHub configureScope:^(SentryScope *_Nonnull outerScope) {
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

            NSString *family = [[systemInfo[@"systemName"]
                componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                firstObject];

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

            [outerScope addScopeListener:^(SentryScope *_Nonnull scope) {
                // The serialization of the scope and synching it to SentryCrash can use quite some
                // CPU time. We want to make sure that this doesn't happen on the main thread. We
                // accept the tradeoff that in case of a crash the scope might not be 100% up to
                // date over blocking the main thread.
                [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
                    NSMutableDictionary<NSString *, id> *userInfo =
                        [[NSMutableDictionary alloc] initWithDictionary:[scope serialize]];

                    // SentryCrashReportConverter.convertReportToEvent needs the release name and
                    // the dist of the SentryOptions in the UserInfo. When SentryCrash records a
                    // crash it writes the UserInfo into SentryCrashField_User of the report.
                    // SentryCrashReportConverter.initWithReport loads the contents of
                    // SentryCrashField_User into self.userContext and convertReportToEvent can map
                    // the release name and dist to the SentryEvent. Fixes GH-581
                    userInfo[@"release"] = self.options.releaseName;
                    userInfo[@"dist"] = self.options.dist;

                    [SentryCrash.sharedInstance setUserInfo:userInfo];
                }];
            }];
        }];
    }
}

@end
