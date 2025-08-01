#import "SentryAsyncLog.h"
#import "SentryAsyncSafeLog.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLogC.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryAsyncLogWrapper

+ (void)initializeAsyncLogFile
{
    const char *asyncLogPath =
        [[sentryStaticCachesPath() stringByAppendingPathComponent:@"async.log"] UTF8String];

    NSError *error;
    if (!createDirectoryIfNotExists(sentryStaticCachesPath(), &error)) {
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

@end

NS_ASSUME_NONNULL_END
