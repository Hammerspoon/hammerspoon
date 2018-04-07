//
//  HSStreamDeckDevice.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDevice.h"

@implementation HSStreamDeckDevice
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super init];
    if (self) {
        self.device = device;
        self.isValid = YES;
        self.manager = manager;
        self.buttonCallbackRef = LUA_NOREF;
        self.selfRefCount = 0;
        //NSLog(@"Added new Stream Deck device %p with IOKit device %p from manager %p", (__bridge void *)self, (void*)self.device, (__bridge void *)self.manager);
    }
    return self;
}

- (void)invalidate {
    self.isValid = NO;
}

- (void)deviceDidSendInput:(NSNumber*)button isDown:(NSNumber*)isDown {
    //NSLog(@"Got an input event from device: %p: button:%@ isDown:%@", (__bridge void*)self, button, isDown);

    if (!self.isValid) {
        return;
    }

    LuaSkin *skin = [LuaSkin shared];
    _lua_stackguard_entry(skin.L);
    if (self.buttonCallbackRef == LUA_NOREF || self.buttonCallbackRef == LUA_REFNIL) {
        [skin logError:@"hs.streamdeck received a button input, but no callback has been set. See hs.streamdeck:buttonCallback()"];
        return;
    }

    [skin pushLuaRef:streamDeckRefTable ref:self.buttonCallbackRef];
    [skin pushNSObject:self];
    lua_pushinteger(skin.L, button.intValue);
    lua_pushboolean(skin.L, isDown.boolValue);
    [skin protectedCallAndError:@"hs.streamdeck:buttonCallback" nargs:3 nresults:0];
    _lua_stackguard_exit(skin.L);
}

- (BOOL)setBrightness:(int)brightness {
    if (!self.isValid) {
        return NO;
    }

    uint8_t brightnessHeader[] = {0x05, 0x55, 0xAA, 0xD1, 0x01, brightness};
    int brightnessLength = 17;

    NSMutableData *reportData = [NSMutableData dataWithLength:brightnessLength];
    [reportData replaceBytesInRange:NSMakeRange(0, 6) withBytes:brightnessHeader];

    const uint8_t *rawBytes = (const uint8_t *)reportData.bytes;

    IOReturn res = IOHIDDeviceSetReport(self.device,
                                        kIOHIDReportTypeFeature,
                                        rawBytes[0], /* Report ID*/
                                        rawBytes, reportData.length);

    return res == kIOReturnSuccess;
}

- (void)reset {
    if (!self.isValid) {
        return;
    }

    uint8_t resetHeader[] = {0x0B, 0x63};
    NSData *reportData = [NSData dataWithBytes:resetHeader length:2];
    const uint8_t *rawBytes = (const uint8_t*)reportData.bytes;
    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeFeature, rawBytes[0], rawBytes, reportData.length);
}

- (NSString*)serialNumber {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }

    uint8_t serial[17];
    CFIndex serialLen = sizeof(serial);
    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, 0x3, serial, &serialLen);
    char *serialNum = (char *)&serial + 5;
    NSData *serialData = [NSData dataWithBytes:serialNum length:12];
    return [[NSString alloc] initWithData:serialData encoding:NSUTF8StringEncoding];
}

- (NSString*)firmwareVersion {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }

    uint8_t fwver[17];
    CFIndex fwverLen = sizeof(fwver);
    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, 0x4, fwver, &fwverLen);
    char *fwverNum = (char *)&fwver + 5;
    NSData *fwVerData = [NSData dataWithBytes:fwverNum length:12];
    return [[NSString alloc] initWithData:fwVerData encoding:NSUTF8StringEncoding];
}

- (void)setColor:(NSColor *)color forButton:(int)button {
    if (!self.isValid) {
        return;
    }

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(buttonImageSideLength, buttonImageSideLength)];
    [image lockFocus];
    [color drawSwatchInRect:NSMakeRect(0, 0, buttonImageSideLength, buttonImageSideLength)];
    [image unlockFocus];
    [self setImage:image forButton:button];
}

- (void)setImage:(NSImage *)image forButton:(int)button {
    if (!self.isValid) {
        return;
    }

    NSImage *renderImage;

    // Unconditionally resize the image
    NSImage *sourceImage = [image copy];
     NSSize newSize = NSMakeSize(buttonImageSideLength, buttonImageSideLength);
    renderImage = [[NSImage alloc] initWithSize: newSize];
    [renderImage lockFocus];
    [sourceImage setSize: newSize];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositeCopy fraction:1.0];
    [renderImage unlockFocus];

    if (![image isValid]) {
        [[LuaSkin shared] logError:@"image is invalid"];
    }
    if (![renderImage isValid]) {
        [[LuaSkin shared] logError:@"Invalid image passed to hs.streamdeck:setImage() (renderImage)"];
    //    return;
    }

    NSData *data = [renderImage bmpData];

    int reportLength = 8191;
    uint8_t reportMagic[] = {0x02,  // Report ID
                             0x01,  // Unknown (always seems to be 1)
                             0x01,  // Image Page
                             0x00,  // Padding
                             0x00,  // Continuation Bool
                             button // Deck button to set
                            };

    int imageLen = (int)data.length;
    int halfImageLen = imageLen / 2;
    const uint8_t *imageBuf = data.bytes;

    // Prepare and send the first half of the image
    NSMutableData *reportPage1 = [NSMutableData dataWithLength:reportLength];
    [reportPage1 replaceBytesInRange:NSMakeRange(0, 6) withBytes:reportMagic];
    [reportPage1 replaceBytesInRange:NSMakeRange(16, halfImageLen) withBytes:imageBuf];
    const uint8_t *rawPage1 = (const uint8_t *)reportPage1.bytes;

    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, rawPage1[0], rawPage1, reportLength);

    // Prepare and send the second half of the image
    NSMutableData *reportPage2 = [NSMutableData dataWithLength:reportLength];
    reportMagic[2] = 2;
    reportMagic[4] = 1;
    [reportPage2 replaceBytesInRange:NSMakeRange(0, 6) withBytes:reportMagic];
    [reportPage2 replaceBytesInRange:NSMakeRange(16, halfImageLen) withBytes:imageBuf+halfImageLen];
    const uint8_t *rawPage2 = (const uint8_t *)reportPage2.bytes;

    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, rawPage2[0], rawPage2, reportLength);

}
@end
