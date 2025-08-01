#import "SentryLogC.h"
#import "SentryAsyncSafeLog.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

void
sendLog(NSInteger level, const char file[], int line, NSString *format, va_list args)
{
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args];

    [SentrySDKLog logWithMessage:[NSString stringWithFormat:@"[%@:%d] %@",
                                     [[[NSString stringWithUTF8String:file] lastPathComponent]
                                         stringByDeletingPathExtension],
                                     line, formattedMessage]
                        andLevel:level];
}

bool
debugEnabled(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelDebug];
}
bool
infoEnabled(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelInfo];
}
bool
warnEnabled(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelWarning];
}
bool
errorEnabled(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelError];
}
bool
fatalEnabled(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelFatal];
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

NS_ASSUME_NONNULL_END
