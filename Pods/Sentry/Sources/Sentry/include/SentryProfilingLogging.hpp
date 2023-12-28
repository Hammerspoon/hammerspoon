#pragma once

#if defined(DEBUG)

#    include <cerrno>
#    include <cstring>
#    include <string>
#    include <unistd.h>
#    include <vector>

namespace sentry {
namespace profiling {

    enum class LogLevel { None, Debug, Info, Warning, Error, Fatal };
    /**
     * Exposes a pure C++ interface to the Objective-C Sentry logging API so that
     * this can be used from C++ code without having to import Objective-C stuff.
     */
    void log(LogLevel level, const char *fmt, ...);

} // namespace profiling
} // namespace sentry

#    define SENTRY_PROF_LOG_DEBUG(...)                                                             \
        sentry::profiling::log(sentry::profiling::LogLevel::Debug, __VA_ARGS__)
#    define SENTRY_PROF_LOG_WARN(...)                                                              \
        sentry::profiling::log(sentry::profiling::LogLevel::Warning, __VA_ARGS__)
#    define SENTRY_PROF_LOG_ERROR(...)                                                             \
        sentry::profiling::log(sentry::profiling::LogLevel::Error, __VA_ARGS__)

#else

// Don't do anything with these in production until we can get a logging solution in place that
// doesn't use NSLog. We can't use NSLog in these codepaths because it takes a lock, and if the
// profiler's sampling thread is terminated before it can release that lock, then subsequent
// attempts to acquire it can cause a crash.
// See https://github.com/getsentry/sentry-cocoa/issues/3336#issuecomment-1802892052 for more info.
#    define SENTRY_PROF_LOG_DEBUG(...)
#    define SENTRY_PROF_LOG_WARN(...)
#    define SENTRY_PROF_LOG_ERROR(...)

#endif // defined(DEBUG)

/**
 * Logs the error code returned by executing `statement`, and returns the
 * error code (i.e. returns the return value of `statement`).
 */
#define SENTRY_PROF_LOG_ERROR_RETURN(statement)                                                    \
    ({                                                                                             \
        const int __log_errnum = statement;                                                        \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_PROF_LOG_ERROR("%s failed with code: %d, description: %s", #statement,          \
                __log_errnum, std::strerror(__log_errnum));                                        \
        }                                                                                          \
        __log_errnum;                                                                              \
    })
