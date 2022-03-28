#import "HSSpeedEditorManager.h"

#pragma mark - Report Struct's

typedef struct __attribute__ ((__packed__)) batteryReport {
    uint8_t reportID;
    uint8_t jogMode;
    int32_t jogValue;
    uint8_t unknown;
} jogWheelReport;

#pragma mark - IOKit C callbacks

static char *inputBuffer = NULL;

static void HIDReport(void* deviceRef, IOReturn result, void* sender, IOHIDReportType type, uint32_t reportID, uint8_t *report,CFIndex reportLength) {
    HSSpeedEditorDevice *device = (__bridge HSSpeedEditorDevice*)deviceRef;
    
    if (reportID == 3) {
        //
        // JOG WHEEL:
        //
        // Report ID: 03
        // u8   - Report ID
        // u8   - Jog mode
        // le32 - Jog value (signed)
        // u8   - Unknown ?
        //
        
        if (reportLength != 7) {
            [LuaSkin logError:@"[hs.speededitor] Unexpected Jog Wheel Report Length."];
        } else {
            jogWheelReport result = *(jogWheelReport *) report;
            
            NSNumber *jogMode = [NSNumber numberWithInt:result.jogMode];
            NSNumber *jogValue = [NSNumber numberWithInteger:result.jogValue];
            
            [device deviceJogWheelUpdateWithMode:jogMode value:jogValue];
        }
    } else if (reportID == 4) {
        //
        // BUTTON PRESS:
        //
        // Key Presses are reported in Input Report ID 4 as an array of 6 LE16 keycodes
        // that are currently being held down. 0x0000 is no key. No auto-repeat, no hw
        // detection of the 'fast double press'. Every time the set of key being held
        // down changes, a new report is sent.
        //
        // Report ID: 04
        // u8      - Report ID
        // le16[6] - Array of keys held down
        //
        
        if (reportLength != 13) {
            [LuaSkin logError:@"[hs.speededitor] Unexpected Button Report Length."];
        } else {
            // Get a blank button state dictionary:
            NSMutableDictionary *currentButtonState = [NSMutableDictionary dictionaryWithDictionary:device.defaultButtonState];
            
            // Get the current values:
            NSArray *allKeys = [device.buttonLookup allKeys];
            for (NSString *currentKey in allKeys) {
                NSNumber *currentValue = [device.buttonLookup valueForKeyPath:currentKey];
                for(int i = 1; i < reportLength; i++) {
                    if (report[i] == [currentValue unsignedIntValue]) {
                        [currentButtonState setObject:@YES forKey:currentKey];
                    }
                }
            }
            
            // Send current values to the device:
            [device deviceButtonUpdate:currentButtonState];
        }
    } else if (reportID == 7) {
        //
        // BATTERY STATUS:
        //
        // Report ID: 07
        // u8 - Report ID
        // u8 - Charging (1) / Not-charging (0)
        // u8 - Battery level (0-100)
        //
        
        if (reportLength != 3) {
            [LuaSkin logError:@"[hs.speededitor] Unexpected Battery Report Length."];
        } else {
            device.batteryCharging = report[1];
            device.batteryLevel = [NSNumber numberWithChar:report[2]];
        }
        
    } else {
        // TODO: Add the report id to the LuaSkin error message:
        [LuaSkin logError:@"[hs.speededitor] Unexpected Report ID."];
        NSLog(@"Unexpected Report ID: %u", reportID);
    }
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"connect: %p:%p", context, (void *)device);
    HSSpeedEditorManager *manager = (__bridge HSSpeedEditorManager *)context;
    HSSpeedEditorDevice *deviceId = [manager deviceDidConnect:device];
    if (deviceId) {
        IOHIDDeviceRegisterInputReportCallback(device, (uint8_t*)inputBuffer, 1024, HIDReport, (void*)deviceId);
        //NSLog(@"Added value callback to new IOKit device %p for Deck Device %p", (void *)device, (__bridge void*)deviceId);
    }
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"disconnect: %p", (void *)device);
    HSSpeedEditorManager *manager = (__bridge HSSpeedEditorManager *)context;
    [manager deviceDidDisconnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, NULL, NULL);
}

#pragma mark - Speed Editor Manager implementation
@implementation HSSpeedEditorManager

- (id)init {
    self = [super init];
    if (self) {
        self.devices = [[NSMutableArray alloc] initWithCapacity:5];
        self.discoveryCallbackRef = LUA_NOREF;
        inputBuffer = malloc(1024);

        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"Created HID Manager: %p", (void *)self.ioHIDManager);

        // Configure the HID manager to match against Speed Editor devices
        NSString *vendorIDKey = @(kIOHIDVendorIDKey);
        NSString *productIDKey = @(kIOHIDProductIDKey);

        NSDictionary *matchSpeedEditor   = @{vendorIDKey:  @USB_VID_BLACKMAGIC,
                                          productIDKey: @USB_PID_SPEED_EDITOR};
        
        IOHIDManagerSetDeviceMatchingMultiple((__bridge IOHIDManagerRef)self.ioHIDManager,
                                              (__bridge CFArrayRef)@[matchSpeedEditor]);

        // Add our callbacks for relevant events
        IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                   HIDconnect,
                                                   (__bridge void*)self);
        IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                  HIDdisconnect,
                                                  (__bridge void*)self);

        // Start our HID manager
        IOHIDManagerScheduleWithRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager,
                                        CFRunLoopGetCurrent(),
                                        kCFRunLoopDefaultMode);
    }
    return self;
}

- (void)doGC {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        // Something is wrong and the manager doesn't exist, so just bail
        return;
    }

    // Remove our callbacks
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);

    // Remove our HID manager from the runloop
    IOHIDManagerUnscheduleFromRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // Deallocate the HID manager
    self.ioHIDManager = nil;

    if (inputBuffer) {
        free(inputBuffer);
    }
}

- (BOOL)startHIDManager {
    IOReturn tIOReturn = IOHIDManagerOpen((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (BOOL)stopHIDManager {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        return YES;
    }

    IOReturn tIOReturn = IOHIDManagerClose((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (HSSpeedEditorDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
     _lua_stackguard_entry(skin.L);

     if (![skin checkGCCanary:self.lsCanary]) {
         _lua_stackguard_exit(skin.L);
         return nil;
     }

     if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
         [skin logWarn:@"hs.speededitor detected a device connecting, but no discovery callback has been set. See hs.speededitor.discoveryCallback()"];
         _lua_stackguard_exit(skin.L);
         return nil;
     }

    NSNumber *vendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    NSString *serialNumber = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDSerialNumberKey));
    
    if (vendorID.intValue != USB_VID_BLACKMAGIC) {
        NSLog(@"deviceDidConnect from unknown vendor: %d", vendorID.intValue);
        return nil;
    }

    HSSpeedEditorDevice *deck = nil;

    switch (productID.intValue) {
        case USB_PID_SPEED_EDITOR:
            deck = [[HSSpeedEditorDevice alloc] initWithDevice:device manager:self serialNumber:serialNumber];
            break;

        default:
            NSLog(@"deviceDidConnect from unknown device: %d", productID.intValue);
            break;
    }
    if (!deck) {
        NSLog(@"deviceDidConnect: no HSSpeedEditorDevice was created, ignoring");
        return nil;
    }
    
    //
    // Authenticate the Speed Editor:
    //
    [deck authenticate];
    
    deck.lsCanary = [skin createGCCanary];
    
    [self.devices addObject:deck];
    
    [skin pushLuaRef:speedEditorRefTable ref:self.discoveryCallbackRef];
    lua_pushboolean(skin.L, 1);
    [skin pushNSObject:deck];
    [skin protectedCallAndError:@"hs.speededitor:deviceDidConnect" nargs:2 nresults:0];

    //NSLog(@"Created Speed Editor device: %p", (__bridge void*)deviceId);
    //NSLog(@"Now have %lu devices", self.devices.count);
    _lua_stackguard_exit(skin.L);
    return deck;
}

- (void)deviceDidDisconnect:(IOHIDDeviceRef)device {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
     _lua_stackguard_entry(skin.L);

    if (![skin checkGCCanary:self.lsCanary]) {
        _lua_stackguard_exit(skin.L);
        return;
    }
    
    for (HSSpeedEditorDevice *deckDevice in self.devices) {
        if (deckDevice.device == device) {
            [deckDevice invalidate];
            
            if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
                [skin logWarn:@"hs.speededitor detected a device disconnecting, but no callback has been set. See hs.speededitor.discoveryCallback()"];
            } else {
                [skin pushLuaRef:speedEditorRefTable ref:self.discoveryCallbackRef];
                lua_pushboolean(skin.L, 0);
                [skin pushNSObject:deckDevice];
                [skin protectedCallAndError:@"hs.speededitor:deviceDidDisconnect" nargs:2 nresults:0];
            }

            LSGCCanary tmpLSUUID = deckDevice.lsCanary;
            [skin destroyGCCanary:&tmpLSUUID];
            deckDevice.lsCanary = tmpLSUUID;
            
            [self.devices removeObject:deckDevice];
            _lua_stackguard_exit(skin.L);
            return;
        }
    }
    NSLog(@"ERROR: A Speed Editor was disconnected that we didn't know about");
    _lua_stackguard_exit(skin.L);
    return;
}

@end
