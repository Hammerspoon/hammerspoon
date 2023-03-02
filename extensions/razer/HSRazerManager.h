@import Foundation;
@import IOKit;
@import IOKit.hid;

@import LuaSkin;

#import "HSRazerDevice.h"

#import "HSRazerNostromoDevice.h"

#import "HSRazerOrbweaverDevice.h"
#import "HSRazerOrbweaverChromaDevice.h"

#import "HSRazerTartarusDevice.h"
#import "HSRazerTartarusChromaDevice.h"
#import "HSRazerTartarusV2Device.h"
#import "HSRazerTartarusProDevice.h"

#import "razer.h"

@interface HSRazerManager : NSObject
@property (nonatomic, strong) id ioHIDManager;
@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic) int discoveryCallbackRef;

- (id)init;
- (void)doGC;
- (BOOL)startHIDManager;
- (BOOL)stopHIDManager;
- (HSRazerDevice*)deviceDidConnect:(IOHIDDeviceRef)device;
- (void)deviceDidDisconnect:(IOHIDDeviceRef)device;

@end
