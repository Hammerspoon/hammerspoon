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

        // These defaults are not necessary, all base classes will override them, but if we miss something, these are chosen to try and provoke a crash where possible, so we notice the lack of an override.
        self.imageCodec = STREAMDECK_CODEC_UNKNOWN;
        self.deckType = @"Unknown";
        self.keyColumns = -1;
        self.keyRows = -1;
        self.imageFlipX = NO;
        self.imageFlipY = NO;
        self.imageAngle = 0;
        self.simpleReportLength = 0;
        self.reportLength = 0;
        self.reportHeaderLength = 0;
        //NSLog(@"Added new Stream Deck device %p with IOKit device %p from manager %p", (__bridge void *)self, (void*)self.device, (__bridge void *)self.manager);
    }
    return self;
}

- (void)invalidate {
    self.isValid = NO;
}

- (IOReturn)deviceWriteSimpleReport:(uint8_t[])report reportLen:(int)reportLen {
    if (self.simpleReportLength == 0) {
        LuaSkin *skin = [LuaSkin shared];
        [skin logError:@"Initialising Stream Deck device with no simple report length defined"];
        return kIOReturnInternalError;
    }
    NSMutableData *reportData = [NSMutableData dataWithLength:self.simpleReportLength];
    [reportData replaceBytesInRange:NSMakeRange(0, reportLen) withBytes:report];
    return [self deviceWrite:reportData];
}

- (IOReturn)deviceWrite:(NSData *)report {
    const uint8_t *rawBytes = (const uint8_t*)report.bytes;
    return IOHIDDeviceSetReport(self.device, kIOHIDReportTypeFeature, rawBytes[0], rawBytes, report.length);
}

- (NSData *)deviceRead:(int)resultLength reportID:(CFIndex)reportID {
    CFIndex reportLength = resultLength + 5;
    uint8_t *report = malloc(reportLength);

    //NSLog(@"deviceRead: expecting resultLength %d, calculated report length %ld", resultLength, (long)reportLength);

    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, reportID, report, &reportLength);
    char *c_data = (char *)(report + 5);
    NSData *data = [NSData dataWithBytes:c_data length:resultLength];

    return data;
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
    NSException *exception = [NSException exceptionWithName:@"HSStreamDeckDeviceUnimplemented"
                                                     reason:@"setBrightness method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return NO;
}

- (void)reset {
    NSException *exception = [NSException exceptionWithName:@"HSStreamDeckDeviceUnimplemented"
                                                     reason:@"reset method not implemented"
                                                   userInfo:nil];
    [exception raise];
}

- (NSString*)serialNumber {
    NSException *exception = [NSException exceptionWithName:@"HSStreamDeckDeviceUnimplemented"
                                                     reason:@"serialNumber method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return nil;
}

- (NSString*)firmwareVersion {
    NSException *exception = [NSException exceptionWithName:@"HSStreamDeckDeviceUnimplemented"
                                                     reason:@"firmwareVersion method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return nil;
}

- (int)getKeyCount {
    return self.keyColumns * self.keyRows;
}

- (void)clearImage:(int)button {
    [self setColor:[NSColor blackColor] forButton:button];
}

- (void)setColor:(NSColor *)color forButton:(int)button {
    if (!self.isValid) {
        return;
    }

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(self.imageWidth, self.imageHeight)];
    [image lockFocus];
    [color drawSwatchInRect:NSMakeRect(0, 0, self.imageWidth, self.imageHeight)];
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
    NSSize newSize = NSMakeSize(self.imageWidth, self.imageHeight);
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

    // Both of these functions are no-ops if there are no rotations or flips required, so we'll call them unconditionally
    renderImage = [renderImage imageRotated:self.imageAngle];
    renderImage = [renderImage flipImage:self.imageFlipX vert:self.imageFlipY];

    NSData *data = nil;

    switch (self.imageCodec) {
        case STREAMDECK_CODEC_BMP:
            data = [renderImage bmpData];
            break;

        case STREAMDECK_CODEC_JPEG:
            //data = [renderImage jpegData];
            break;

        case STREAMDECK_CODEC_UNKNOWN:
            [[LuaSkin shared] logError:@"Unknown image codec for hs.streamdeck device"];
            break;
    }

    // Writing the image to hardware is a device-specific operation, so hand it off to our subclasses
    [self deviceWriteImage:data button:button];

}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    NSException *exception = [NSException exceptionWithName:@"HSStreamDeckDeviceUnimplemented"
                                                     reason:@"deviceWriteImage method not implemented"
                                                   userInfo:nil];
    [exception raise];
}
@end
