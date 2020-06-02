//
//  SentryCrashMonitor_NSException.m
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
#import "SentryCrashMonitor_NSException.h"
#import "SentryCrashStackCursor_Backtrace.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashID.h"
#include "SentryCrashThread.h"
#import <Foundation/Foundation.h>

//#define SentryCrashLogger_LocalLevel TRACE
#import "SentryCrashLogger.h"


// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = 0;

static SentryCrash_MonitorContext g_monitorContext;

/** The exception handler that was in place before we installed ours. */
static NSUncaughtExceptionHandler* g_previousUncaughtExceptionHandler;


// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom excepetion handler.
 * Fetch the stack trace from the exception and write a report.
 *
 * @param exception The exception that was raised.
 */

static void handleException(NSException* exception, BOOL currentSnapshotUserReported) {
    SentryCrashLOG_DEBUG(@"Trapped exception %@", exception);
    if(g_isEnabled)
    {
        sentrycrashmc_suspendEnvironment();
        sentrycrashcm_notifyFatalExceptionCaptured(false);

        SentryCrashLOG_DEBUG(@"Filling out context.");
        NSArray* addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = addresses.count;
        uintptr_t* callstack = malloc(numFrames * sizeof(*callstack));
        for(NSUInteger i = 0; i < numFrames; i++)
        {
            callstack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }

        char eventID[37];
        sentrycrashid_generate(eventID);
        SentryCrashMC_NEW_CONTEXT(machineContext);
        sentrycrashmc_getContextForThread(sentrycrashthread_self(), machineContext, true);
        SentryCrashStackCursor cursor;
        sentrycrashsc_initWithBacktrace(&cursor, callstack, (int)numFrames, 0);

        SentryCrash_MonitorContext* crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));
        crashContext->crashType = SentryCrashMonitorTypeNSException;
        crashContext->eventID = eventID;
        crashContext->offendingMachineContext = machineContext;
        crashContext->registersAreValid = false;
        crashContext->NSException.name = [[exception name] UTF8String];
        crashContext->NSException.userInfo = [[NSString stringWithFormat:@"%@", exception.userInfo] UTF8String];
        crashContext->exceptionName = crashContext->NSException.name;
        crashContext->crashReason = [[exception reason] UTF8String];
        crashContext->stackCursor = &cursor;
        crashContext->currentSnapshotUserReported = currentSnapshotUserReported;

        SentryCrashLOG_DEBUG(@"Calling main crash handler.");
        sentrycrashcm_handleException(crashContext);

        free(callstack);
        if (currentSnapshotUserReported) {
            sentrycrashmc_resumeEnvironment();
        }
        if (g_previousUncaughtExceptionHandler != NULL)
        {
            SentryCrashLOG_DEBUG(@"Calling original exception handler.");
            g_previousUncaughtExceptionHandler(exception);
        }
    }
}

static void handleCurrentSnapshotUserReportedException(NSException* exception) {
    handleException(exception, true);
}

static void handleUncaughtException(NSException* exception) {
    handleException(exception, false);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void setEnabled(bool isEnabled)
{
    if(isEnabled != g_isEnabled)
    {
        g_isEnabled = isEnabled;
        if(isEnabled)
        {
            SentryCrashLOG_DEBUG(@"Backing up original handler.");
            g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();

            SentryCrashLOG_DEBUG(@"Setting new handler.");
            NSSetUncaughtExceptionHandler(&handleUncaughtException);
            SentryCrash.sharedInstance.uncaughtExceptionHandler = &handleUncaughtException;
            SentryCrash.sharedInstance.currentSnapshotUserReportedExceptionHandler = &handleCurrentSnapshotUserReportedException;
        }
        else
        {
            SentryCrashLOG_DEBUG(@"Restoring original handler.");
            NSSetUncaughtExceptionHandler(g_previousUncaughtExceptionHandler);
        }
    }
}

static bool isEnabled()
{
    return g_isEnabled;
}

SentryCrashMonitorAPI* sentrycrashcm_nsexception_getAPI()
{
    static SentryCrashMonitorAPI api =
    {
        .setEnabled = setEnabled,
        .isEnabled = isEnabled
    };
    return &api;
}
