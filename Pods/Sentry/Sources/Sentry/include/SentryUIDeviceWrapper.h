#import "SentryDefines.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;

@interface SentryUIDeviceWrapper : NSObject

- (void)start;
- (void)stop;
- (UIDeviceOrientation)orientation;
- (BOOL)isBatteryMonitoringEnabled;
- (UIDeviceBatteryState)batteryState;
- (float)batteryLevel;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
