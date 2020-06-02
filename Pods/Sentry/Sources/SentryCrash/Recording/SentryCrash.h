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


#import <Foundation/Foundation.h>

#import "SentryCrashReportWriter.h"
#import "SentryCrashReportFilter.h"
#import "SentryCrashMonitorType.h"

typedef enum
{
    SentryCrashDemangleLanguageNone = 0,
    SentryCrashDemangleLanguageCPlusPlus = 1,
    SentryCrashDemangleLanguageSwift = 2,
    SentryCrashDemangleLanguageAll = ~1
} SentryCrashDemangleLanguage;

typedef enum
{
    SentryCrashCDeleteNever,
    SentryCrashCDeleteOnSucess,
    SentryCrashCDeleteAlways
} SentryCrashCDeleteBehavior;

/**
 * Reports any crashes that occur in the application.
 *
 * The crash reports will be located in $APP_HOME/Library/Caches/SentryCrashReports
 */
@interface SentryCrash : NSObject

#pragma mark - Configuration -

/** Init SentryCrash instance with custom base path. */
- (id) initWithBasePath:(NSString *)basePath;

/** A dictionary containing any info you'd like to appear in crash reports. Must
 * contain only JSON-safe data: NSString for keys, and NSDictionary, NSArray,
 * NSString, NSDate, and NSNumber for values.
 *
 * Default: nil
 */
@property(atomic,readwrite,retain) NSDictionary* userInfo;

/** What to do after sending reports via sendAllReportsWithCompletion:
 *
 * - Use SentryCrashCDeleteNever if you will manually manage the reports.
 * - Use SentryCrashCDeleteAlways if you will be using an alert confirmation (otherwise it
 *   will nag the user incessantly until he selects "yes").
 * - Use SentryCrashCDeleteOnSuccess for all other situations.
 *
 * Default: SentryCrashCDeleteAlways
 */
@property(nonatomic,readwrite,assign) SentryCrashCDeleteBehavior deleteBehaviorAfterSendAll;

/** The monitors that will or have been installed.
 * Note: This value may change once SentryCrash is installed if some monitors
 *       fail to install.
 *
 * Default: SentryCrashMonitorTypeProductionSafeMinimal
 */
@property(nonatomic,readwrite,assign) SentryCrashMonitorType monitoring;

/** Maximum time to allow the main thread to run without returning.
 * If a task occupies the main thread for longer than this interval, the
 * watchdog will consider the queue deadlocked and shut down the app and write a
 * crash report.
 *
 * Note: You must have added SentryCrashMonitorTypeMainThreadDeadlock to the monitoring
 *       property in order for this to have any effect.
 *
 * Warning: Make SURE that nothing in your app that runs on the main thread takes
 * longer to complete than this value or it WILL get shut down! This includes
 * your app startup process, so you may need to push app initialization to
 * another thread, or perhaps set this to a higher value until your application
 * has been fully initialized.
 *
 * WARNING: This is still causing false positives in some cases. Use at own risk!
 *
 * 0 = Disabled.
 *
 * Default: 0
 */
@property(nonatomic,readwrite,assign) double deadlockWatchdogInterval;

/** If YES, introspect memory contents during a crash.
 * Any Objective-C objects or C strings near the stack pointer or referenced by
 * cpu registers or exceptions will be recorded in the crash report, along with
 * their contents.
 *
 * Default: YES
 */
@property(nonatomic,readwrite,assign) BOOL introspectMemory;

/** If YES, monitor all Objective-C/Swift deallocations and keep track of any
 * accesses after deallocation.
 *
 * Default: NO
 */
@property(nonatomic,readwrite,assign) BOOL catchZombies;

/** List of Objective-C classes that should never be introspected.
 * Whenever a class in this list is encountered, only the class name will be recorded.
 * This can be useful for information security concerns.
 *
 * Default: nil
 */
@property(nonatomic,readwrite,retain) NSArray* doNotIntrospectClasses;

/** The maximum number of reports allowed on disk before old ones get deleted.
 *
 * Default: 5
 */
@property(nonatomic,readwrite,assign) int maxReportCount;

/** The report sink where reports get sent.
 * This MUST be set or else the reporter will not send reports (although it will
 * still record them).
 *
 * Note: If you use an installation, it will automatically set this property.
 *       Do not modify it in such a case.
 */
@property(nonatomic,readwrite,retain) id<SentryCrashReportFilter> sink;

/** C Function to call during a crash report to give the callee an opportunity to
 * add to the report. NULL = ignore.
 *
 * WARNING: Only call async-safe functions from this function! DO NOT call
 * Objective-C methods!!!
 *
 * Note: If you use an installation, it will automatically set this property.
 *       Do not modify it in such a case.
 */
@property(nonatomic,readwrite,assign) SentryCrashReportWriteCallback onCrash;

/** Add a copy of SentryCrash's console log messages to the crash report.
 */
@property(nonatomic,readwrite,assign) BOOL addConsoleLogToReport;

/** Print the previous app run log to the console when installing SentryCrash.
 *  This is primarily for debugging purposes.
 */
@property(nonatomic,readwrite,assign) BOOL printPreviousLog;

/** Which languages to demangle when getting stack traces (default SentryCrashDemangleLanguageAll) */
@property(nonatomic,readwrite,assign) SentryCrashDemangleLanguage demangleLanguages;

/** Exposes the uncaughtExceptionHandler if set from SentryCrash. Is nil if debugger is running. **/
@property (nonatomic, assign) NSUncaughtExceptionHandler *uncaughtExceptionHandler;

/** Exposes the currentSnapshotUserReportedExceptionHandler if set from SentryCrash. Is nil if debugger is running. **/
@property (nonatomic, assign) NSUncaughtExceptionHandler *currentSnapshotUserReportedExceptionHandler;

#pragma mark - Information -

/** Total active time elapsed since the last crash. */
@property(nonatomic,readonly,assign) NSTimeInterval activeDurationSinceLastCrash;

/** Total time backgrounded elapsed since the last crash. */
@property(nonatomic,readonly,assign) NSTimeInterval backgroundDurationSinceLastCrash;

/** Number of app launches since the last crash. */
@property(nonatomic,readonly,assign) int launchesSinceLastCrash;

/** Number of sessions (launch, resume from suspend) since last crash. */
@property(nonatomic,readonly,assign) int sessionsSinceLastCrash;

/** Total active time elapsed since launch. */
@property(nonatomic,readonly,assign) NSTimeInterval activeDurationSinceLaunch;

/** Total time backgrounded elapsed since launch. */
@property(nonatomic,readonly,assign) NSTimeInterval backgroundDurationSinceLaunch;

/** Number of sessions (launch, resume from suspend) since app launch. */
@property(nonatomic,readonly,assign) int sessionsSinceLaunch;

/** If true, the application crashed on the previous launch. */
@property(nonatomic,readonly,assign) BOOL crashedLastLaunch;

/** The total number of unsent reports. Note: This is an expensive operation. */
@property(nonatomic,readonly,assign) int reportCount;

/** Information about the operating system and environment */
@property(nonatomic,readonly,strong) NSDictionary* systemInfo;

#pragma mark - API -

/** Get the singleton instance of the crash reporter.
 */
+ (SentryCrash*) sharedInstance;

/** Install the crash reporter.
 * The reporter will record crashes, but will not send any crash reports unless
 * sink is set.
 *
 * @return YES if the reporter successfully installed.
 */
- (BOOL) install;

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
- (void) sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion) onCompletion;

/** Get all unsent report IDs.
 *
 * @return An array with report IDs.
 */
- (NSArray*) reportIDs;

/** Get report.
 *
 * @param reportID An ID of report.
 *
 * @return A dictionary with report fields. See SentryCrashReportFields.h for available fields.
 */
- (NSDictionary*) reportWithID:(NSNumber*) reportID;

/** Delete all unsent reports.
 */
- (void) deleteAllReports;

/** Delete report.
 *
 * @param reportID An ID of report to delete.
 */
- (void) deleteReportWithID:(NSNumber*) reportID;

/** Report a custom, user defined exception.
 * This can be useful when dealing with scripting languages.
 *
 * If terminateProgram is true, all sentries will be uninstalled and the application will
 * terminate with an abort().
 *
 * @param name The exception name (for namespacing exception types).
 *
 * @param reason A description of why the exception occurred.
 *
 * @param language A unique language identifier.
 *
 * @param lineOfCode A copy of the offending line of code (nil = ignore).
 *
 * @param stackTrace An array of frames (dictionaries or strings) representing the call stack leading to the exception (nil = ignore).
 *
 * @param logAllThreads If true, suspend all threads and log their state. Note that this incurs a
 *                      performance penalty, so it's best to use only on fatal errors.
 *
 * @param terminateProgram If true, do not return from this function call. Terminate the program instead.
 */
- (void) reportUserException:(NSString*) name
                      reason:(NSString*) reason
                    language:(NSString*) language
                  lineOfCode:(NSString*) lineOfCode
                  stackTrace:(NSArray*) stackTrace
               logAllThreads:(BOOL) logAllThreads
            terminateProgram:(BOOL) terminateProgram;

@end


//! Project version number for SentryCrashFramework.
FOUNDATION_EXPORT const double SentryCrashFrameworkVersionNumber;

//! Project version string for SentryCrashFramework.
FOUNDATION_EXPORT const unsigned char SentryCrashFrameworkVersionString[];
