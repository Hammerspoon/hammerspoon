// Adapted from: https://github.com/kstenerud/KSCrash
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

#import "SentryCrashMonitor_NSException.h"
#import "SentryCrash.h"
#include "SentryCrashID.h"
#include "SentryCrashMonitorContext.h"
#import "SentryCrashStackCursor_Backtrace.h"
#include "SentryCrashThread.h"
#import "SentryDependencyContainer.h"

#import "SentryLog.h"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = 0;

static SentryCrash_MonitorContext g_monitorContext;

/** The exception handler that was in place before we installed ours. */
static NSUncaughtExceptionHandler *g_previousUncaughtExceptionHandler;

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom exception handler.
 * Fetch the stack trace from the exception and write a report.
 *
 * @param exception The exception that was raised.
 */

static void
handleException(NSException *exception)
{
    SENTRY_LOG_DEBUG(@"Trapped exception %@", exception);
    if (g_isEnabled) {
        thread_act_array_t threads = NULL;
        mach_msg_type_number_t numThreads = 0;
        sentrycrashmc_suspendEnvironment(&threads, &numThreads);
        sentrycrashcm_notifyFatalExceptionCaptured(false);

        SENTRY_LOG_DEBUG(@"Filling out context.");
        NSArray *addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = addresses.count;
        uintptr_t *callstack = malloc(numFrames * sizeof(*callstack));
        assert(callstack != NULL);

        for (NSUInteger i = 0; i < numFrames; i++) {
            callstack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }

        char eventID[37];
        sentrycrashid_generate(eventID);
        SentryCrashMC_NEW_CONTEXT(machineContext);
        sentrycrashmc_getContextForThread(sentrycrashthread_self(), machineContext, true);
        SentryCrashStackCursor cursor;
        sentrycrashsc_initWithBacktrace(&cursor, callstack, (int)numFrames, 0);

        SentryCrash_MonitorContext *crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));
        crashContext->crashType = SentryCrashMonitorTypeNSException;
        crashContext->eventID = eventID;
        crashContext->offendingMachineContext = machineContext;
        crashContext->registersAreValid = false;
        crashContext->NSException.name = [[exception name] UTF8String];
        crashContext->NSException.userInfo =
            [[NSString stringWithFormat:@"%@", exception.userInfo] UTF8String];
        crashContext->exceptionName = crashContext->NSException.name;
        crashContext->crashReason = [[exception reason] UTF8String];
        crashContext->stackCursor = &cursor;

        SENTRY_LOG_DEBUG(@"Calling main crash handler.");
        sentrycrashcm_handleException(crashContext);

        free(callstack);
        if (g_previousUncaughtExceptionHandler != NULL) {
            SENTRY_LOG_DEBUG(@"Calling original exception handler.");
            g_previousUncaughtExceptionHandler(exception);
        }
    }
}

static void
handleUncaughtException(NSException *exception)
{
    handleException(exception);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void
setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            SENTRY_LOG_DEBUG(@"Backing up original handler.");
            g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();

            SENTRY_LOG_DEBUG(@"Setting new handler.");
            NSSetUncaughtExceptionHandler(&handleUncaughtException);
            SentryDependencyContainer.sharedInstance.crashReporter.uncaughtExceptionHandler
                = &handleUncaughtException;
        } else {
            SENTRY_LOG_DEBUG(@"Restoring original handler.");
            NSSetUncaughtExceptionHandler(g_previousUncaughtExceptionHandler);
        }
    }
}

static bool
isEnabled(void)
{
    return g_isEnabled;
}

SentryCrashMonitorAPI *
sentrycrashcm_nsexception_getAPI(void)
{
    static SentryCrashMonitorAPI api = { .setEnabled = setEnabled, .isEnabled = isEnabled };
    return &api;
}
