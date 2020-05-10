//
//  SentryCrashC.c
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


#include "SentryCrashC.h"

#include "SentryCrashCachedData.h"
#include "SentryCrashReport.h"
#include "SentryCrashReportFixer.h"
#include "SentryCrashReportStore.h"
#include "SentryCrashMonitor_Deadlock.h"
#include "SentryCrashMonitor_User.h"
#include "SentryCrashFileUtils.h"
#include "SentryCrashObjC.h"
#include "SentryCrashString.h"
#include "SentryCrashMonitor_System.h"
#include "SentryCrashMonitor_Zombie.h"
#include "SentryCrashMonitor_AppState.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashSystemCapabilities.h"

//#define SentryCrashLogger_LocalLevel TRACE
#include "SentryCrashLogger.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if SentryCrash has been installed. */
static volatile bool g_installed = 0;

static bool g_shouldAddConsoleLogToReport = false;
static bool g_shouldPrintPreviousLog = false;
static char g_consoleLogPath[SentryCrashFU_MAX_PATH_LENGTH];
static SentryCrashMonitorType g_monitoring = SentryCrashMonitorTypeProductionSafeMinimal;
static char g_lastCrashReportFilePath[SentryCrashFU_MAX_PATH_LENGTH];


// ============================================================================
#pragma mark - Utility -
// ============================================================================

static void printPreviousLog(const char* filePath)
{
    char* data;
    int length;
    if(sentrycrashfu_readEntireFile(filePath, &data, &length, 0))
    {
        printf("\nvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv Previous Log vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n\n");
        printf("%s\n", data);
        printf("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n");
        fflush(stdout);
    }
}


// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
static void onCrash(struct SentryCrash_MonitorContext* monitorContext)
{
    if (monitorContext->currentSnapshotUserReported == false) {
        SentryCrashLOG_DEBUG("Updating application state to note crash.");
        sentrycrashstate_notifyAppCrash();
    }
    monitorContext->consoleLogPath = g_shouldAddConsoleLogToReport ? g_consoleLogPath : NULL;

    if(monitorContext->crashedDuringCrashHandling)
    {
        sentrycrashreport_writeRecrashReport(monitorContext, g_lastCrashReportFilePath);
    }
    else
    {
        char crashReportFilePath[SentryCrashFU_MAX_PATH_LENGTH];
        sentrycrashcrs_getNextCrashReportPath(crashReportFilePath);
        strncpy(g_lastCrashReportFilePath, crashReportFilePath, sizeof(g_lastCrashReportFilePath));
        sentrycrashreport_writeStandardReport(monitorContext, crashReportFilePath);
    }
}


// ============================================================================
#pragma mark - API -
// ============================================================================

SentryCrashMonitorType sentrycrash_install(const char* appName, const char* const installPath)
{
    SentryCrashLOG_DEBUG("Installing crash reporter.");

    if(g_installed)
    {
        SentryCrashLOG_DEBUG("Crash reporter already installed.");
        return g_monitoring;
    }
    g_installed = 1;

    char path[SentryCrashFU_MAX_PATH_LENGTH];
    snprintf(path, sizeof(path), "%s/Reports", installPath);
    sentrycrashfu_makePath(path);
    sentrycrashcrs_initialize(appName, path);

    snprintf(path, sizeof(path), "%s/Data", installPath);
    sentrycrashfu_makePath(path);
    snprintf(path, sizeof(path), "%s/Data/CrashState.json", installPath);
    sentrycrashstate_initialize(path);

    snprintf(g_consoleLogPath, sizeof(g_consoleLogPath), "%s/Data/ConsoleLog.txt", installPath);
    if(g_shouldPrintPreviousLog)
    {
        printPreviousLog(g_consoleLogPath);
    }
    sentrycrashlog_setLogFilename(g_consoleLogPath, true);

    sentrycrashccd_init(60);

    sentrycrashcm_setEventCallback(onCrash);
    SentryCrashMonitorType monitors = sentrycrash_setMonitoring(g_monitoring);

    SentryCrashLOG_DEBUG("Installation complete.");
    return monitors;
}

SentryCrashMonitorType sentrycrash_setMonitoring(SentryCrashMonitorType monitors)
{
    g_monitoring = monitors;

    if(g_installed)
    {
        sentrycrashcm_setActiveMonitors(monitors);
        return sentrycrashcm_getActiveMonitors();
    }
    // Return what we will be monitoring in future.
    return g_monitoring;
}

void sentrycrash_setUserInfoJSON(const char* const userInfoJSON)
{
    sentrycrashreport_setUserInfoJSON(userInfoJSON);
}

void sentrycrash_setDeadlockWatchdogInterval(double deadlockWatchdogInterval)
{
#if SentryCrashCRASH_HAS_OBJC
    sentrycrashcm_setDeadlockHandlerWatchdogInterval(deadlockWatchdogInterval);
#endif
}

void sentrycrash_setIntrospectMemory(bool introspectMemory)
{
    sentrycrashreport_setIntrospectMemory(introspectMemory);
}

void sentrycrash_setDoNotIntrospectClasses(const char** doNotIntrospectClasses, int length)
{
    sentrycrashreport_setDoNotIntrospectClasses(doNotIntrospectClasses, length);
}

void sentrycrash_setCrashNotifyCallback(const SentryCrashReportWriteCallback onCrashNotify)
{
    sentrycrashreport_setUserSectionWriteCallback(onCrashNotify);
}

void sentrycrash_setAddConsoleLogToReport(bool shouldAddConsoleLogToReport)
{
    g_shouldAddConsoleLogToReport = shouldAddConsoleLogToReport;
}

void sentrycrash_setPrintPreviousLog(bool shouldPrintPreviousLog)
{
    g_shouldPrintPreviousLog = shouldPrintPreviousLog;
}

void sentrycrash_setMaxReportCount(int maxReportCount)
{
    sentrycrashcrs_setMaxReportCount(maxReportCount);
}

void sentrycrash_reportUserException(const char* name,
                                 const char* reason,
                                 const char* language,
                                 const char* lineOfCode,
                                 const char* stackTrace,
                                 bool logAllThreads,
                                 bool terminateProgram)
{
    sentrycrashcm_reportUserException(name,
                             reason,
                             language,
                             lineOfCode,
                             stackTrace,
                             logAllThreads,
                             terminateProgram);
    if(g_shouldAddConsoleLogToReport)
    {
        sentrycrashlog_clearLogFile();
    }
}

void sentrycrash_notifyAppActive(bool isActive)
{
    sentrycrashstate_notifyAppActive(isActive);
}

void sentrycrash_notifyAppInForeground(bool isInForeground)
{
    sentrycrashstate_notifyAppInForeground(isInForeground);
}

void sentrycrash_notifyAppTerminate(void)
{
    sentrycrashstate_notifyAppTerminate();
}

void sentrycrash_notifyAppCrash(void)
{
    sentrycrashstate_notifyAppCrash();
}

int sentrycrash_getReportCount()
{
    return sentrycrashcrs_getReportCount();
}

int sentrycrash_getReportIDs(int64_t* reportIDs, int count)
{
    return sentrycrashcrs_getReportIDs(reportIDs, count);
}

char* sentrycrash_readReport(int64_t reportID)
{
    if(reportID <= 0)
    {
        SentryCrashLOG_ERROR("Report ID was %" PRIx64, reportID);
        return NULL;
    }

    char* rawReport = sentrycrashcrs_readReport(reportID);
    if(rawReport == NULL)
    {
        SentryCrashLOG_ERROR("Failed to load report ID %" PRIx64, reportID);
        return NULL;
    }

    char* fixedReport = sentrycrashcrf_fixupCrashReport(rawReport);
    if(fixedReport == NULL)
    {
        SentryCrashLOG_ERROR("Failed to fixup report ID %" PRIx64, reportID);
    }

    free(rawReport);
    return fixedReport;
}

int64_t sentrycrash_addUserReport(const char* report, int reportLength)
{
    return sentrycrashcrs_addUserReport(report, reportLength);
}

void sentrycrash_deleteAllReports()
{
    sentrycrashcrs_deleteAllReports();
}

void sentrycrash_deleteReportWithID(int64_t reportID)
{
    sentrycrashcrs_deleteReportWithID(reportID);
}
