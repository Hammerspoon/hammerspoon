#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@property (nonatomic, copy) NSString *systemVersion;
@end

@implementation SentryUIDeviceWrapper

- (void)start
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{

#    if TARGET_OS_IOS
        if (!UIDevice.currentDevice.isGeneratingDeviceOrientationNotifications) {
            self.cleanupDeviceOrientationNotifications = YES;
            [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
        }

        // Needed so we can read the battery level
        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            self.cleanupBatteryMonitoring = YES;
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }
#    endif

        self.systemVersion = [UIDevice currentDevice].systemVersion;
    }];
}

- (void)stop
{
#    if TARGET_OS_IOS
    BOOL needsCleanUp = self.cleanupDeviceOrientationNotifications;
    BOOL needsDisablingBattery = self.cleanupBatteryMonitoring;
    UIDevice *device = [UIDevice currentDevice];
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
        if (needsCleanUp) {
            [device endGeneratingDeviceOrientationNotifications];
        }
        if (needsDisablingBattery) {
            device.batteryMonitoringEnabled = NO;
        }
    }];
#    endif // TARGET_OS_IOS
}

- (void)dealloc
{
    [self stop];
}

#    if TARGET_OS_IOS
- (UIDeviceOrientation)orientation
{
    return (UIDeviceOrientation)[UIDevice currentDevice].orientation;
}

- (BOOL)isBatteryMonitoringEnabled
{
    return [UIDevice currentDevice].isBatteryMonitoringEnabled;
}

- (UIDeviceBatteryState)batteryState
{
    return (UIDeviceBatteryState)[UIDevice currentDevice].batteryState;
}

- (float)batteryLevel
{
    return [UIDevice currentDevice].batteryLevel;
}
#    endif // TARGET_OS_IOS

- (NSString *)getSystemVersion
{
    return self.systemVersion;
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
