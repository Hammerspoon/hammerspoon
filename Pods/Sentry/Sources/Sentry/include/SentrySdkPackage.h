#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkPackage : NSObject
SENTRY_NO_INIT

+ (nullable NSDictionary<NSString *, NSString *> *)global;

#if SENTRY_TEST || SENTRY_TEST_CI
+ (void)setPackageManager:(NSUInteger)manager;
+ (void)resetPackageManager;
#endif

@end

NS_ASSUME_NONNULL_END
