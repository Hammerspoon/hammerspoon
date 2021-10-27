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

#import "NSError+SentrySimpleConstructor.h"
#import "SentryCrashC.h"
#import "SentryCrashDoctor.h"
#import "SentryCrashJSONCodecObjC.h"
#import "SentryCrashMonitorContext.h"
#import "SentryCrashMonitor_AppState.h"
#import "SentryCrashMonitor_System.h"
#import "SentryCrashReportFields.h"
#import "SentryCrashSystemCapabilities.h"
#import <NSData+Sentry.h>

//#define SentryCrashLogger_LocalLevel TRACE
#import "SentryCrashLogger.h"

#include <inttypes.h>
#if SentryCrashCRASH_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

// ============================================================================
#pragma mark - Globals -
// ============================================================================

@interface
SentryCrash ()

@property (nonatomic, readwrite, retain) NSString *bundleName;
@property (nonatomic, readwrite, retain) NSString *basePath;

@end

static NSString *
getBundleName()
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    if (bundleName == nil) {
        bundleName = @"Unknown";
    }
    return bundleName;
}

static NSString *
getBasePath()
{
    NSArray *directories
        = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([directories count] == 0) {
        SentryCrashLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *cachePath = [directories objectAtIndex:0];
    if ([cachePath length] == 0) {
        SentryCrashLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *pathEnd = [@"SentryCrash" stringByAppendingPathComponent:getBundleName()];
    return [cachePath stringByAppendingPathComponent:pathEnd];
}

@implementation SentryCrash

// ============================================================================
#pragma mark - Properties -
// ============================================================================

@synthesize sink = _sink;
@synthesize userInfo = _userInfo;
@synthesize deleteBehaviorAfterSendAll = _deleteBehaviorAfterSendAll;
@synthesize monitoring = _monitoring;
@synthesize deadlockWatchdogInterval = _deadlockWatchdogInterval;
@synthesize onCrash = _onCrash;
@synthesize bundleName = _bundleName;
@synthesize basePath = _basePath;
@synthesize introspectMemory = _introspectMemory;
@synthesize catchZombies = _catchZombies;
@synthesize doNotIntrospectClasses = _doNotIntrospectClasses;
@synthesize demangleLanguages = _demangleLanguages;
@synthesize addConsoleLogToReport = _addConsoleLogToReport;
@synthesize printPreviousLog = _printPreviousLog;
@synthesize maxReportCount = _maxReportCount;
@synthesize uncaughtExceptionHandler = _uncaughtExceptionHandler;
@synthesize currentSnapshotUserReportedExceptionHandler
    = _currentSnapshotUserReportedExceptionHandler;

// ============================================================================
#pragma mark - Lifecycle -
// ============================================================================

+ (instancetype)sharedInstance
{
    static SentryCrash *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ sharedInstance = [[SentryCrash alloc] init]; });
    return sharedInstance;
}

- (id)init
{
    return [self initWithBasePath:getBasePath()];
}

- (id)initWithBasePath:(NSString *)basePath
{
    if ((self = [super init])) {
        self.bundleName = getBundleName();
        self.basePath = basePath;
        if (self.basePath == nil) {
            SentryCrashLOG_ERROR(@"Failed to initialize crash handler. Crash "
                                 @"reporting disabled.");
            return nil;
        }
        self.deleteBehaviorAfterSendAll = SentryCrashCDeleteAlways;
        self.introspectMemory = YES;
        self.catchZombies = NO;
        self.maxReportCount = 5;
        self.monitoring = SentryCrashMonitorTypeProductionSafeMinimal;
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
            userInfoJSON = [[SentryCrashJSONCodec encode:userInfo
                                                 options:SentryCrashJSONEncodeOptionSorted
                                                   error:&error] nullTerminated];
            if (error != NULL) {
                SentryCrashLOG_ERROR(@"Could not serialize user info: %@", error);
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

- (void)setDeadlockWatchdogInterval:(double)deadlockWatchdogInterval
{
    _deadlockWatchdogInterval = deadlockWatchdogInterval;
    sentrycrash_setDeadlockWatchdogInterval(deadlockWatchdogInterval);
}

- (void)setOnCrash:(SentryCrashReportWriteCallback)onCrash
{
    _onCrash = onCrash;
    sentrycrash_setCrashNotifyCallback(onCrash);
}

- (void)setIntrospectMemory:(BOOL)introspectMemory
{
    _introspectMemory = introspectMemory;
    sentrycrash_setIntrospectMemory(introspectMemory);
}

- (void)setCatchZombies:(BOOL)catchZombies
{
    _catchZombies = catchZombies;
    self.monitoring |= SentryCrashMonitorTypeZombie;
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
    COPY_STRING(timezone);
    COPY_STRING(processName);
    COPY_PRIMITIVE(processID);
    COPY_PRIMITIVE(parentProcessID);
    COPY_STRING(deviceAppHash);
    COPY_STRING(buildType);
    COPY_PRIMITIVE(storageSize);
    COPY_PRIMITIVE(memorySize);
    COPY_PRIMITIVE(freeMemory);
    COPY_PRIMITIVE(usableMemory);

    return dict;
}

- (BOOL)install
{
    _monitoring = sentrycrash_install(self.bundleName.UTF8String, self.basePath.UTF8String);
    if (self.monitoring == 0) {
        return false;
    }

#if SentryCrashCRASH_HAS_UIAPPLICATION
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:UIApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:UIApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:UIApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:UIApplicationWillEnterForegroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillTerminate)
                    name:UIApplicationWillTerminateNotification
                  object:nil];
#endif
#if SentryCrashCRASH_HAS_NSEXTENSION
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:NSExtensionHostDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:NSExtensionHostWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:NSExtensionHostDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:NSExtensionHostWillEnterForegroundNotification
                  object:nil];
#endif

    return true;
}

- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSArray *reports = [self allReports];

    SentryCrashLOG_INFO(@"Sending %d crash reports", [reports count]);

    [self sendReports:reports
         onCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
             SentryCrashLOG_DEBUG(@"Process finished with completion: %d", completed);
             if (error != nil) {
                 SentryCrashLOG_ERROR(@"Failed to send reports: %@", error);
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

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram
{
    const char *cName = [name cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cReason = [reason cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLanguage = [language cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLineOfCode = [lineOfCode cStringUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *jsonData = [SentryCrashJSONCodec encode:stackTrace options:0 error:&error];
    if (jsonData == nil || error != nil) {
        SentryCrashLOG_ERROR(@"Error encoding stack trace to JSON: %@", error);
        // Don't return, since we can still record other useful information.
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char *cStackTrace = [jsonString cStringUsingEncoding:NSUTF8StringEncoding];

    sentrycrash_reportUserException(
        cName, cReason, cLanguage, cLineOfCode, cStackTrace, logAllThreads, terminateProgram);
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
            [NSError sentryErrorWithDomain:[[self class] description]
                                      code:0
                               description:@"No sink set. Crash reports not sent."]);
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
        SentryCrashLOG_ERROR(
            @"Encountered error loading crash report %" PRIx64 ": %@", reportID, error);
    }
    if (crashReport == nil) {
        SentryCrashLOG_ERROR(@"Could not load crash report");
        return nil;
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

- (void)setAddConsoleLogToReport:(BOOL)shouldAddConsoleLogToReport
{
    _addConsoleLogToReport = shouldAddConsoleLogToReport;
    sentrycrash_setAddConsoleLogToReport(shouldAddConsoleLogToReport);
}

- (void)setPrintPreviousLog:(BOOL)shouldPrintPreviousLog
{
    _printPreviousLog = shouldPrintPreviousLog;
    sentrycrash_setPrintPreviousLog(shouldPrintPreviousLog);
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

@end

//! Project version number for SentryCrashFramework.
const double SentryCrashFrameworkVersionNumber = 1.1518;

//! Project version string for SentryCrashFramework.
const unsigned char SentryCrashFrameworkVersionString[] = "1.15.18";
