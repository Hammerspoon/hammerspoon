#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    define SentryDidBecomeActiveNotification UIApplicationDidBecomeActiveNotification
#    define SentryWillResignActiveNotification UIApplicationWillResignActiveNotification
#    define SentryWillTerminateNotification UIApplicationWillTerminateNotification
#elif SENTRY_TARGET_MACOS_HAS_UI
#    define SentryDidBecomeActiveNotification NSApplicationDidBecomeActiveNotification
#    define SentryWillResignActiveNotification NSApplicationWillResignActiveNotification
#    define SentryWillTerminateNotification NSApplicationWillTerminateNotification
#endif
