#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIDeviceWrapper : NSObject

- (void)start;
- (void)stop;

#    if TARGET_OS_IOS
- (UIDeviceOrientation)orientation;
- (BOOL)isBatteryMonitoringEnabled;
- (UIDeviceBatteryState)batteryState;
- (float)batteryLevel;
#    endif // TARGET_OS_IOS

- (NSString *)getSystemVersion;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
