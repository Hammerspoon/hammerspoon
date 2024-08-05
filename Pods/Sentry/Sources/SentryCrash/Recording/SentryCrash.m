// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrash.m
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SentryCrash.h"

#import "SentryCrashC.h"
#import "SentryCrashDoctor.h"
#import "SentryCrashJSONCodecObjC.h"
#import "SentryCrashMonitorContext.h"
#import "SentryCrashMonitor_AppState.h"
#import "SentryCrashMonitor_System.h"
#import "SentryCrashNSErrorUtil.h"
#import "SentryCrashReportFields.h"
#import "SentryCrashReportStore.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalCDefines.h"
#import "SentryNSNotificationCenterWrapper.h"
#import <SentryNSDataUtils.h>

#import "SentryLog.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

#include <inttypes.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

@interface
SentryCrash ()

@property (nonatomic, readwrite, retain) NSString *bundleName;
@property (nonatomic, readwrite, assign) SentryCrashMonitorType monitoringWhenUninstalled;
@property (nonatomic, readwrite, assign) BOOL monitoringFromUninstalledToRestore;

- (NSString *)getBundleName;

@end

@implementation SentryCrash

// ============================================================================
#pragma mark - Properties -
// ============================================================================

@synthesize sink = _sink;
@synthesize userInfo = _userInfo;
@synthesize deleteBehaviorAfterSendAll = _deleteBehaviorAfterSendAll;
@synthesize monitoring = _monitoring;
@synthesize onCrash = _onCrash;
@synthesize bundleName = _bundleName;
@synthesize basePath = _basePath;
@synthesize introspectMemory = _introspectMemory;
@synthesize doNotIntrospectClasses = _doNotIntrospectClasses;
@synthesize demangleLanguages = _demangleLanguages;
@synthesize maxReportCount = _maxReportCount;
@synthesize uncaughtExceptionHandler = _uncaughtExceptionHandler;

// ============================================================================
#pragma mark - Lifecycle -
// ============================================================================

- (instancetype)initWithBasePath:(NSString *)basePath
{
    if ((self = [super init])) {
        self.bundleName = [self getBundleName];
        self.basePath = basePath;
        self.deleteBehaviorAfterSendAll = SentryCrashCDeleteAlways;
        self.introspectMemory = YES;
        self.maxReportCount = 5;
        self.monitoring = SentryCrashMonitorTypeProductionSafeMinimal;
        self.monitoringFromUninstalledToRestore = NO;
    }
    return self;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    @synchronized(self) {
        NSError *error = nil;
        NSData *userInfoJSON = nil;
        if (userInfo != nil) {
            userInfoJSON = sentry_nullTerminated(
                [SentryCrashJSONCodec encode:userInfo
                                     options:SentryCrashJSONEncodeOptionSorted
                                       error:&error]);
            if (error != NULL) {
                SENTRY_LOG_ERROR(@"Could not serialize user info: %@", error);
                return;
            }
        }

        _userInfo = userInfo;
        sentrycrash_setUserInfoJSON([userInfoJSON bytes]);
    }
}

- (void)setMonitoring:(SentryCrashMonitorType)monitoring
{
    _monitoring = sentrycrash_setMonitoring(monitoring);
}

- (void)setOnCrash:(SentryCrashReportWriteCallback)onCrash
{
    _onCrash = onCrash;
}

- (void)setIntrospectMemory:(BOOL)introspectMemory
{
    _introspectMemory = introspectMemory;
    sentrycrash_setIntrospectMemory(introspectMemory);
}

- (void)setDoNotIntrospectClasses:(NSArray *)doNotIntrospectClasses
{
    _doNotIntrospectClasses = doNotIntrospectClasses;
    NSUInteger count = [doNotIntrospectClasses count];
    if (count == 0) {
        sentrycrash_setDoNotIntrospectClasses(nil, 0);
    } else {
        NSMutableData *data = [NSMutableData dataWithLength:count * sizeof(const char *)];
        const char **classes = data.mutableBytes;
        for (unsigned i = 0; i < count; i++) {
            classes[i] = [[doNotIntrospectClasses objectAtIndex:i]
                cStringUsingEncoding:NSUTF8StringEncoding];
        }
        sentrycrash_setDoNotIntrospectClasses(classes, (int)count);
    }
}

- (void)setMaxReportCount:(int)maxReportCount
{
    _maxReportCount = maxReportCount;
    sentrycrash_setMaxReportCount(maxReportCount);
}

- (NSDictionary *)systemInfo
{
    SentryCrash_MonitorContext fakeEvent = { 0 };
    sentrycrashcm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);
    NSMutableDictionary *dict = [NSMutableDictionary new];

#define COPY_STRING(A)                                                                             \
    if (fakeEvent.System.A)                                                                        \
    dict[@ #A] = [NSString stringWithUTF8String:fakeEvent.System.A]
#define COPY_PRIMITIVE(A) dict[@ #A] = @(fakeEvent.System.A)
    COPY_STRING(systemName);
    COPY_STRING(systemVersion);
    COPY_STRING(machine);
    COPY_STRING(model);
    COPY_STRING(kernelVersion);
    COPY_STRING(osVersion);
    COPY_PRIMITIVE(isJailbroken);
    COPY_STRING(bootTime);
    COPY_STRING(appStartTime);
    COPY_STRING(executablePath);
    COPY_STRING(executableName);
    COPY_STRING(bundleID);
    COPY_STRING(bundleName);
    COPY_STRING(bundleVersion);
    COPY_STRING(bundleShortVersion);
    COPY_STRING(appID);
    COPY_STRING(cpuArchitecture);
    COPY_PRIMITIVE(cpuType);
    COPY_PRIMITIVE(cpuSubType);
    COPY_PRIMITIVE(binaryCPUType);
    COPY_PRIMITIVE(binaryCPUSubType);
    COPY_STRING(processName);
    COPY_PRIMITIVE(processID);
    COPY_PRIMITIVE(parentProcessID);
    COPY_STRING(deviceAppHash);
    COPY_STRING(buildType);
    COPY_PRIMITIVE(memorySize);
    COPY_PRIMITIVE(freeMemorySize);
    COPY_PRIMITIVE(usableMemorySize);

    return dict;
}

- (BOOL)install
{
    if (self.basePath == nil) {
        SENTRY_LOG_ERROR(@"Failed to initialize crash handler. Crash "
                         @"reporting disabled.");
        return NO;
    }

    // Restore previous monitors when uninstall was called previously
    if (self.monitoringFromUninstalledToRestore
        && self.monitoringWhenUninstalled != SentryCrashMonitorTypeNone) {
        [self setMonitoring:self.monitoringWhenUninstalled];
        self.monitoringWhenUninstalled = SentryCrashMonitorTypeNone;
        self.monitoringFromUninstalledToRestore = NO;
    }

    NSString *pathEnd = [@"SentryCrash" stringByAppendingPathComponent:[self getBundleName]];
    NSString *installPath = [self.basePath stringByAppendingPathComponent:pathEnd];

    _monitoring = sentrycrash_install(self.bundleName.UTF8String, installPath.UTF8String);
    if (self.monitoring == 0) {
        return false;
    }

#if SENTRY_HAS_UIKIT
    SentryNSNotificationCenterWrapper *notificationCenter
        = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive)
                               name:UIApplicationDidBecomeActiveNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive)
                               name:UIApplicationWillResignActiveNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground)
                               name:UIApplicationDidEnterBackgroundNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground)
                               name:UIApplicationWillEnterForegroundNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate)
                               name:UIApplicationWillTerminateNotification];
#endif // SENTRY_HAS_UIKIT
#if SENTRY_HAS_NSEXTENSION
    SentryNSNotificationCenterWrapper *notificationCenter
        = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive)
                               name:NSExtensionHostDidBecomeActiveNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive)
                               name:NSExtensionHostWillResignActiveNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground)
                               name:NSExtensionHostDidEnterBackgroundNotification];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground)
                               name:NSExtensionHostWillEnterForegroundNotification];
#endif // SENTRY_HAS_NSEXTENSION

    return true;
}

- (void)uninstall
{
    self.monitoringWhenUninstalled = self.monitoring;
    [self setMonitoring:SentryCrashMonitorTypeNone];
    self.monitoringFromUninstalledToRestore = YES;
    self.onCrash = NULL;
    sentrycrash_uninstall();

#if SENTRY_HAS_UIKIT
    SentryNSNotificationCenterWrapper *notificationCenter
        = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notificationCenter removeObserver:self name:UIApplicationDidBecomeActiveNotification];
    [notificationCenter removeObserver:self name:UIApplicationWillResignActiveNotification];
    [notificationCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification];
    [notificationCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification];
    [notificationCenter removeObserver:self name:UIApplicationWillTerminateNotification];
#endif // SENTRY_HAS_UIKIT
#if SENTRY_HAS_NSEXTENSION
    SentryNSNotificationCenterWrapper *notificationCenter
        = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    [notificationCenter removeObserver:self name:NSExtensionHostDidBecomeActiveNotification];
    [notificationCenter removeObserver:self name:NSExtensionHostWillResignActiveNotification];
    [notificationCenter removeObserver:self name:NSExtensionHostDidEnterBackgroundNotification];
    [notificationCenter removeObserver:self name:NSExtensionHostWillEnterForegroundNotification];
#endif
}

- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSArray *reports = [self allReports];

    SENTRY_LOG_INFO(@"Sending %lu crash reports", (unsigned long)[reports count]);

    [self sendReports:reports
         onCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
             SENTRY_LOG_DEBUG(@"Process finished with completion: %d", completed);
             if (error != nil) {
                 SENTRY_LOG_ERROR(@"Failed to send reports: %@", error);
             }
             if ((self.deleteBehaviorAfterSendAll == SentryCrashCDeleteOnSucess && completed)
                 || self.deleteBehaviorAfterSendAll == SentryCrashCDeleteAlways) {
                 sentrycrash_deleteAllReports();
             }
             sentrycrash_callCompletion(onCompletion, filteredReports, completed, error);
         }];
}

- (void)deleteAllReports
{
    sentrycrash_deleteAllReports();
}

- (void)deleteReportWithID:(NSNumber *)reportID
{
    sentrycrash_deleteReportWithID([reportID longValue]);
}

// ============================================================================
#pragma mark - Advanced API -
// ============================================================================

#define SYNTHESIZE_CRASH_STATE_PROPERTY(TYPE, NAME)                                                \
    -(TYPE)NAME { return sentrycrashstate_currentState()->NAME; }

SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, launchesSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(BOOL, crashedLastLaunch)

- (int)reportCount
{
    return sentrycrash_getReportCount();
}

- (void)sendReports:(NSArray *)reports onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    if ([reports count] == 0) {
        sentrycrash_callCompletion(onCompletion, reports, YES, nil);
        return;
    }

    if (self.sink == nil) {
        sentrycrash_callCompletion(onCompletion, reports, NO,
            sentryErrorWithDomain(
                [[self class] description], 0, @"No sink set. Crash reports not sent."));
        return;
    }

    [self.sink filterReports:reports
                onCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
                    sentrycrash_callCompletion(onCompletion, filteredReports, completed, error);
                }];
}

- (NSData *)loadCrashReportJSONWithID:(int64_t)reportID
{
    char *report = sentrycrash_readReport(reportID);
    if (report != NULL) {
        return [NSData dataWithBytesNoCopy:report length:strlen(report) freeWhenDone:YES];
    }
    return nil;
}

- (NSArray<NSString *> *)getAttachmentPaths:(int64_t)reportID
{
    char report_attachments_path[SentryCrashCRS_MAX_PATH_LENGTH];
    sentrycrashcrs_getAttachmentsPath_forReportId(reportID, report_attachments_path);
    NSString *path = [NSString stringWithUTF8String:report_attachments_path];

    BOOL isDir = false;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || !isDir)
        return @[];

    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil];
    if (files == nil)
        return @[];

    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:files.count];
    [files enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [result addObject:[NSString stringWithFormat:@"%@/%@", path, obj]];
    }];

    return result;
}

- (void)doctorReport:(NSMutableDictionary *)report
{
    NSMutableDictionary *crashReport = report[@SentryCrashField_Crash];
    if (crashReport != nil) {
        crashReport[@SentryCrashField_Diagnosis] =
            [[SentryCrashDoctor doctor] diagnoseCrash:report];
    }
    crashReport = report[@SentryCrashField_RecrashReport][@SentryCrashField_Crash];
    if (crashReport != nil) {
        crashReport[@SentryCrashField_Diagnosis] =
            [[SentryCrashDoctor doctor] diagnoseCrash:report];
    }
}

- (NSArray *)reportIDs
{
    int reportCount = sentrycrash_getReportCount();
    int64_t reportIDsC[reportCount];
    reportCount = sentrycrash_getReportIDs(reportIDsC, reportCount);
    NSMutableArray *reportIDs = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for (int i = 0; i < reportCount; i++) {
        [reportIDs addObject:@(reportIDsC[i])];
    }
    return reportIDs;
}

- (NSDictionary *)reportWithID:(NSNumber *)reportID
{
    return [self reportWithIntID:[reportID longValue]];
}

- (NSDictionary *)reportWithIntID:(int64_t)reportID
{
    NSData *jsonData = [self loadCrashReportJSONWithID:reportID];
    if (jsonData == nil) {
        return nil;
    }

    NSError *error = nil;
    NSMutableDictionary *crashReport =
        [SentryCrashJSONCodec decode:jsonData
                             options:SentryCrashJSONDecodeOptionIgnoreNullInArray
                             | SentryCrashJSONDecodeOptionIgnoreNullInObject
                             | SentryCrashJSONDecodeOptionKeepPartialObject
                               error:&error];

    if (error != nil) {
        SENTRY_LOG_ERROR(
            @"Encountered error loading crash report %" PRIx64 ": %@", reportID, error);
    }
    if (crashReport == nil) {
        SENTRY_LOG_ERROR(@"Could not load crash report");
        return nil;
    }

    NSArray *attachments = [self getAttachmentPaths:reportID];
    if (attachments.count > 0) {
        crashReport[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM] = attachments;
    }

    [self doctorReport:crashReport];

    return crashReport;
}

- (NSArray *)allReports
{
    NSMutableArray *reports = [NSMutableArray array];
    int reportCount = sentrycrash_getReportCount();
    if (reportCount > 0) {
        int64_t reportIDs[reportCount];
        reportCount = sentrycrash_getReportIDs(reportIDs, reportCount);
        for (int i = 0; i < reportCount; i++) {
            NSDictionary *report = [self reportWithIntID:reportIDs[i]];
            if (report != nil) {
                [reports addObject:report];
            }
        }
    }
    return reports;
}

- (void)setPrintPreviousLog:(BOOL)shouldPrintPreviousLog
{
    _printPreviousLog = shouldPrintPreviousLog;
}

// ============================================================================
#pragma mark - Notifications -
// ============================================================================

- (void)applicationDidBecomeActive
{
    sentrycrash_notifyAppActive(true);
}

- (void)applicationWillResignActive
{
    sentrycrash_notifyAppActive(false);
}

- (void)applicationDidEnterBackground
{
    sentrycrash_notifyAppInForeground(false);
}

- (void)applicationWillEnterForeground
{
    sentrycrash_notifyAppInForeground(true);
}

- (void)applicationWillTerminate
{
    sentrycrash_notifyAppTerminate();
}

- (NSString *)clearBundleName:(NSString *)filename
{
    // The bundle name is used as file name, therefore "/" is not allowed.
    return [filename stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
}

- (NSString *)getBundleName
{
    NSString *bundleName =
        [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] ?: @"Unknown";
    return [self clearBundleName:bundleName];
}

@end

//! Project version number for SentryCrashFramework.
const double SentryCrashFrameworkVersionNumber = 1.1518;

//! Project version string for SentryCrashFramework.
const unsigned char SentryCrashFrameworkVersionString[] = "1.15.18";
