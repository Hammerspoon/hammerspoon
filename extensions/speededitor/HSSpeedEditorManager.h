@import Foundation;
@import IOKit;
@import IOKit.hid;

@import LuaSkin;

#import "HSSpeedEditorDevice.h"
#import "speededitor.h"

@interface HSSpeedEditorManager : NSObject
@property (nonatomic, strong) id ioHIDManager;
@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic) int discoveryCallbackRef;
@property LSGCCanary lsCanary;

- (id)init;
- (void)doGC;
- (BOOL)startHIDManager;
- (BOOL)stopHIDManager;
- (HSSpeedEditorDevice*)deviceDidConnect:(IOHIDDeviceRef)device;
- (void)deviceDidDisconnect:(IOHIDDeviceRef)device;

@end
