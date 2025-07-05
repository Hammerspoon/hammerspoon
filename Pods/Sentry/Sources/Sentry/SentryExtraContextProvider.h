#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

@class SentryCrashWrapper;
@class SentryNSProcessInfoWrapper;
@class SentryUIDeviceWrapper;

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
@class SentryUIDeviceWrapper;
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * Provider of dynamic context data that we need to read at the time of an exception.
 */
@interface SentryExtraContextProvider : NSObject
SENTRY_NO_INIT

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
                  processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
                       deviceWrapper:(SentryUIDeviceWrapper *)deviceWrapper
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
    ;

- (NSDictionary *)getExtraContext;

@end

NS_ASSUME_NONNULL_END
