//
//  HSStreamDeckManager.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckManager.h"

#pragma mark - IOKit C callbacks

static char *inputBuffer = NULL;

static void HIDReport(void* deviceRef, IOReturn result, void* sender, IOHIDReportType type, uint32_t reportID, uint8_t *report,CFIndex reportLength) {
    HSStreamDeckDevice *device = (__bridge HSStreamDeckDevice*)deviceRef;
    NSMutableArray* buttonReport = [NSMutableArray arrayWithCapacity:device.keyCount+1];

    // We need an unused button at slot zero - all our uses of these arrays are one-indexed
    [buttonReport setObject:[NSNumber numberWithInt:0] atIndexedSubscript:0];

    for(int p=1; p <= device.keyCount; p++) {
        [buttonReport setObject:@0 atIndexedSubscript:p];
    }

    uint8_t *start = report + device.dataKeyOffset;
    for(int button=1; button <= device.keyCount; button ++) {
        NSNumber* val = [NSNumber numberWithInt:start[button-1]];
        int translatedButton = [device transformKeyIndex:button];
        [buttonReport setObject:val atIndexedSubscript:translatedButton];
    }
    [device deviceDidSendInput:buttonReport];
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"connect: %p:%p", context, (void *)device);
    HSStreamDeckManager *manager = (__bridge HSStreamDeckManager *)context;
    HSStreamDeckDevice *deviceId = [manager deviceDidConnect:device];
    if (deviceId) {
        IOHIDDeviceRegisterInputReportCallback(device, (uint8_t*)inputBuffer, 1024, HIDReport, (void*)deviceId);
        //NSLog(@"Added value callback to new IOKit device %p for Deck Device %p", (void *)device, (__bridge void*)deviceId);
    }
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"disconnect: %p", (void *)device);
    HSStreamDeckManager *manager = (__bridge HSStreamDeckManager *)context;
    [manager deviceDidDisconnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, NULL, NULL);
}

#pragma mark - Stream Deck Manager implementation
@implementation HSStreamDeckManager

- (id)init {
    self = [super init];
    if (self) {
        self.devices = [[NSMutableArray alloc] initWithCapacity:5];
        self.discoveryCallbackRef = LUA_NOREF;
        inputBuffer = malloc(1024);

        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"Created HID Manager: %p", (void *)self.ioHIDManager);

        // Configure the HID manager to match against Stream Deck devices
        NSString *vendorIDKey = @(kIOHIDVendorIDKey);
        NSString *productIDKey = @(kIOHIDProductIDKey);

        NSDictionary *matchOriginal   = @{vendorIDKey:  @USB_VID_ELGATO,
                                          productIDKey: @USB_PID_STREAMDECK_ORIGINAL};
        NSDictionary *matchOriginalv2 = @{vendorIDKey:  @USB_VID_ELGATO,
                                          productIDKey: @USB_PID_STREAMDECK_ORIGINAL_V2};
        NSDictionary *matchMini       = @{vendorIDKey:  @USB_VID_ELGATO,
                                          productIDKey: @USB_PID_STREAMDECK_MINI};
        NSDictionary *matchXL         = @{vendorIDKey: @USB_VID_ELGATO,
                                          productIDKey: @USB_PID_STREAMDECK_XL};

        IOHIDManagerSetDeviceMatchingMultiple((__bridge IOHIDManagerRef)self.ioHIDManager,
                                              (__bridge CFArrayRef)@[matchOriginal,
                                                                     matchOriginalv2,
                                                                     matchMini,
                                                                     matchXL]);

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

- (HSStreamDeckDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    NSNumber *vendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));

    if (vendorID.intValue != USB_VID_ELGATO) {
        NSLog(@"deviceDidConnect from unknown vendor: %d", vendorID.intValue);
        return nil;
    }

    HSStreamDeckDevice *deck = nil;

    switch (productID.intValue) {
        case USB_PID_STREAMDECK_ORIGINAL:
            deck = [[HSStreamDeckDeviceOriginal alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_MINI:
            deck = [[HSStreamDeckDeviceMini alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_XL:
            deck = [[HSStreamDeckDeviceXL alloc] initWithDevice:device manager:self];
            break;

        case USB_PID_STREAMDECK_ORIGINAL_V2:
            deck = [[HSStreamDeckDeviceOriginalV2 alloc] initWithDevice:device manager:self];
            break;

        default:
            NSLog(@"deviceDidConnect from unknown device: %d", productID.intValue);
            break;
    }
    if (!deck) {
        NSLog(@"deviceDidConnect: no HSStreamDeckDevice was created, ignoring");
        return nil;
    }
    [deck initialiseCaches];
    [self.devices addObject:deck];

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
        [skin logWarn:@"hs.streamdeck detected a device connecting, but no discovery callback has been set. See hs.streamdeck.discoveryCallback()"];
    } else {
        [skin pushLuaRef:streamDeckRefTable ref:self.discoveryCallbackRef];
        lua_pushboolean(skin.L, 1);
        [skin pushNSObject:deck];
        [skin protectedCallAndError:@"hs.streamdeck:deviceDidConnect" nargs:2 nresults:0];
    }

    //NSLog(@"Created deck device: %p", (__bridge void*)deviceId);
    //NSLog(@"Now have %lu devices", self.devices.count);
    _lua_stackguard_exit(skin.L);
    return deck;
}

- (void)deviceDidDisconnect:(IOHIDDeviceRef)device {
    for (HSStreamDeckDevice *deckDevice in self.devices) {
        if (deckDevice.device == device) {
            [deckDevice invalidate];
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
                [skin logWarn:@"hs.streamdeck detected a device disconnecting, but no callback has been set. See hs.streamdeck.discoveryCallback()"];
            } else {
                [skin pushLuaRef:streamDeckRefTable ref:self.discoveryCallbackRef];
                lua_pushboolean(skin.L, 0);
                [skin pushNSObject:deckDevice];
                [skin protectedCallAndError:@"hs.streamdeck:deviceDidDisconnect" nargs:2 nresults:0];
            }

            [self.devices removeObject:deckDevice];
            _lua_stackguard_exit(skin.L);
            return;
        }
    }
    NSLog(@"ERROR: A Stream Deck was disconnected that we didn't know about");
    return;
}

@end
