// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportStore.c
//
//  Created by Karl Stenerud on 2012-02-05.
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

#include "SentryCrashReportStore.h"
#include "SentryCrashFileUtils.h"
#include "SentryCrashLogger.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int g_maxReportCount = 5;
// Have to use max 32-bit atomics because of MIPS.
static _Atomic(uint32_t) g_nextUniqueIDLow;
static int64_t g_nextUniqueIDHigh;
static const char *g_appName;
static const char *g_reportsPath;
static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;

static int
compareInt64(const void *a, const void *b)
{
    int64_t diff = *(int64_t *)a - *(int64_t *)b;
    if (diff < 0) {
        return -1;
    } else if (diff > 0) {
        return 1;
    }
    return 0;
}

static inline int64_t
getNextUniqueID(void)
{
    return g_nextUniqueIDHigh + g_nextUniqueIDLow++;
}

static void
getCrashReportPathByID(int64_t id, char *pathBuffer)
{
    snprintf(pathBuffer, SentryCrashCRS_MAX_PATH_LENGTH, "%s/%s-report-%016llx.json", g_reportsPath,
        g_appName, id);
}

static int64_t
getReportIDFromFilename(const char *filename)
{
    char scanFormat[SentryCrashCRS_MAX_PATH_LENGTH];
    snprintf(scanFormat, sizeof(scanFormat), "%s-report-%%" PRIx64 ".json", g_appName);

    int64_t reportID = 0;
    sscanf(filename, scanFormat, &reportID);

    return reportID;
}

static int64_t
getReportIDFromFilePath(const char *filepath)
{
    char scanFormat[SentryCrashCRS_MAX_PATH_LENGTH];
    snprintf(
        scanFormat, sizeof(scanFormat), "%s/%s-report-%%" PRIx64 ".json", g_reportsPath, g_appName);

    int64_t reportID = 0;
    sscanf(filepath, scanFormat, &reportID);

    return reportID;
}

static int
getReportCount(void)
{
    int count = 0;
    DIR *dir = opendir(g_reportsPath);
    if (dir == NULL) {
        SentryCrashLOG_ERROR("Could not open directory %s", g_reportsPath);
        goto done;
    }
    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (ent->d_type != DT_DIR && getReportIDFromFilename(ent->d_name) > 0) {
            count++;
        }
    }

done:
    if (dir != NULL) {
        closedir(dir);
    }
    return count;
}

static int
getReportIDs(int64_t *reportIDs, int count)
{
    int index = 0;
    DIR *dir = opendir(g_reportsPath);
    if (dir == NULL) {
        SentryCrashLOG_ERROR("Could not open directory %s", g_reportsPath);
        goto done;
    }

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL && index < count) {
        int64_t reportID = getReportIDFromFilename(ent->d_name);
        if (reportID > 0) {
            reportIDs[index++] = reportID;
        }
    }

    qsort(reportIDs, (unsigned)count, sizeof(reportIDs[0]), compareInt64);

done:
    if (dir != NULL) {
        closedir(dir);
    }
    return index;
}

static void
pruneReports(void)
{
    int reportCount = getReportCount();
    if (reportCount > g_maxReportCount) {
        int64_t reportIDs[reportCount];
        reportCount = getReportIDs(reportIDs, reportCount);

        for (int i = 0; i < reportCount - g_maxReportCount; i++) {
            sentrycrashcrs_deleteReportWithID(reportIDs[i]);
        }
    }
}

static void
initializeIDs(void)
{
    time_t rawTime;
    time(&rawTime);
    struct tm time;
    gmtime_r(&rawTime, &time);
    int64_t baseID = (int64_t)time.tm_sec + (int64_t)time.tm_min * 61
        + (int64_t)time.tm_hour * 61 * 60 + (int64_t)time.tm_yday * 61 * 60 * 24
        + (int64_t)time.tm_year * 61 * 60 * 24 * 366;
    baseID <<= 23;

    g_nextUniqueIDHigh = baseID & ~0xffffffff;
    uint32_t lowerBaseID = (uint32_t)(baseID & 0xffffffff);
    g_nextUniqueIDLow = lowerBaseID;
}

// Public API

void
sentrycrashcrs_initialize(const char *appName, const char *reportsPath)
{
    pthread_mutex_lock(&g_mutex);
    g_appName = strdup(appName);
    g_reportsPath = strdup(reportsPath);
    sentrycrashfu_makePath(reportsPath);
    pruneReports();
    initializeIDs();
    pthread_mutex_unlock(&g_mutex);
}

void
sentrycrashcrs_getNextCrashReportPath(char *crashReportPathBuffer)
{
    getCrashReportPathByID(getNextUniqueID(), crashReportPathBuffer);
}

int
sentrycrashcrs_getReportCount(void)
{
    pthread_mutex_lock(&g_mutex);
    int count = getReportCount();
    pthread_mutex_unlock(&g_mutex);
    return count;
}

int
sentrycrashcrs_getReportIDs(int64_t *reportIDs, int count)
{
    pthread_mutex_lock(&g_mutex);
    count = getReportIDs(reportIDs, count);
    pthread_mutex_unlock(&g_mutex);
    return count;
}

void
sentrycrashcrs_getCrashReportPathById(int64_t reportId, char *pathBuffer)
{
    getCrashReportPathByID(reportId, pathBuffer);
}

char *
sentrycrashcrs_readReport(int64_t reportID)
{
    pthread_mutex_lock(&g_mutex);
    char path[SentryCrashCRS_MAX_PATH_LENGTH];
    getCrashReportPathByID(reportID, path);
    char *result;
    sentrycrashfu_readEntireFile(path, &result, NULL, 2000000);
    pthread_mutex_unlock(&g_mutex);
    return result;
}

void
sentrycrashcrs_getAttachmentsPath_forReportId(int64_t reportID, char *pathBuffer)
{
    snprintf(pathBuffer, SentryCrashCRS_MAX_PATH_LENGTH, "%s/%s-report-%016llx-attachments",
        g_reportsPath, g_appName, reportID);
}

void
sentrycrashcrs_getAttachmentsPath_forReport(const char *reportPath, char *pathBuffer)
{
    sentrycrashcrs_getAttachmentsPath_forReportId(getReportIDFromFilePath(reportPath), pathBuffer);
}

int64_t
sentrycrashcrs_addUserReport(const char *report, int reportLength)
{
    pthread_mutex_lock(&g_mutex);
    int64_t currentID = getNextUniqueID();
    char crashReportPath[SentryCrashCRS_MAX_PATH_LENGTH];
    getCrashReportPathByID(currentID, crashReportPath);

    int fd = open(crashReportPath, O_WRONLY | O_CREAT, 0644);
    if (fd < 0) {
        SentryCrashLOG_ERROR("Could not open file %s: %s", crashReportPath, strerror(errno));
        goto done;
    }

    int bytesWritten = (int)write(fd, report, (unsigned)reportLength);
    if (bytesWritten < 0) {
        SentryCrashLOG_ERROR("Could not write to file %s: %s", crashReportPath, strerror(errno));
        goto done;
    } else if (bytesWritten < reportLength) {
        SentryCrashLOG_ERROR("Expected to write %d bytes to file %s, but only wrote %d",
            crashReportPath, reportLength, bytesWritten);
    }

done:
    if (fd >= 0) {
        close(fd);
    }
    pthread_mutex_unlock(&g_mutex);

    return currentID;
}

void
sentrycrashcrs_deleteAllReports(void)
{
    pthread_mutex_lock(&g_mutex);
    sentrycrashfu_deleteContentsOfPath(g_reportsPath);
    pthread_mutex_unlock(&g_mutex);
}

void
sentrycrashcrs_deleteReportWithID(int64_t reportID)
{
    char path[SentryCrashCRS_MAX_PATH_LENGTH];
    getCrashReportPathByID(reportID, path);
    sentrycrashfu_removeFile(path, true);
}

void
sentrycrashcrs_setMaxReportCount(int maxReportCount)
{
    g_maxReportCount = maxReportCount;
}
