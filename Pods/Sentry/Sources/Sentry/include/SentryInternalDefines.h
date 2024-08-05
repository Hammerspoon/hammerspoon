#import "SentryLog.h"
#import <Foundation/Foundation.h>

static NSString *const SentryDebugImageType = @"macho";
static NSString *const SentryPlatformName = @"cocoa";

#define SENTRY_DEFAULT_SAMPLE_RATE @1
#define SENTRY_DEFAULT_TRACES_SAMPLE_RATE @0
#define SENTRY_DEFAULT_PROFILES_SAMPLE_RATE @0

/**
 * Abort in debug, and log a warning in production.
 */
#define SENTRY_GRACEFUL_FATAL(...)                                                                 \
    SENTRY_LOG_WARN(__VA_ARGS__);                                                                  \
    NSAssert(NO, __VA_ARGS__);

/**
 * Abort if assertion fails in debug, and log a warning if it fails in production.
 */
#define SENTRY_ASSERT(cond, ...)                                                                   \
    if (!(cond)) {                                                                                 \
        SENTRY_LOG_WARN(__VA_ARGS__);                                                              \
        NSAssert(NO, __VA_ARGS__);                                                                 \
    }

/**
 * Abort if assertion fails in debug, and log a warning if it fails in production.
 */
#define SENTRY_CASSERT(cond, ...)                                                                  \
    if (!(cond)) {                                                                                 \
        SENTRY_LOG_WARN(__VA_ARGS__);                                                              \
        NSCAssert(NO, __VA_ARGS__);                                                                \
    }

/**
 * Abort if assertion fails in debug, and log a warning if it fails in production.
 * @return The result of the assertion condition, so it can be used to e.g. early return from the
 * point of it's check if that's also desirable in production.
 */
#define SENTRY_ASSERT_RETURN(cond, ...)                                                            \
    ({                                                                                             \
        BOOL __cond_result = (cond);                                                               \
        if (!__cond_result) {                                                                      \
            SENTRY_LOG_WARN(__VA_ARGS__);                                                          \
            NSAssert(NO, __VA_ARGS__);                                                             \
        }                                                                                          \
        (__cond_result);                                                                           \
    })

/**
 * Abort if assertion fails in a C context in debug, and log a warning if it fails in production.
 * @return The result of the assertion condition, so it can be used to e.g. early return from the
 * point of it's check if that's also desirable in production.
 */
#define SENTRY_CASSERT_RETURN(cond, ...)                                                           \
    ({                                                                                             \
        BOOL __cond_result = (cond);                                                               \
        if (!__cond_result) {                                                                      \
            SENTRY_LOG_WARN(__VA_ARGS__);                                                          \
            NSCAssert(NO, __VA_ARGS__);                                                            \
        }                                                                                          \
        (__cond_result);                                                                           \
    })

#define SPAN_DATA_BLOCKED_MAIN_THREAD @"blocked_main_thread"
#define SPAN_DATA_THREAD_ID @"thread.id"
#define SPAN_DATA_THREAD_NAME @"thread.name"
