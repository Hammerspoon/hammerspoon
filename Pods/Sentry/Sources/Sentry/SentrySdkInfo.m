#import "SentrySdkInfo.h"
#import <Foundation/Foundation.h>

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

@interface
SentrySdkInfo ()

@property (nonatomic) SentryPackageManagerOption packageManager;

@end

@implementation SentrySdkInfo

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _packageManager = SENTRY_PACKAGE_INFO;
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    return [self initWithDictInternal:dict orDefaults:nil];
}

- (instancetype)initWithDict:(NSDictionary *)dict orDefaults:(SentrySdkInfo *)info;
{
    return [self initWithDictInternal:dict orDefaults:info];
}

- (instancetype)initWithDictInternal:(NSDictionary *)dict orDefaults:(SentrySdkInfo *_Nullable)info;
{
    NSString *name = @"";
    NSString *version = @"";

    if (nil != dict[@"sdk"] && [dict[@"sdk"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *sdkInfoDict = dict[@"sdk"];
        if ([sdkInfoDict[@"name"] isKindOfClass:[NSString class]]) {
            name = sdkInfoDict[@"name"];
        } else if (info && info.name) {
            name = info.name;
        }

        if ([sdkInfoDict[@"version"] isKindOfClass:[NSString class]]) {
            version = sdkInfoDict[@"version"];
        } else if (info && info.version) {
            version = info.version;
        }
    }

    return [self initWithName:name andVersion:version];
}

- (nullable NSString *)getPackageName:(SentryPackageManagerOption)packageManager
{
    switch (packageManager) {
    case SentrySwiftPackageManager:
        return @"spm:getsentry/%@";
    case SentryCocoaPods:
        return @"cocoapods:getsentry/%@";
    case SentryCarthage:
        return @"carthage:getsentry/%@";
    default:
        return nil;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *sdk = @{
        @"name" : self.name,
        @"version" : self.version,
    }
                                   .mutableCopy;
    if (self.packageManager != SentryPackageManagerUnkown) {
        NSString *format = [self getPackageName:self.packageManager];
        if (format != nil) {
            sdk[@"packages"] = @{
                @"name" : [NSString stringWithFormat:format, self.name],
                @"version" : self.version
            };
        }
    }

    return @{ @"sdk" : sdk };
}

@end

NS_ASSUME_NONNULL_END
