/**
 * These declarations are needed in both SDK and test code, for use with various testing scenarios.
 */

#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Disable profiling when running with TSAN because it produces a TSAN false positive, similar to
 * the situation described here: https://github.com/envoyproxy/envoy/issues/2561
 */
SENTRY_EXTERN BOOL sentry_threadSanitizerIsPresent(void);

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

/**
 * Write a file to the disk cache containing the profile data. This is an affordance for UI
 * tests to be able to validate the contents of a profile.
 */
SENTRY_EXTERN void sentry_writeProfileFile(NSData *JSONData, BOOL continuous);

#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
