#import <Foundation/Foundation.h>
#import <SentryAppState.h>

@implementation SentryAppState

- (instancetype)initWithReleaseName:(NSString *)releaseName
                          osVersion:(NSString *)osVersion
                        isDebugging:(BOOL)isDebugging
{
    if (self = [super init]) {
        _releaseName = releaseName;
        _osVersion = osVersion;
        _isDebugging = isDebugging;
        _isActive = NO;
        _wasTerminated = NO;
    }
    return self;
}

- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject
{
    if (self = [super init]) {
        id releaseName = [jsonObject valueForKey:@"release_name"];
        if (releaseName == nil || ![releaseName isKindOfClass:[NSString class]]) {
            return nil;
        } else {
            _releaseName = releaseName;
        }

        id osVersion = [jsonObject valueForKey:@"os_version"];
        if (osVersion == nil || ![osVersion isKindOfClass:[NSString class]]) {
            return nil;
        } else {
            _osVersion = osVersion;
        }

        id isDebugging = [jsonObject valueForKey:@"is_debugging"];
        if (isDebugging == nil || ![isDebugging isKindOfClass:[NSNumber class]]) {
            return nil;
        } else {
            _isDebugging = [isDebugging boolValue];
        }

        id isActive = [jsonObject valueForKey:@"is_active"];
        if (isActive == nil || ![isActive isKindOfClass:[NSNumber class]]) {
            return nil;
        } else {
            _isActive = [isActive boolValue];
        }

        id wasTerminated = [jsonObject valueForKey:@"was_terminated"];
        if (wasTerminated == nil || ![wasTerminated isKindOfClass:[NSNumber class]]) {
            return nil;
        } else {
            _wasTerminated = [wasTerminated boolValue];
        }
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];

    [data setValue:self.releaseName forKey:@"release_name"];
    [data setValue:self.osVersion forKey:@"os_version"];
    [data setValue:@(self.isDebugging) forKey:@"is_debugging"];
    [data setValue:@(self.isActive) forKey:@"is_active"];
    [data setValue:@(self.wasTerminated) forKey:@"was_terminated"];

    return data;
}

@end
