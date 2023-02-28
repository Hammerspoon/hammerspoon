#include "SentryProfilingLogging.hpp"

#import "SentryLog.h"

namespace sentry {
namespace profiling {
    namespace {
        SentryLevel
        sentryLevelFromLogLevel(LogLevel level)
        {
            switch (level) {
            case LogLevel::None:
                return kSentryLevelNone;
            case LogLevel::Debug:
                return kSentryLevelDebug;
            case LogLevel::Info:
                return kSentryLevelInfo;
            case LogLevel::Warning:
                return kSentryLevelWarning;
            case LogLevel::Error:
                return kSentryLevelError;
            case LogLevel::Fatal:
                return kSentryLevelFatal;
            }
        }
    }

    void
    log(LogLevel level, const char *fmt, ...)
    {
        if (fmt == nullptr) {
            return;
        }
        va_list args;
        va_start(args, fmt);
        const auto fmtStr = [[NSString alloc] initWithUTF8String:fmt];
        const auto msgStr = [[NSString alloc] initWithFormat:fmtStr arguments:args];
        va_end(args);
        [SentryLog logWithMessage:msgStr andLevel:sentryLevelFromLogLevel(level)];
    }

} // namespace profiling
} // namespace sentry
