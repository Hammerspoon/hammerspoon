#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

- (void)start
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
        if (!UIDevice.currentDevice.isGeneratingDeviceOrientationNotifications) {
            self.cleanupDeviceOrientationNotifications = YES;
            [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
        }

        // Needed so we can read the battery level
        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            self.cleanupBatteryMonitoring = YES;
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }
    }];
}

- (void)stop
{
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
}

- (void)dealloc
{
    [self stop];
}

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

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
