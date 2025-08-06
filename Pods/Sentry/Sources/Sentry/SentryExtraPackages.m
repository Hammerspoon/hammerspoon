#import "SentryExtraPackages.h"
#import "SentryMeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryExtraPackages

static NSSet<NSDictionary<NSString *, NSString *> *> *extraPackages;

+ (void)initialize
{
    if (self == [SentryExtraPackages class]) {
        extraPackages = [[NSSet alloc] init];
    }
}

+ (void)addPackageName:(NSString *)name version:(NSString *)version
{
    if (name == nil || version == nil) {
        return;
    }

    @synchronized(extraPackages) {
        NSDictionary<NSString *, NSString *> *newPackage =
            @{ @"name" : name, @"version" : version };
        extraPackages = [extraPackages setByAddingObject:newPackage];
    }
}

+ (NSMutableSet<NSDictionary<NSString *, NSString *> *> *)getPackages
{
    @synchronized(extraPackages) {
        return [extraPackages mutableCopy];
    }
}

#if SENTRY_TEST || SENTRY_TEST_CI
+ (void)clear
{
    extraPackages = [[NSSet alloc] init];
}
#endif

@end

NS_ASSUME_NONNULL_END
