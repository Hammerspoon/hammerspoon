#import "SentryDefines.h"

#ifdef __cplusplus
extern "C" {
#endif
bool debugEnabled(void);
bool infoEnabled(void);
bool warnEnabled(void);
bool errorEnabled(void);
bool fatalEnabled(void);
void logDebug(const char file[], int line, NSString *format, ...);
void logInfo(const char file[], int line, NSString *format, ...);
void logWarn(const char file[], int line, NSString *format, ...);
void logError(const char file[], int line, NSString *format, ...);
void logFatal(const char file[], int line, NSString *format, ...);
#ifdef __cplusplus
}
#endif

#define SENTRY_LOG_DEBUG(...)                                                                      \
    if (debugEnabled())                                                                            \
        logDebug(__FILE__, __LINE__, __VA_ARGS__);
#define SENTRY_LOG_INFO(...)                                                                       \
    if (infoEnabled())                                                                             \
        logInfo(__FILE__, __LINE__, __VA_ARGS__);
#define SENTRY_LOG_WARN(...)                                                                       \
    if (warnEnabled())                                                                             \
        logWarn(__FILE__, __LINE__, __VA_ARGS__);
#define SENTRY_LOG_ERROR(...)                                                                      \
    if (errorEnabled())                                                                            \
        logError(__FILE__, __LINE__, __VA_ARGS__);
#define SENTRY_LOG_FATAL(...)                                                                      \
    if (fatalEnabled())                                                                            \
        logFatal(__FILE__, __LINE__, __VA_ARGS__);

/**
 * If @c errno is set to a non-zero value after @c statement finishes executing,
 * the error value is logged, and the original return value of @c statement is
 * returned.
 */
#define SENTRY_LOG_ERRNO(statement)                                                                \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const int __log_rv = (statement);                                                          \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_LOG_ERROR(@"%s failed with code: %d, description: %s", #statement,              \
                __log_errnum, strerror(__log_errnum));                                             \
        }                                                                                          \
        __log_rv;                                                                                  \
    })
