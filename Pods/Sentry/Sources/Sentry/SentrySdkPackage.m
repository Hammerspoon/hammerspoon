#import "SentrySdkPackage.h"
#import "SentryMeta.h"

typedef NS_ENUM(NSUInteger, SentryPackageManagerOption) {
    SentrySwiftPackageManager,
    SentryCocoaPods,
    SentryCarthage,
    SentryPackageManagerUnkown
};

/**
 * This is required to identify the package manager used when installing sentry.
 */
#if SWIFT_PACKAGE
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentrySwiftPackageManager;
#elif COCOAPODS
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryCocoaPods;
#elif CARTHAGE_YES
// CARTHAGE is a xcodebuild build setting with value `YES`, we need to convert it into a compiler
// definition to be able to use it.
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryCarthage;
#else
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryPackageManagerUnkown;
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySdkPackage

+ (nullable NSString *)getSentrySDKPackageName:(SentryPackageManagerOption)packageManager
{
    switch (packageManager) {
    case SentrySwiftPackageManager:
        return [NSString stringWithFormat:@"spm:getsentry/%@", SentryMeta.sdkName];
    case SentryCocoaPods:
        return [NSString stringWithFormat:@"cocoapods:getsentry/%@", SentryMeta.sdkName];
    case SentryCarthage:
        return [NSString stringWithFormat:@"carthage:getsentry/%@", SentryMeta.sdkName];
    default:
        return nil;
    }
}

+ (nullable NSDictionary<NSString *, NSString *> *)getSentrySDKPackage:
    (SentryPackageManagerOption)packageManager
{

    if (packageManager == SentryPackageManagerUnkown) {
        return nil;
    }

    NSString *name = [SentrySdkPackage getSentrySDKPackageName:packageManager];
    if (nil == name) {
        return nil;
    }

    return @{ @"name" : name, @"version" : SentryMeta.versionString };
}

+ (nullable NSDictionary<NSString *, NSString *> *)global
{
    return [SentrySdkPackage getSentrySDKPackage:SENTRY_PACKAGE_INFO];
}

#if SENTRY_TEST || SENTRY_TEST_CI
+ (void)setPackageManager:(NSUInteger)manager
{
    SENTRY_PACKAGE_INFO = manager;
}

+ (void)resetPackageManager
{
    SENTRY_PACKAGE_INFO = SentryPackageManagerUnkown;
}
#endif

@end

NS_ASSUME_NONNULL_END
