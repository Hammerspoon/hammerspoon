@import Foundation;
@import IOKit;
@import IOKit.hid;

@import LuaSkin;

#import "HSBlackmagicDevice.h"
#import "HSBlackmagicDeviceKeyboard.h"
#import "HSBlackmagicDeviceSpeedEditor.h"

#import "blackmagic.h"

@interface HSBlackmagicManager : NSObject
@property (nonatomic, strong) id ioHIDManager;
@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic) int discoveryCallbackRef;
@property LSGCCanary lsCanary;

- (id)init;
- (void)doGC;
- (BOOL)startHIDManager;
- (BOOL)stopHIDManager;
- (HSBlackmagicDevice*)deviceDidConnect:(IOHIDDeviceRef)device;
- (void)deviceDidDisconnect:(IOHIDDeviceRef)device;

@end
