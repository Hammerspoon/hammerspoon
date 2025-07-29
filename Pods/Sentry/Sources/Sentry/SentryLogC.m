#import "SentryLogC.h"
#import "SentryAsyncSafeLog.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

void
sendLog(NSInteger level, const char file[], int line, NSString *format, va_list args)
{
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args];

    [SentryLog logWithMessage:[NSString stringWithFormat:@"[%@:%d] %@",
                                  [[[NSString stringWithUTF8String:file] lastPathComponent]
                                      stringByDeletingPathExtension],
                                  line, formattedMessage]
                     andLevel:level];
}

bool
debugEnabled(void)
{
    return [SentryLog willLogAtLevel:kSentryLevelDebug];
}
bool
infoEnabled(void)
{
    return [SentryLog willLogAtLevel:kSentryLevelInfo];
}
bool
warnEnabled(void)
{
    return [SentryLog willLogAtLevel:kSentryLevelWarning];
}
bool
errorEnabled(void)
{
    return [SentryLog willLogAtLevel:kSentryLevelError];
}
bool
fatalEnabled(void)
{
    return [SentryLog willLogAtLevel:kSentryLevelFatal];
}

void
logDebug(const char file[], int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    sendLog(kSentryLevelDebug, file, line, format, args);
    va_end(args);
}

void
logInfo(const char file[], int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    sendLog(kSentryLevelInfo, file, line, format, args);
    va_end(args);
}

void
logWarn(const char file[], int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    sendLog(kSentryLevelWarning, file, line, format, args);
    va_end(args);
}

void
logError(const char file[], int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    sendLog(kSentryLevelError, file, line, format, args);
    va_end(args);
}

void
logFatal(const char file[], int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    sendLog(kSentryLevelFatal, file, line, format, args);
    va_end(args);
}

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
