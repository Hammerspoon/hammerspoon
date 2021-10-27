#import <Foundation/Foundation.h>
#import <NSDate+SentryExtras.h>
#import <SentryAppState.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryAppState

- (instancetype)initWithReleaseName:(NSString *)releaseName
                          osVersion:(NSString *)osVersion
                        isDebugging:(BOOL)isDebugging
                systemBootTimestamp:(NSDate *)systemBootTimestamp
{
    if (self = [super init]) {
        _releaseName = releaseName;
        _osVersion = osVersion;
        _isDebugging = isDebugging;

        // Round down to seconds as the precision of the serialization of the date is only
        // milliseconds. With this we avoid getting different dates before and after serialization.
        NSTimeInterval interval = round(systemBootTimestamp.timeIntervalSince1970);
        _systemBootTimestamp = [[NSDate alloc] initWithTimeIntervalSince1970:interval];

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

        id systemBoot = [jsonObject valueForKey:@"system_boot_timestamp"];
        if (systemBoot == nil || ![systemBoot isKindOfClass:[NSString class]])
            return nil;
        NSDate *systemBootTimestamp = [NSDate sentry_fromIso8601String:systemBoot];
        if (nil == systemBootTimestamp) {
            return nil;
        }
        _systemBootTimestamp = systemBootTimestamp;

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
    [data setValue:[self.systemBootTimestamp sentry_toIso8601String]
            forKey:@"system_boot_timestamp"];
    [data setValue:@(self.isActive) forKey:@"is_active"];
    [data setValue:@(self.wasTerminated) forKey:@"was_terminated"];

    return data;
}

@end

NS_ASSUME_NONNULL_END
