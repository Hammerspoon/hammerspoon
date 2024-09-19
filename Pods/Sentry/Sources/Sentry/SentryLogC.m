#import "SentryAsyncSafeLog.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

void
sentry_initializeAsyncLogFile(void)
{
    const char *asyncLogPath =
        [[sentryApplicationSupportPath() stringByAppendingPathComponent:@"async.log"] UTF8String];

    NSError *error;
    if (!createDirectoryIfNotExists(sentryApplicationSupportPath(), &error)) {
        SENTRY_LOG_ERROR(@"Failed to initialize directory for async log file: %@", error);
        return;
    }

    if (SENTRY_LOG_ERRNO(
            sentry_asyncLogSetFileName(asyncLogPath, true /* overwrite existing log */))
        != 0) {
        SENTRY_LOG_ERROR(
            @"Could not open a handle to specified path for async logging %s", asyncLogPath);
    };
}

NS_ASSUME_NONNULL_END
