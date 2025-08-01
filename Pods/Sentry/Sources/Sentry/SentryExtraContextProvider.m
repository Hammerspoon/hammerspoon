#import "SentryExtraContextProvider.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryLogC.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryUIDeviceWrapper.h"

NSString *const kSentryProcessInfoThermalStateNominal = @"nominal";
NSString *const kSentryProcessInfoThermalStateFair = @"fair";
NSString *const kSentryProcessInfoThermalStateSerious = @"serious";
NSString *const kSentryProcessInfoThermalStateCritical = @"critical";

@interface SentryExtraContextProvider ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIDeviceWrapper *deviceWrapper;
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

@end

@implementation SentryExtraContextProvider

- (instancetype)initWithCrashWrapper:(id)crashWrapper
                  processInfoWrapper:(id)processInfoWrapper
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
                       deviceWrapper:(SentryUIDeviceWrapper *)deviceWrapper
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
{
    if (self = [super init]) {
        self.crashWrapper = crashWrapper;
        self.processInfoWrapper = processInfoWrapper;
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
        self.deviceWrapper = deviceWrapper;
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
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

    NSProcessInfoThermalState thermalState = [self.processInfoWrapper thermalState];
    switch (thermalState) {
    case NSProcessInfoThermalStateNominal:
        extraDeviceContext[@"thermal_state"] = kSentryProcessInfoThermalStateNominal;
        break;
    case NSProcessInfoThermalStateFair:
        extraDeviceContext[@"thermal_state"] = kSentryProcessInfoThermalStateFair;
        break;
    case NSProcessInfoThermalStateSerious:
        extraDeviceContext[@"thermal_state"] = kSentryProcessInfoThermalStateSerious;
        break;
    case NSProcessInfoThermalStateCritical:
        extraDeviceContext[@"thermal_state"] = kSentryProcessInfoThermalStateCritical;
        break;
    default:
        SENTRY_LOG_WARN(@"Unexpected thermal state enum value: %ld", (long)thermalState);
        break;
    }

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    if (self.deviceWrapper.orientation != UIDeviceOrientationUnknown) {
        extraDeviceContext[@"orientation"]
            = UIDeviceOrientationIsPortrait(self.deviceWrapper.orientation) ? @"portrait"
                                                                            : @"landscape";
    }

    if (self.deviceWrapper.isBatteryMonitoringEnabled) {
        extraDeviceContext[@"charging"]
            = self.deviceWrapper.batteryState == UIDeviceBatteryStateCharging ? @(YES) : @(NO);
        extraDeviceContext[@"battery_level"] = @((int)(self.deviceWrapper.batteryLevel * 100));
    }
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
    return extraDeviceContext;
}

- (NSDictionary *)getExtraAppContext
{
    return @{ SentryDeviceContextAppMemoryKey : @(self.crashWrapper.appMemorySize) };
}

@end
