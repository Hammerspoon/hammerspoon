#import "SentryCrashIntegration.h"
#import "SentryCrashInstallationReporter.h"

#include "SentryCrashMonitor_Signal.h"
#import "SentryCrashWrapper.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryInAppLogic.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySessionCrashedHandler.h"
#import "SentryWatchdogTerminationLogic.h"
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashScopeObserver.h>
#import <SentryDependencyContainer.h>
#import <SentrySDK+Private.h>
#import <SentrySysctl.h>

#if SENTRY_HAS_UIKIT
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>
#endif

static dispatch_once_t installationToken = 0;
static SentryCrashInstallationReporter *installation = nil;

static NSString *const DEVICE_KEY = @"device";
static NSString *const LOCALE_KEY = @"locale";

@interface
SentryCrashIntegration ()

@property (nonatomic, weak) SentryOptions *options;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryCrashWrapper *crashAdapter;
@property (nonatomic, strong) SentrySessionCrashedHandler *crashedSessionHandler;
@property (nonatomic, strong) SentryCrashScopeObserver *scopeObserver;

@end

@implementation SentryCrashIntegration

- (instancetype)init
{
    self = [self initWithCrashAdapter:[SentryCrashWrapper sharedInstance]
              andDispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]];

    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithCrashAdapter:(SentryCrashWrapper *)crashAdapter
             andDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.crashAdapter = crashAdapter;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
    }

    return self;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.options = options;

#if SENTRY_HAS_UIKIT
    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;
    SentryWatchdogTerminationLogic *logic =
        [[SentryWatchdogTerminationLogic alloc] initWithOptions:options
                                                   crashAdapter:self.crashAdapter
                                                appStateManager:appStateManager];
    self.crashedSessionHandler =
        [[SentrySessionCrashedHandler alloc] initWithCrashWrapper:self.crashAdapter
                                         watchdogTerminationLogic:logic];
#else
    self.crashedSessionHandler =
        [[SentrySessionCrashedHandler alloc] initWithCrashWrapper:self.crashAdapter];
#endif // SENTRY_HAS_UIKIT

    self.scopeObserver =
        [[SentryCrashScopeObserver alloc] initWithMaxBreadcrumbs:options.maxBreadcrumbs];

    BOOL enableSigtermReporting = NO;
#if !TARGET_OS_WATCH
    enableSigtermReporting = options.enableSigtermReporting;
#endif // !TARGET_OS_WATCH

    [self startCrashHandler:options.cacheDirectoryPath
        enableSigtermReporting:enableSigtermReporting];

    [self configureScope];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableCrashHandler;
}

- (void)startCrashHandler:(NSString *)cacheDirectory
    enableSigtermReporting:(BOOL)enableSigtermReporting
{
    void (^block)(void) = ^{
        BOOL canSendReports = NO;
        if (installation == nil) {
            SentryInAppLogic *inAppLogic =
                [[SentryInAppLogic alloc] initWithInAppIncludes:self.options.inAppIncludes
                                                  inAppExcludes:self.options.inAppExcludes];

            installation = [[SentryCrashInstallationReporter alloc]
                initWithInAppLogic:inAppLogic
                      crashWrapper:self.crashAdapter
                     dispatchQueue:self.dispatchQueueWrapper];

            canSendReports = YES;
        }

        sentrycrashcm_setEnableSigtermReporting(enableSigtermReporting);

        [installation install:cacheDirectory];

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
        [self.crashedSessionHandler endCurrentSessionAsCrashedWhenCrashOrOOM];

        // We only need to send all reports on the first initialization of SentryCrash. If
        // SenryCrash was deactivated there are no new reports to send. Furthermore, the
        // g_reportsPath in SentryCrashReportsStore gets set when SentryCrash is installed. In
        // production usage, this path is not supposed to change. When testing, this path can
        // change, and therefore, the initial set g_reportsPath can be deleted. sendAllReports calls
        // deleteAllReports, which fails it can't access g_reportsPath. We could fix SentryCrash or
        // just not call sendAllReports as it doesn't make sense to call it twice as described
        // above.
        if (canSendReports) {
            [SentryCrashIntegration sendAllSentryCrashReports];
        }
    };
    [self.dispatchQueueWrapper dispatchOnce:&installationToken block:block];
}

/**
 * Internal, only needed for testing.
 */
+ (void)sendAllSentryCrashReports
{
    [installation sendAllReportsWithCompletion:NULL];
}

- (void)uninstall
{
    if (nil != installation) {
        [installation uninstall];
        installationToken = 0;
    }

    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:NSCurrentLocaleDidChangeNotification
                                                object:nil];
}

- (void)configureScope
{
    // We need to make sure to set always the scope to KSCrash so we have it in
    // case of a crash
    [SentrySDK.currentHub configureScope:^(SentryScope *_Nonnull outerScope) {
        NSMutableDictionary<NSString *, id> *userInfo =
            [[NSMutableDictionary alloc] initWithDictionary:[outerScope serialize]];
        // SentryCrashReportConverter.convertReportToEvent needs the release name and
        // the dist of the SentryOptions in the UserInfo. When SentryCrash records a
        // crash it writes the UserInfo into SentryCrashField_User of the report.
        // SentryCrashReportConverter.initWithReport loads the contents of
        // SentryCrashField_User into self.userContext and convertReportToEvent can map
        // the release name and dist to the SentryEvent. Fixes GH-581
        userInfo[@"release"] = self.options.releaseName;
        userInfo[@"dist"] = self.options.dist;

        [SentryDependencyContainer.sharedInstance.crashReporter setUserInfo:userInfo];

        [outerScope addObserver:self.scopeObserver];
    }];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(currentLocaleDidChange)
                                               name:NSCurrentLocaleDidChangeNotification
                                             object:nil];
}

- (void)currentLocaleDidChange
{
    [SentrySDK.currentHub configureScope:^(SentryScope *_Nonnull scope) {
        NSMutableDictionary<NSString *, id> *device;
        if (scope.contextDictionary != nil && scope.contextDictionary[DEVICE_KEY] != nil) {
            device = [[NSMutableDictionary alloc]
                initWithDictionary:scope.contextDictionary[DEVICE_KEY]];
        } else {
            device = [NSMutableDictionary new];
        }

        NSString *locale = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleIdentifier];
        device[LOCALE_KEY] = locale;

        [scope setContextValue:device forKey:DEVICE_KEY];
    }];
}

@end
