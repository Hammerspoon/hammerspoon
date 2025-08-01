#import "SentryLogC.h"
#import <Foundation/Foundation.h>

static NSString *const SentryDebugImageType = @"macho";
static NSString *const SentryPlatformName = @"cocoa";

#define SENTRY_DEFAULT_SAMPLE_RATE @1
#define SENTRY_DEFAULT_TRACES_SAMPLE_RATE @0

/**
 * The value we give when initializing the options object, and what it will be if a consumer never
 * modifies it in their SDK config.
 * */
#define SENTRY_INITIAL_PROFILES_SAMPLE_RATE nil

/**
 * The default value we will give for profiles sample rate if an invalid value is supplied for the
 * options property in config or returned from the sampler function.
 */
#define SENTRY_DEFAULT_PROFILES_SAMPLE_RATE @0

/**
 * Abort in debug, and log a warning in production. Meant to help customers while they work locally,
 * but not crash their app in production if a condition inadvertently becomes true.
 */
#define SENTRY_GRACEFUL_FATAL(...)                                                                 \
    SENTRY_LOG_WARN(__VA_ARGS__);                                                                  \
    NSAssert(NO, __VA_ARGS__);

/**
 * Abort in test, log a warning otherwise. Meant to help us fail faster in our own development, but
 * never crash customers because since it's not something they can control with their own
 * configuration.
 */
#if SENTRY_TEST || SENTRY_TEST_CI
#    define SENTRY_TEST_FATAL(...) SENTRY_CASSERT(NO, __VA_ARGS__)
#else
#    define SENTRY_TEST_FATAL(...) SENTRY_LOG_WARN(__VA_ARGS__)
#endif // SENTRY_TEST || SENTRY_TEST_CI

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
