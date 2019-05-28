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
        self.isMini = false;
        
        NSNumber * productID = (__bridge id)(IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)));
        if ( productID && [productID intValue] == 0x0063) {
            self.isMini = true;
        }
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

- (int)targetSize {
    if(self.isMini) {
        return 80;
    }
    return 72;
}

- (int)rotateAngle {
    if(self.isMini) {
        return 270;
    }
    return 180;

}

- (int)packetSize {
    if(self.isMini) {
        return 1024;
    }
    return 8191;
}

- (int)buttonOffset {
    if(self.isMini) {
        return 145;
    }
    return 84;
}

- (int)reportFirstIndex {
    if(self.isMini) {
        return 0;
    }
    return 1;
}

- (int)scaleX {
    if(self.isMini) {
        return -1;
    }
    return 1;
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

    int targetSize = [self targetSize];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(targetSize, targetSize)];
    [image lockFocus];
    [color drawSwatchInRect:NSMakeRect(0, 0, targetSize, targetSize)];
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
    NSSize newSize = NSMakeSize([self targetSize], [self targetSize]);
    
    renderImage = [[NSImage alloc] initWithSize: newSize];
    [renderImage lockFocus];
    [sourceImage setSize: newSize];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositingOperationCopy fraction:1.0];
    [renderImage unlockFocus];

    if (![image isValid]) {
        [[LuaSkin shared] logError:@"image is invalid"];
    }
    if (![renderImage isValid]) {
        [[LuaSkin shared] logError:@"Invalid image passed to hs.streamdeck:setImage() (renderImage)"];
    //    return;
    }

    NSData *data = [renderImage bmpDataWithRotation:[self rotateAngle] andScaleXBy:[self scaleX]];

    int reportLength = [self packetSize];
    int sendableAmount = reportLength - 16;

    // the reportMagic is 16 bytes long, but we only use 6
    uint8_t reportMagic[] = {0x02,  // Report ID
                             0x01,  // Unknown (always seems to be 1)
                             0x00,  // Image Page
                             0x00,  // Padding
                             0x01,  // Continuation Bool
                             button // Deck button to set
                            };

    const uint8_t *imageBuf = data.bytes;
    int imageLen = (int)data.length;

    int imagePosition = 0;
    int reportIndex = [self reportFirstIndex];
    while(imagePosition < imageLen) {
        // Update page index
        reportMagic[2] = reportIndex;
        // Is this the last page?
        if (imagePosition + sendableAmount >= imageLen) {
            reportMagic[4] = 0;
        }

        NSMutableData *reportPage = [NSMutableData dataWithLength:reportLength];
        [reportPage replaceBytesInRange:NSMakeRange(0, 6) withBytes:reportMagic];
        
        if ((imagePosition + sendableAmount) > imageLen) {
            sendableAmount = imageLen - imagePosition;
        }
        
        [reportPage replaceBytesInRange:NSMakeRange(16, sendableAmount) withBytes:imageBuf+imagePosition];
        
        const uint8_t *rawPage = (const uint8_t *)reportPage.bytes;
        IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, rawPage[0], rawPage, reportLength);
        reportIndex++;
        imagePosition = imagePosition + sendableAmount;
    }
}
@end
