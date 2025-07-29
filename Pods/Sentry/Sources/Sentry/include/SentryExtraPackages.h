#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryExtraPackages : NSObject
SENTRY_NO_INIT

+ (void)addPackageName:(NSString *)name version:(NSString *)version;
+ (NSMutableSet<NSDictionary<NSString *, NSString *> *> *)getPackages;

#if SENTRY_TEST || SENTRY_TEST_CI
+ (void)clear;
#endif

@end

NS_ASSUME_NONNULL_END
