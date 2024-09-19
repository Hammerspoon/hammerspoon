#include "SentrySessionReplaySyncC.h"
#include "SentryAsyncSafeLog.h"
#include <SentryCrashFileUtils.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static SentryCrashReplay crashReplay = { 0 };

void
sentrySessionReplaySync_start(const char *const path)
{
    crashReplay.lastSegmentEnd = 0;
    crashReplay.segmentId = 0;

    if (crashReplay.path != NULL) {
        free(crashReplay.path);
    }

    crashReplay.path = malloc(strlen(path));
    strcpy(crashReplay.path, path);
}

void
sentrySessionReplaySync_updateInfo(unsigned int segmentId, double lastSegmentEnd)
{
    crashReplay.segmentId = segmentId;
    crashReplay.lastSegmentEnd = lastSegmentEnd;
}

void
sentrySessionReplaySync_writeInfo(void)
{
    int fd = open(crashReplay.path, O_RDWR | O_CREAT | O_TRUNC, 0644);

    if (fd < 1) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Could not open replay info crash for file %s: %s", crashReplay.path, strerror(errno));
        return;
    }

    if (!sentrycrashfu_writeBytesToFD(
            fd, (char *)&crashReplay.segmentId, sizeof(crashReplay.segmentId))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing replay info for crash.");
        close(fd);
        return;
    }

    if (!sentrycrashfu_writeBytesToFD(
            fd, (char *)&crashReplay.lastSegmentEnd, sizeof(crashReplay.lastSegmentEnd))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing replay info for crash.");
        close(fd);
        return;
    }

    close(fd);
}

bool
sentrySessionReplaySync_readInfo(SentryCrashReplay *output, const char *const path)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Could not open replay info crash file %s: %s", path, strerror(errno));
        return false;
    }

    unsigned int segmentId = 0;
    double lastSegmentEnd = 0;

    if (!sentrycrashfu_readBytesFromFD(fd, (char *)&segmentId, sizeof(segmentId))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error reading segmentId from replay info crash file.");
        close(fd);
        return false;
    }

    if (!sentrycrashfu_readBytesFromFD(fd, (char *)&lastSegmentEnd, sizeof(lastSegmentEnd))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error reading lastSegmentEnd from replay info crash file.");
        close(fd);
        return false;
    }

    close(fd);

    if (lastSegmentEnd == 0) {
        return false;
    }

    output->segmentId = segmentId;
    output->lastSegmentEnd = lastSegmentEnd;
    return true;
}
