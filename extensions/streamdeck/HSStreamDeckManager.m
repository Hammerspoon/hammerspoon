//
//  HSStreamDeckManager.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckManager.h"

#pragma mark - IOKit C callbacks
static void HIDevent(void *deviceRef, IOReturn result, void *sender, IOHIDValueRef value) {
    //NSLog(@"HIDevent: deviceRef:%p sender:%p", deviceRef, sender);
    HSStreamDeckDevice *device = (__bridge HSStreamDeckDevice*)deviceRef;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    int button = IOHIDElementGetCookie(element) - 84;
    BOOL isDown = IOHIDValueGetIntegerValue(value) == 1 ? YES : NO;
    //NSLog(@"HIDevent: button pressed: %d, isDown: %@", button, isDown ? @"YES" : @"NO");

    [device deviceDidSendInput:[NSNumber numberWithInt:button] isDown:[NSNumber numberWithBool:isDown]];
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    //NSLog(@"connect: %p:%p", context, (void *)device);
    HSStreamDeckManager *manager = (__bridge HSStreamDeckManager *)context;
    HSStreamDeckDevice *deviceId = [manager deviceDidConnect:device];
    IOHIDDeviceRegisterInputValueCallback(device, HIDevent, (void*)deviceId);
    //NSLog(@"Added value callback to new IOKit device %p for Deck Device %p", (void *)device, (__bridge void*)deviceId);
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

        // Create a HID device manager
        self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
        //NSLog(@"Created HID Manager: %p", (void *)self.ioHIDManager);

        // Configure the HID manager to match against Stream Deck devices
        NSString *vendorIDKey = @(kIOHIDVendorIDKey);
        NSString *productIDKey = @(kIOHIDProductIDKey);
        NSDictionary *match = @{
                                vendorIDKey: @0x0fd9,
                                productIDKey: @0x0060,
                                };
        IOHIDManagerSetDeviceMatching ((__bridge IOHIDManagerRef)self.ioHIDManager, (__bridge CFDictionaryRef)match);

        // Add our callbacks for relevant events
        IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, HIDconnect, (__bridge void*)self);
        IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, HIDdisconnect, (__bridge void*)self);

        // Start our HID manager
        IOHIDManagerScheduleWithRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
    return self;
}

- (void)doGC {
    // Remove our callbacks
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);

    // Remove our HID manager from the runloop
    IOHIDManagerUnscheduleFromRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // Deallocate the HID manager
    self.ioHIDManager = nil;
}

- (BOOL)startHIDManager {
    IOReturn tIOReturn = IOHIDManagerOpen((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (BOOL)stopHIDManager {
    IOReturn tIOReturn = IOHIDManagerClose((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (HSStreamDeckDevice*)deviceDidConnect:(IOHIDDeviceRef)device {
    HSStreamDeckDevice *deviceId = [[HSStreamDeckDevice alloc] initWithDevice:device manager:self];
    [self.devices addObject:deviceId];

    LuaSkin *skin = [LuaSkin shared];
    _lua_stackguard_entry(skin.L);
    if (self.discoveryCallbackRef == LUA_NOREF || self.discoveryCallbackRef == LUA_REFNIL) {
        [skin logWarn:@"hs.streamdeck detected a device connecting, but no callback has been set. See hs.streamdeck.discoveryCallback()"];
    } else {
        [skin pushLuaRef:streamDeckRefTable ref:self.discoveryCallbackRef];
        lua_pushboolean(skin.L, 1);
        [skin pushNSObject:deviceId];
        [skin protectedCallAndError:@"hs.streamdeck:deviceDidConnect" nargs:2 nresults:0];
    }

    //NSLog(@"Created deck device: %p", (__bridge void*)deviceId);
    //NSLog(@"Now have %lu devices", self.devices.count);
    _lua_stackguard_exit(skin.L);
    return deviceId;
}

- (void)deviceDidDisconnect:(IOHIDDeviceRef)device {
    for (HSStreamDeckDevice *deckDevice in self.devices) {
        if (deckDevice.device == device) {
            [deckDevice invalidate];
            LuaSkin *skin = [LuaSkin shared];
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
