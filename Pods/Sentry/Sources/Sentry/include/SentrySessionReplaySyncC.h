#ifndef SentrySessionReplaySyncC_h
#define SentrySessionReplaySyncC_h
#include <stdbool.h>

typedef struct {
    unsigned int segmentId;
    double lastSegmentEnd;
    char *path;
} SentryCrashReplay;

void sentrySessionReplaySync_start(const char *const path);

void sentrySessionReplaySync_updateInfo(unsigned int segmentId, double lastSegmentEnd);

void sentrySessionReplaySync_writeInfo(void);

bool sentrySessionReplaySync_readInfo(SentryCrashReplay *output, const char *const path);

#endif /* SentrySessionReplaySyncC_h */
