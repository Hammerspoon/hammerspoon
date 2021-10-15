#import "HSRazerManager.h"

#pragma mark - IOKit C callbacks

static void HIDcallback(void* context, IOReturn result, void* sender, IOHIDValueRef value)
{
    NSNumber *locationID = (__bridge NSNumber *)IOHIDDeviceGetProperty(sender, CFSTR(kIOHIDLocationIDKey));
    if (!locationID) {
        return;
    }
    HSRazerManager *manager = (__bridge HSRazerManager *)context;
    for (HSRazerDevice *device in manager.devices) {
        if (device.locationID == locationID) {
            IOHIDElementRef elem = IOHIDValueGetElement(value);
            uint32_t scancode = IOHIDElementGetUsage(elem);
            long pressed = IOHIDValueGetIntegerValue(value);

            if (scancode < 4 || scancode > 231) {
                return;
            }

            NSString *scancodeString = [NSString stringWithFormat:@"%d",scancode];

            [device deviceButtonPress:scancodeString pressed:pressed];
        }
    }
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"[hs.razer] connect: %p:%p", context, (void *)device);
    HSRazerManager *manager = (__bridge HSRazerManager *)context;
    [manager deviceDidConnect:device];
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"[hs.razer] disconnect: %p", (void *)device);
    HSRazerManager *manager = (__bridge HSRazerManager *)context;
    [manager deviceDidDisconnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, NULL, NULL);
}

#pragma mark - Razer Manager implementation

@implementation HSRazerManager

- (id)init {
    self = [super init];
    if (self) {
        self.devices = [[NSMutableArray alloc] initWithCapacity:1];
        self.discoveryCallbackRef = LUA_NOREF;

        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"[hs.razer] Created HID Manager: %p", (void *)self.ioHIDManager);

        // Configure the HID manager to match against Razer devices:
        NSString *vendorIDKey = @(kIOHIDVendorIDKey);
        NSString *productIDKey = @(kIOHIDProductIDKey);

        NSDictionary *matchTartarusV2   =   @{vendorIDKey:  @USB_VID_RAZER,
                                              productIDKey: @USB_PID_RAZER_TARTARUS_V2};

        IOHIDManagerSetDeviceMatchingMultiple((__bridge IOHIDManagerRef)self.ioHIDManager,
                                              (__bridge CFArrayRef)@[matchTartarusV2]);

        // Add our callbacks for relevant events:
        IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                   HIDconnect,
                                                   (__bridge void*)self);

        IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                                  HIDdisconnect,
                                                  (__bridge void*)self);

        IOHIDManagerRegisterInputValueCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                               HIDcallback,
                                               (__bridge void*)self);

        // Start our HID manager:
        IOHIDManagerScheduleWithRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager,
                                        CFRunLoopGetCurrent(),
                                        kCFRunLoopDefaultMode);
    }
    return self;
}

- (void)doGC {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        // Something is wrong and the manager doesn't exist, so just bail:
        return;
    }

    // Remove our callbacks:
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);

    // Remove our HID manager from the runloop:
    IOHIDManagerUnscheduleFromRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // Deallocate the HID manager:
    self.ioHIDManager = nil;

    // Destroy any event taps:
    for (HSRazerDevice *razerDevice in self.devices) {
        [razerDevice destroyEventTap];
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

- (HSRazerDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    /*
    Handy Resources:

        - HID Device Property Keys
          https://developer.apple.com/documentation/iokit/iohidkeys_h_user-space/hid_device_property_keys
    */

    NSNumber *vendorID              = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID             = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    NSNumber *locationID            = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDLocationIDKey));

    // Make sure the vendor is Razer:
    if (vendorID.intValue != USB_VID_RAZER) {
        //NSLog(@"[hs.razer] deviceDidConnect from unknown vendor: %d", vendorID.intValue);
        return nil;
    }

    HSRazerDevice *razerDevice = nil;
    BOOL alreadyRegistered = NO;

    // Make sure the product ID matches:
    switch (productID.intValue) {
        case USB_PID_RAZER_TARTARUS_V2:
            // We only want to register each device once, as they might have multiple
            // HID objects for the same physical hardware:
            alreadyRegistered = NO;
            for (HSRazerDevice *checkDevice in self.devices) {
                if (checkDevice.locationID == locationID) {
                    alreadyRegistered = YES;
                }
            }

            if (!alreadyRegistered) {
                //NSLog(@"[hs.razer] Razer Tartarus V2 detected.");
                razerDevice = [[HSRazerTartarusV2Device alloc] initWithDevice:device manager:self];

                // Save the location ID for making sure we're communicating with the right hardware
                // when changing LED backlights:
                razerDevice.locationID = locationID;

                // Setup Event Tap:
                [razerDevice setupEventTap];
                break;
            }
        default:
            //NSLog(@"[hs.razer] deviceDidConnect from unknown device: %d", productID.intValue);
            break;
    }
    if (!razerDevice) {
        //NSLog(@"[hs.razer] deviceDidConnect: no HSRazerDevice was created, ignoring");
        return nil;
    }

    [self.devices addObject:razerDevice];

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    razerDevice.lsCanary = [skin createGCCanary];

    _lua_stackguard_entry(skin.L);
    if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
        [skin logWarn:@"hs.razer detected a device connecting, but no discovery callback has been set. See hs.razer.discoveryCallback()"];
    } else {
        [skin pushLuaRef:razerRefTable ref:self.discoveryCallbackRef];
        lua_pushboolean(skin.L, 1);
        [skin pushNSObject:razerDevice];
        [skin protectedCallAndError:@"hs.razer:deviceDidConnect" nargs:2 nresults:0];
    }

    //NSLog(@"Created Razer device: %p", (__bridge void*)deviceId);
    //NSLog(@"[hs.razer] Now have %lu devices", self.devices.count);
    _lua_stackguard_exit(skin.L);
    return razerDevice;
}

- (void)deviceDidDisconnect:(IOHIDDeviceRef)device {
    for (HSRazerDevice *razerDevice in self.devices) {
        if (razerDevice.device == device) {
            [razerDevice invalidate];
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
                [skin logWarn:@"hs.razer detected a device disconnecting, but no callback has been set. See hs.razer.discoveryCallback()"];
            } else {
                [skin pushLuaRef:razerRefTable ref:self.discoveryCallbackRef];
                lua_pushboolean(skin.L, 0);
                [skin pushNSObject:razerDevice];
                [skin protectedCallAndError:@"hs.razer:deviceDidDisconnect" nargs:2 nresults:0];
            }

            [self.devices removeObject:razerDevice];
            _lua_stackguard_exit(skin.L);
            return;
        }
    }
    //NSLog(@"[hs.razer] ERROR: A Razer was disconnected that we didn't know about");
    return;
}

@end
