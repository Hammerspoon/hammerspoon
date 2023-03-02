#import "SentrySdkInfo.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySdkInfo

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    if (self = [super init]) {

        if (name.length == 0) {
            _name = @"";
        } else {
            _name = name;
        }

        if (version.length == 0) {
            _version = @"";
        } else {
            _version = version;
        }
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    NSString *name = @"";
    NSString *version = @"";

    if (nil != dict[@"sdk"] && [dict[@"sdk"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *sdkInfoDict = dict[@"sdk"];
        if ([sdkInfoDict[@"name"] isKindOfClass:[NSString class]]) {
            name = sdkInfoDict[@"name"];
        }

        if ([sdkInfoDict[@"version"] isKindOfClass:[NSString class]]) {
            version = sdkInfoDict[@"version"];
        }
    }

    return [self initWithName:name andVersion:version];
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"sdk" : @ { @"name" : self.name, @"version" : self.version } };
}

@end

NS_ASSUME_NONNULL_END
