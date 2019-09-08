//
//  HSStreamDeckDevice.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDevice.h"

@implementation HSStreamDeckDevice
# pragma mark

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super init];
    if (self) {
        self.device = device;
        self.isValid = YES;
        self.manager = manager;
        self.buttonCallbackRef = LUA_NOREF;
        self.selfRefCount = 0;
        
        NSNumber * productID = (__bridge id)(IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)));
        self.productID = [productID intValue];
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

# pragma mark Basic Properties

- (NSString*)modelName {
    NSString *modelName = @"";
    switch ([self productID]) {
        case  0x0063: modelName=[modelName stringByAppendingString:@"Mini"];break;
        case 0x006c: modelName=[modelName stringByAppendingString:@"XL"]; break;
        default: modelName=[modelName stringByAppendingString:@"Original"]; break;
    }
    return modelName;
}

#pragma mark - Key management

// Number of bytes skipped at beginning of report
- (int)dataKeyOffset {
    switch (self.productID) {
        case 0x0060: return 1;
        case 0x0063: return 1;
        case 0x006c: return 4;
            
        default: return 1;
    }
}

- (int)transformKeyIndex:(int)sourceKey {
    int half;
    int diff;
    
    switch (self.productID) {
        case 0x0060:
            // horizontal flip
            half = ([self keyColumns] - 1) / 2;
            diff = ((sourceKey % [self keyColumns]) - half) * -half;
            return sourceKey + diff;
        case 0x0063:
        case 0x006c:
        default: return sourceKey;
    }
}

# pragma mark Button count, Columns and Rows

-(int)keyColumns {
    switch (self.productID) {
        case 0x0060: return 5;
        case 0x0063: return 3;
        case 0x006c: return 8;
            
        default: return 5;
    }
}

-(int)keyRows {
    switch (self.productID) {
        case 0x0060: return 3;
        case 0x0063: return 2;
        case 0x006c: return 4;
            
        default: return 3;
    }
}

- (int)numKeys {
    return [self keyRows] * [self keyColumns];
}

# pragma mark

- (int)reportFirstIndex {
    return 0;
}

# pragma mark Image manipulation

- (int)packetSize {
    switch (self.productID) {
        case 0x0060: return 8191;
        case 0x0063: return 1024;
        case 0x006c: return 1024;
            
        default: return 8191;
    }
}

- (int)targetSize {
    switch (self.productID) {
        case 0x0060: return 72;
        case 0x0063: return 80;
        case 0x006c: return 96;
            
        default: return 72;
    }
}
- (int)rotateAngle {
    return 0;
}

- (int)scaleX {
    switch (self.productID) {
        case 0x0063: return -1;
        case 0x0060:
        case 0x006c:
        default: return 1;
    }
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
                             0x00,  // Continuation Bool
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
            reportMagic[4] = 1;
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
# pragma mark Other Commands

- (int)serialRepordtId {
        switch (self.productID) {
            case 0x0060: return 0x3;
            case 0x0063: return 0x3;
            case 0x006c: return 0x5;
                
            default: return 0x3;
        }
    }

- (int)firmwareRepordtId {
    switch (self.productID) {
        case 0x0060: return 0x4;
        case 0x0063: return 0x4;
        case 0x006c: return 0x6;
            
        default: return 0x4;
    }
}

- (NSString*)serialNumber {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }
    
    uint8_t serial[17];
    CFIndex serialLen = sizeof(serial);
    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, [self serialRepordtId], serial, &serialLen);
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
    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, [self firmwareRepordtId], fwver, &fwverLen);
    char *fwverNum = (char *)&fwver + 5;
    NSData *fwVerData = [NSData dataWithBytes:fwverNum length:12];
    return [[NSString alloc] initWithData:fwVerData encoding:NSUTF8StringEncoding];
}

- (NSMutableData*)brightnessReport:(int)brightness {
    uint8 bg = brightness>100? 100 : brightness<0? 0: brightness;
    uint8_t header[] = {0x05, 0x55, 0xaa, 0xd1, 0x01, bg};
    uint8_t xlHeader[] = {0x03, 0x08, bg, 0x00, 0x00, 0x00};
    int brightnessLength = 17;

    uint8_t *selected;
        switch (self.productID) {
            case 0x0060: case 0x0063:
                selected = header;
                break;
            case 0x006c:
                selected = xlHeader;
                break;
            default:
                selected = xlHeader;
        }
    
    NSMutableData *reportData = [NSMutableData dataWithLength:brightnessLength];
    [reportData replaceBytesInRange:NSMakeRange(0, 6) withBytes:selected];
    return reportData;
}

- (BOOL)setBrightness:(int)brightness {
    if (!self.isValid) {
        return NO;
    }
    
    NSMutableData *reportData = [self brightnessReport:brightness];
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
    
    uint8_t resetHeader[] = { 0x0B, 0x63};
    uint8_t newResetHeader[] = { 0x03, 0x02 };
    
    uint8_t *selected;
    switch (self.productID) {
        case 0x0060: case 0x0063:
            selected = resetHeader;
            break;
        case 0x006c:
            selected = newResetHeader;
            break;
        default:
            selected = resetHeader;
    }
    
    NSMutableData *reportData = [NSMutableData dataWithLength:17];
    [reportData replaceBytesInRange:NSMakeRange(0, 2) withBytes:selected];

    const uint8_t *rawBytes = (const uint8_t*)reportData.bytes;
    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeFeature, rawBytes[0], rawBytes, reportData.length);
}

@end
