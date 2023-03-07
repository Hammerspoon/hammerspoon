#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;

@interface SentryUIDeviceWrapper : NSObject

#if TARGET_OS_IOS
- (instancetype)init;
- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;
- (void)stop;
- (UIDeviceOrientation)orientation;
- (BOOL)isBatteryMonitoringEnabled;
- (UIDeviceBatteryState)batteryState;
- (float)batteryLevel;
#endif

@end

NS_ASSUME_NONNULL_END
