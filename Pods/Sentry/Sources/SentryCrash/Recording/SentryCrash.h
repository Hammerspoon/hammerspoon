// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrash.h
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

#import "SentryCrashMonitorType.h"
#import "SentryCrashReportFilter.h"
#import "SentryCrashReportWriter.h"
#import "SentryDefines.h"

typedef enum {
    SentryCrashDemangleLanguageNone = 0,
    SentryCrashDemangleLanguageCPlusPlus = 1,
    SentryCrashDemangleLanguageSwift = 2,
    SentryCrashDemangleLanguageAll = ~1
} SentryCrashDemangleLanguage;

typedef enum {
    SentryCrashCDeleteNever,
    SentryCrashCDeleteOnSucess,
    SentryCrashCDeleteAlways
} SentryCrashCDeleteBehavior;

static NSString *const SENTRYCRASH_REPORT_ATTACHMENTS_ITEM = @"attachments";

@class SentryNSNotificationCenterWrapper;

/**
 * Reports any crashes that occur in the application.
 *
 * The crash reports will be located in
 * $APP_HOME/Library/Caches/SentryCrashReports
 */
@interface SentryCrash : NSObject

#pragma mark - Configuration -
SENTRY_NO_INIT

/** Init SentryCrash instance with custom base path. */
- (instancetype)initWithBasePath:(NSString *)basePath NS_DESIGNATED_INITIALIZER;

/** Cache directory base path. */
@property (nonatomic, readwrite, retain) NSString *basePath;

/** A dictionary containing any info you'd like to appear in crash reports. Must
 * contain only JSON-safe data: NSString for keys, and NSDictionary, NSArray,
 * NSString, NSDate, and NSNumber for values.
 *
 * Default: nil
 */
@property (atomic, readwrite, retain) NSDictionary *userInfo;

/** What to do after sending reports via sendAllReportsWithCompletion:
 *
 * - Use SentryCrashCDeleteNever if you will manually manage the reports.
 * - Use SentryCrashCDeleteAlways if you will be using an alert confirmation
 * (otherwise it will nag the user incessantly until he selects "yes").
 * - Use SentryCrashCDeleteOnSuccess for all other situations.
 *
 * Default: SentryCrashCDeleteAlways
 */
@property (nonatomic, readwrite, assign) SentryCrashCDeleteBehavior deleteBehaviorAfterSendAll;

/** The monitors that will or have been installed.
 * Note: This value may change once SentryCrash is installed if some monitors
 *       fail to install.
 *
 * Default: SentryCrashMonitorTypeProductionSafeMinimal
 */
@property (nonatomic, readwrite, assign) SentryCrashMonitorType monitoring;

// We removed searchQueueNames in 4.0.0 see:
// https://github.com/getsentry/sentry-cocoa/commit/b728c74e898e6ed3b1cab0b1cf5b6c8892b29b70,
// because we were deferencing a pointer to the dispatch queue, which could have been deallocated by
// the time you deference it. Also see this comment in some WebKit code:
// https://github.com/WebKit/WebKit/blob/09225dc168d445890bb0e2a5fa8bc19aef8556f2/Source/WebCore/page/cocoa/ResourceUsageThreadCocoa.mm#L119.

/** If YES, introspect memory contents during a crash.
 * Any Objective-C objects or C strings near the stack pointer or referenced by
 * cpu registers or exceptions will be recorded in the crash report, along with
 * their contents.
 *
 * Default: YES
 */
@property (nonatomic, readwrite, assign) BOOL introspectMemory;

/** List of Objective-C classes that should never be introspected.
 * Whenever a class in this list is encountered, only the class name will be
 * recorded. This can be useful for information security concerns.
 *
 * Default: nil
 */
@property (nonatomic, readwrite, retain) NSArray *doNotIntrospectClasses;

/** The maximum number of reports allowed on disk before old ones get deleted.
 *
 * Default: 5
 */
@property (nonatomic, readwrite, assign) int maxReportCount;

/** The report sink where reports get sent.
 * This MUST be set or else the reporter will not send reports (although it will
 * still record them).
 *
 * Note: If you use an installation, it will automatically set this property.
 *       Do not modify it in such a case.
 */
@property (nonatomic, readwrite, retain) id<SentryCrashReportFilter> sink;

/** C Function to call during a crash report to give the callee an opportunity
 * to add to the report. NULL = ignore.
 *
 * WARNING: Only call async-safe functions from this function! DO NOT call
 * Objective-C methods!!!
 *
 * Note: If you use an installation, it will automatically set this property.
 *       Do not modify it in such a case.
 */
@property (nonatomic, readwrite, assign) SentryCrashReportWriteCallback onCrash;

/** Print the previous app run log to the console when installing SentryCrash.
 *  This is primarily for debugging purposes.
 */
@property (nonatomic, readwrite, assign) BOOL printPreviousLog;

/** Which languages to demangle when getting stack traces (default
 * SentryCrashDemangleLanguageAll) */
@property (nonatomic, readwrite, assign) SentryCrashDemangleLanguage demangleLanguages;

/** Exposes the uncaughtExceptionHandler if set from SentryCrash. Is nil if
 * debugger is running. **/
@property (nonatomic, assign) NSUncaughtExceptionHandler *uncaughtExceptionHandler;

#pragma mark - Information -

/** Total active time elapsed since the last crash. */
@property (nonatomic, readonly, assign) NSTimeInterval activeDurationSinceLastCrash;

/** Total time backgrounded elapsed since the last crash. */
@property (nonatomic, readonly, assign) NSTimeInterval backgroundDurationSinceLastCrash;

/** Number of app launches since the last crash. */
@property (nonatomic, readonly, assign) int launchesSinceLastCrash;

/** Number of sessions (launch, resume from suspend) since last crash. */
@property (nonatomic, readonly, assign) int sessionsSinceLastCrash;

/** Total active time elapsed since launch. */
@property (nonatomic, readonly, assign) NSTimeInterval activeDurationSinceLaunch;

/** Total time backgrounded elapsed since launch. */
@property (nonatomic, readonly, assign) NSTimeInterval backgroundDurationSinceLaunch;

/** Number of sessions (launch, resume from suspend) since app launch. */
@property (nonatomic, readonly, assign) int sessionsSinceLaunch;

/** If true, the application crashed on the previous launch. */
@property (nonatomic, readonly, assign) BOOL crashedLastLaunch;

/** The total number of unsent reports. Note: This is an expensive operation. */
@property (nonatomic, readonly, assign) int reportCount;

/** Information about the operating system and environment */
@property (nonatomic, readonly, strong) NSDictionary *systemInfo;

#pragma mark - API -

/** Install the crash reporter.
 * The reporter will record crashes, but will not send any crash reports unless
 * sink is set.
 *
 * @return YES if the reporter successfully installed.
 */
- (BOOL)install;

/**
 * It's not really possible to completely uninstall SentryCrash. The best we can do is to deactivate
 * all the monitors, keep track of the already installed monitors to install them again if someone
 * calls install, clear the `onCrash` callback, and stop the SentryCrashCachedData. For the
 * ``SentryCrashMonitorTypeMachException`` we let the exception threads running, but they don't
 * report anything.
 */
- (void)uninstall;

/** Send all outstanding crash reports to the current sink.
 * It will only attempt to send the most recent 5 reports. All others will be
 * deleted. Once the reports are successfully sent to the server, they may be
 * deleted locally, depending on the property "deleteAfterSendAll".
 *
 * Note: property "sink" MUST be set or else this method will call onCompletion
 *       with an error.
 *
 * @param onCompletion Called when sending is complete (nil = ignore).
 */
- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion;

/** Get all unsent report IDs.
 *
 * @return An array with report IDs.
 */
- (NSArray *)reportIDs;

/** Get report.
 *
 * @param reportID An ID of report.
 *
 * @return A dictionary with report fields. See SentryCrashReportFields.h for
 * available fields.
 */
- (NSDictionary *)reportWithID:(NSNumber *)reportID;

/** Delete all unsent reports.
 */
- (void)deleteAllReports;

/** Delete report.
 *
 * @param reportID An ID of report to delete.
 */
- (void)deleteReportWithID:(NSNumber *)reportID;

@end

//! Project version number for SentryCrashFramework.
FOUNDATION_EXPORT const double SentryCrashFrameworkVersionNumber;

//! Project version string for SentryCrashFramework.
FOUNDATION_EXPORT const unsigned char SentryCrashFrameworkVersionString[];
