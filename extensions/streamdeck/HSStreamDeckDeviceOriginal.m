//
//  HSStreamDeckDeviceOriginal.m
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDeviceOriginal.h"

@implementation HSStreamDeckDeviceOriginal

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck (Original v1)";
        self.keyRows = 3;
        self.keyColumns = 5;
        self.imageWidth = 72;
        self.imageHeight = 72;
        self.imageCodec = STREAMDECK_CODEC_BMP;
        self.imageFlipX = YES;
        self.imageFlipY = YES;
        self.imageAngle = 0;
        self.simpleReportLength = 17;
        self.reportLength = 8192;
        self.reportHeaderLength = 16;
        self.dataKeyOffset = 1;
    }
    return self;
}

- (int)transformKeyIndex:(int)sourceKey {
    int midpoint;
    int diff;

    if (sourceKey >=1 && sourceKey <= 5) {
        midpoint = 3;
    } else if (sourceKey >= 6 && sourceKey <= 10) {
        midpoint = 8;
    } else if (sourceKey >= 11 && sourceKey <= 15) {
        midpoint = 13;
    } else {
        midpoint = 3; // This will cause incorrect rendering, but it shouldn't happen
    }

    diff = midpoint - sourceKey;

    //NSLog(@"transformKeyIndex: source %d, midpoint %d, diff %d, trans %d", sourceKey, midpoint, diff, midpoint + diff);
    return midpoint + diff;
}

- (void)reset {
    if (!self.isValid) {
        return;
    }

    uint8_t resetHeader[] = {0x0B, 0x63};
    [self deviceWriteSimpleReport:resetHeader reportLen:2];
}

- (BOOL)setBrightness:(int)brightness {
    if (!self.isValid) {
        return NO;
    }

    uint8_t brightnessHeader[] = {0x05, 0x55, 0xAA, 0xD1, 0x01, brightness};
    IOReturn res = [self deviceWriteSimpleReport:brightnessHeader reportLen:6];

    return res == kIOReturnSuccess;
}

- (NSString *)cacheSerialNumber {
    if (!self.isValid) {
        return nil;
    }

    return [[NSString alloc] initWithData:[self deviceRead:12 reportID:0x3]
                                                   encoding:NSUTF8StringEncoding];
}

- (NSString*)firmwareVersion {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }

    return [[NSString alloc] initWithData:[self deviceRead:12 reportID:0x4]
                                 encoding:NSUTF8StringEncoding];
}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    uint8_t reportMagic[] = {0x02,  // Report ID
                             0x01,  // Unknown (always seems to be 1)
                             0x01,  // Page Number
                             0x00,  // Padding
                             0x00,  // Continuation Bool
                             button, // Deck button to set
                             0,
                             0,
                             0,
                             0,
                             0,
                             0,
                             0,
                             0,
                             0,
                             0,
                            };

    // The original Stream Deck needs images sent in two halves of seemingly arbitrary length
    int imageLen = (int)data.length;
    int halfImageLen = imageLen / 2;
    const uint8_t *imageBuf = data.bytes;

    // Prepare and send the first half of the image
    NSMutableData *reportPage1 = [NSMutableData dataWithLength:self.reportLength];
    [reportPage1 replaceBytesInRange:NSMakeRange(0, self.reportHeaderLength) withBytes:reportMagic];
    [reportPage1 replaceBytesInRange:NSMakeRange(self.reportHeaderLength, halfImageLen) withBytes:imageBuf];
    //const uint8_t *rawPage1 = (const uint8_t *)reportPage1.bytes;

    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, reportMagic[0], reportPage1.bytes, (int)reportPage1.length);

    // Prepare and send the second half of the image
    NSMutableData *reportPage2 = [NSMutableData dataWithLength:self.reportLength];
    reportMagic[2] = 2;
    reportMagic[4] = 1;
    [reportPage2 replaceBytesInRange:NSMakeRange(0, self.reportHeaderLength) withBytes:reportMagic];
    [reportPage2 replaceBytesInRange:NSMakeRange(self.reportHeaderLength, halfImageLen) withBytes:imageBuf+halfImageLen];
    //const uint8_t *rawPage2 = (const uint8_t *)reportPage2.bytes;

    IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, reportMagic[0], reportPage2.bytes, (int)reportPage2.length);
}
@end
