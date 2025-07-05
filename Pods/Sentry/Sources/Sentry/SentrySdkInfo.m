#import "SentrySdkInfo.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryMeta.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo ()
@end

@implementation SentrySdkInfo

+ (instancetype)global
{
    SentryClient *_Nullable client = [SentrySDK.currentHub getClient];
    return [[SentrySdkInfo alloc] initWithOptions:client.options];
}

- (instancetype)initWithOptions:(SentryOptions *_Nullable)options
{

    NSArray<NSString *> *features =
        [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];

    NSMutableArray<NSString *> *integrations =
        [SentrySDK.currentHub trimmedInstalledIntegrationNames];

#if SENTRY_HAS_UIKIT
    if (options.enablePreWarmedAppStartTracing) {
        [integrations addObject:@"PreWarmedAppStartTracing"];
    }
#endif

    NSMutableSet<NSDictionary<NSString *, NSString *> *> *packages =
        [SentryExtraPackages getPackages];
    NSDictionary<NSString *, NSString *> *sdkPackage = [SentrySdkPackage global];
    if (sdkPackage != nil) {
        [packages addObject:sdkPackage];
    }

    return [self initWithName:SentryMeta.sdkName
                      version:SentryMeta.versionString
                 integrations:integrations
                     features:features
                     packages:[packages allObjects]];
}

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                integrations:(NSArray<NSString *> *)integrations
                    features:(NSArray<NSString *> *)features
                    packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _integrations = integrations ?: @[];
        _features = features ?: @[];
        _packages = packages ?: @[];
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    NSString *name = @"";
    NSString *version = @"";
    NSMutableSet<NSString *> *integrations = [[NSMutableSet alloc] init];
    NSMutableSet<NSString *> *features = [[NSMutableSet alloc] init];
    NSMutableSet<NSDictionary<NSString *, NSString *> *> *packages = [[NSMutableSet alloc] init];

    if ([dict[@"name"] isKindOfClass:[NSString class]]) {
        name = dict[@"name"];
    }

    if ([dict[@"version"] isKindOfClass:[NSString class]]) {
        version = dict[@"version"];
    }

    if ([dict[@"integrations"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"integrations"]) {
            if ([item isKindOfClass:[NSString class]]) {
                [integrations addObject:item];
            }
        }
    }

    if ([dict[@"features"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"features"]) {
            if ([item isKindOfClass:[NSString class]]) {
                [features addObject:item];
            }
        }
    }

    if ([dict[@"packages"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"packages"]) {
            if ([item isKindOfClass:[NSDictionary class]] &&
                [item[@"name"] isKindOfClass:[NSString class]] &&
                [item[@"version"] isKindOfClass:[NSString class]]) {
                [packages addObject:@{ @"name" : item[@"name"], @"version" : item[@"version"] }];
            }
        }
    }

    return [self initWithName:name
                      version:version
                 integrations:[integrations allObjects]
                     features:[features allObjects]
                     packages:[packages allObjects]];
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"name" : self.name,
        @"version" : self.version,
        @"integrations" : self.integrations,
        @"features" : self.features,
        @"packages" : self.packages,
    };
}

@end

NS_ASSUME_NONNULL_END
