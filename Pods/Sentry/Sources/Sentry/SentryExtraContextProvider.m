#import "SentryExtraContextProvider.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryUIDeviceWrapper.h"

@interface
SentryExtraContextProvider ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;

@end

@implementation SentryExtraContextProvider

- (instancetype)init
{
    return
        [self initWithCrashWrapper:[SentryCrashWrapper sharedInstance]
                processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]];
}

- (instancetype)initWithCrashWrapper:(id)crashWrapper processInfoWrapper:(id)processInfoWrapper
{
    if (self = [super init]) {
        self.crashWrapper = crashWrapper;
        self.processInfoWrapper = processInfoWrapper;
    }
    return self;
}

- (NSDictionary *)getExtraContext
{
    return @{ @"device" : [self getExtraDeviceContext], @"app" : [self getExtraAppContext] };
}

- (NSDictionary *)getExtraDeviceContext
{
    NSMutableDictionary *extraDeviceContext = [[NSMutableDictionary alloc] init];

    extraDeviceContext[SentryDeviceContextFreeMemoryKey] = @(self.crashWrapper.freeMemorySize);
    extraDeviceContext[@"processor_count"] = @([self.processInfoWrapper processorCount]);

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    SentryUIDeviceWrapper *deviceWrapper = SentryDependencyContainer.sharedInstance.uiDeviceWrapper;
    if (deviceWrapper.orientation != UIDeviceOrientationUnknown) {
        extraDeviceContext[@"orientation"]
            = UIDeviceOrientationIsPortrait(deviceWrapper.orientation) ? @"portrait" : @"landscape";
    }

    if (deviceWrapper.isBatteryMonitoringEnabled) {
        extraDeviceContext[@"charging"]
            = deviceWrapper.batteryState == UIDeviceBatteryStateCharging ? @(YES) : @(NO);
        extraDeviceContext[@"battery_level"] = @((int)(deviceWrapper.batteryLevel * 100));
    }
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
    return extraDeviceContext;
}

- (NSDictionary *)getExtraAppContext
{
    return @{ SentryDeviceContextAppMemoryKey : @(self.crashWrapper.appMemorySize) };
}

@end
