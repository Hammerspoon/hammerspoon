#import "SentryDefines.h"

@class SentryCrashWrapper;

#if SENTRY_HAS_UIKIT
@class SentryWatchdogTerminationLogic;
#endif // SENTRY_HAS_UIKIT

@interface SentryCrashIntegrationSessionHandler : NSObject

#if SENTRY_HAS_UIKIT
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic;
#else
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper;
#endif // SENTRY_HAS_UIKIT

/**
 * When a crash or a watchdog termination happens, we end the current session as crashed, store it
 * in a dedicated location, and delete the current one. The same applies if a fatal app hang occurs.
 * Then, we end the current session as abnormal and store it in a dedicated abnormal session
 * location.
 *
 * Check out the SentryHub, which implements most of the session logic, for more details about
 * sessions.
 */
- (void)endCurrentSessionIfRequired;

@end
