// Adapted from: https://github.com/kstenerud/KSCrash
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
#include "SentryCrashFileUtils.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashMonitor_AppState.h"
#include "SentryCrashMonitor_System.h"
#include "SentryCrashObjC.h"
#include "SentryCrashReport.h"
#include "SentryCrashReportFixer.h"
#include "SentryCrashReportStore.h"
#include "SentryCrashString.h"
#include "SentryCrashSystemCapabilities.h"

// #define SentryCrashLogger_LocalLevel TRACE
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

static SentryCrashMonitorType g_monitoring = SentryCrashMonitorTypeProductionSafeMinimal;
static char g_lastCrashReportFilePath[SentryCrashFU_MAX_PATH_LENGTH];
static void (*g_saveScreenShot)(const char *) = 0;
static void (*g_saveViewHierarchy)(const char *) = 0;

// ============================================================================
#pragma mark - Utility -
// ============================================================================

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
static void
onCrash(struct SentryCrash_MonitorContext *monitorContext)
{
    SentryCrashLOG_DEBUG("Updating application state to note crash.");
    sentrycrashstate_notifyAppCrash();

    if (monitorContext->crashedDuringCrashHandling) {
        sentrycrashreport_writeRecrashReport(monitorContext, g_lastCrashReportFilePath);
    } else {
        char crashReportFilePath[SentryCrashFU_MAX_PATH_LENGTH];
        sentrycrashcrs_getNextCrashReportPath(crashReportFilePath);
        strncpy(g_lastCrashReportFilePath, crashReportFilePath, sizeof(g_lastCrashReportFilePath));
        sentrycrashreport_writeStandardReport(monitorContext, crashReportFilePath);
    }

    // Report is saved to disk, now we try to take screenshots
    // and view hierarchies.
    // Depending on the state of the crash this may not work
    // because we gonna call into non async-signal safe code
    // but since the app is already in a crash state we don't
    // mind if this approach crashes.
    if (g_saveScreenShot || g_saveViewHierarchy) {
        char crashAttachmentsPath[SentryCrashCRS_MAX_PATH_LENGTH];
        sentrycrashcrs_getAttachmentsPath_forReport(
            g_lastCrashReportFilePath, crashAttachmentsPath);

        if (sentrycrashfu_makePath(crashAttachmentsPath)) {
            if (g_saveScreenShot) {
                g_saveScreenShot(crashAttachmentsPath);
            }

            if (g_saveViewHierarchy) {
                g_saveViewHierarchy(crashAttachmentsPath);
            }
        }
    }
}

// ============================================================================
#pragma mark - API -
// ============================================================================

SentryCrashMonitorType
sentrycrash_install(const char *appName, const char *const installPath)
{
    SentryCrashLOG_DEBUG("Installing crash reporter.");

    if (g_installed) {
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

    sentrycrashccd_init(60);

    sentrycrashcm_setEventCallback(onCrash);
    SentryCrashMonitorType monitors = sentrycrash_setMonitoring(g_monitoring);

    SentryCrashLOG_DEBUG("Installation complete.");
    return monitors;
}

void
sentrycrash_uninstall(void)
{
    sentrycrashcm_setEventCallback(NULL);
    g_installed = 0;
    sentrycrashccd_close();
}

SentryCrashMonitorType
sentrycrash_setMonitoring(SentryCrashMonitorType monitors)
{
    g_monitoring = monitors;

    if (g_installed) {
        sentrycrashcm_setActiveMonitors(monitors);
        return sentrycrashcm_getActiveMonitors();
    }
    // Return what we will be monitoring in future.
    return g_monitoring;
}

void
sentrycrash_setUserInfoJSON(const char *const userInfoJSON)
{
    sentrycrashreport_setUserInfoJSON(userInfoJSON);
}

void
sentrycrash_setIntrospectMemory(bool introspectMemory)
{
    sentrycrashreport_setIntrospectMemory(introspectMemory);
}

void
sentrycrash_setDoNotIntrospectClasses(const char **doNotIntrospectClasses, int length)
{
    sentrycrashreport_setDoNotIntrospectClasses(doNotIntrospectClasses, length);
}

void
sentrycrash_setMaxReportCount(int maxReportCount)
{
    sentrycrashcrs_setMaxReportCount(maxReportCount);
}

void
sentrycrash_setSaveScreenshots(void (*callback)(const char *))
{
    g_saveScreenShot = callback;
}

void
sentrycrash_setSaveViewHierarchy(void (*callback)(const char *))
{
    g_saveViewHierarchy = callback;
}

void
sentrycrash_notifyAppActive(bool isActive)
{
    sentrycrashstate_notifyAppActive(isActive);
}

void
sentrycrash_notifyAppInForeground(bool isInForeground)
{
    sentrycrashstate_notifyAppInForeground(isInForeground);
}

void
sentrycrash_notifyAppTerminate(void)
{
    sentrycrashstate_notifyAppTerminate();
}

void
sentrycrash_notifyAppCrash(void)
{
    sentrycrashstate_notifyAppCrash();
}

int
sentrycrash_getReportCount(void)
{
    return sentrycrashcrs_getReportCount();
}

int
sentrycrash_getReportIDs(int64_t *reportIDs, int count)
{
    return sentrycrashcrs_getReportIDs(reportIDs, count);
}

char *
sentrycrash_readReport(int64_t reportID)
{
    if (reportID <= 0) {
        SentryCrashLOG_ERROR("Report ID was %" PRIx64, reportID);
        return NULL;
    }

    char *rawReport = sentrycrashcrs_readReport(reportID);
    if (rawReport == NULL) {
        SentryCrashLOG_ERROR("Failed to load report ID %" PRIx64, reportID);
        return NULL;
    }

    char *fixedReport = sentrycrashcrf_fixupCrashReport(rawReport);
    if (fixedReport == NULL) {
        SentryCrashLOG_ERROR("Failed to fixup report ID %" PRIx64, reportID);
    }

    free(rawReport);
    return fixedReport;
}

int64_t
sentrycrash_addUserReport(const char *report, int reportLength)
{
    return sentrycrashcrs_addUserReport(report, reportLength);
}

void
sentrycrash_deleteAllReports(void)
{
    sentrycrashcrs_deleteAllReports();
}

void
sentrycrash_deleteReportWithID(int64_t reportID)
{
    sentrycrashcrs_deleteReportWithID(reportID);
}

bool
sentrycrash_hasSaveScreenshotCallback(void)
{
    return g_saveScreenShot != NULL;
}

bool
sentrycrash_hasSaveViewHierarchyCallback(void)
{
    return g_saveViewHierarchy != NULL;
}
