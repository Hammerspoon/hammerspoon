#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@property (strong, nonatomic) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (instancetype)init
{
    return [self initWithDispatchQueueWrapper:[SentryDependencyContainer sharedInstance]
                                                  .dispatchQueueWrapper];
}

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{
            // Needed to read the device orientation on demand
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
    return self;
}

- (void)stop
{
    [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{
        if (self.cleanupDeviceOrientationNotifications) {
            [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
        }
        if (self.cleanupBatteryMonitoring) {
            UIDevice.currentDevice.batteryMonitoringEnabled = NO;
        }
    }];
}

- (void)dealloc
{
    [self stop];
}

- (UIDeviceOrientation)orientation
{
    return UIDevice.currentDevice.orientation;
}

- (BOOL)isBatteryMonitoringEnabled
{
    return UIDevice.currentDevice.isBatteryMonitoringEnabled;
}

- (UIDeviceBatteryState)batteryState
{
    return UIDevice.currentDevice.batteryState;
}

- (float)batteryLevel
{
    return UIDevice.currentDevice.batteryLevel;
}

#endif

@end

NS_ASSUME_NONNULL_END
