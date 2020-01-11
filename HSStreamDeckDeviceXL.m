//
//  HSStreamDeckDeviceXL.m
//  streamdeck
//
//  Created by Chris Jones on 08/01/2020.
//  Copyright © 2020 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDeviceXL.h"

@implementation HSStreamDeckDeviceXL

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck (XL)";
        self.keyRows = 4;
        self.keyColumns = 8;
        self.imageWidth = 96;
        self.imageHeight = 96;
        self.imageCodec = STREAMDECK_CODEC_JPEG;
        self.imageFlipX = YES;
        self.imageFlipY = YES;
        self.imageAngle = 0;
        self.simpleReportLength = 32;
        self.reportLength = 1024;
        self.reportHeaderLength = 8;
    }
    return self;
}

- (void)reset {
    if (!self.isValid) {
        return;
    }

    uint8_t resetHeader[] = {0x03, 0x02};
    IOReturn res = [self deviceWriteSimpleReport:resetHeader reportLen:2];
    if (res != kIOReturnSuccess) {
        NSLog(@"hs.streamdeck:reset() failed on %@ (%@)", self.deckType, [self serialNumber]);
    }
}

- (BOOL)setBrightness:(int)brightness {
    if (!self.isValid) {
        return NO;
    }

    uint8_t brightnessHeader[] = {0x03, 0x08, brightness};
    IOReturn res = [self deviceWriteSimpleReport:brightnessHeader reportLen:3];

    return res == kIOReturnSuccess;
}

- (NSString*)serialNumber {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }

    return [[NSString alloc] initWithData:[self deviceRead:32 reportID:0x06]
                                 encoding:NSUTF8StringEncoding];
}

- (NSString*)firmwareVersion {
    if (!self.isValid) {
        return @"INVALID DEVICE";
    }

    return [[NSString alloc] initWithData:[self deviceRead:32 reportID:0x05]
                                 encoding:NSUTF8StringEncoding];
}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    uint8_t reportMagic[] = {0x02,   // Report ID
                             0x07,   // Unknown (always seems to be 7)
                             button, // Deck button to set
                             0x00,   // Final page bool
                             0x00,   // Some kind of encoding of the length of the current page
                             0x00,   // Some other kind of encoding of the current page length
                             0x00,   // Some kind of encoding of the page number
                             0x00    // Some other kind of encoding of the page number
                            };

    // The Mini Stream Deck needs images sent in slices no more than 1008 bytes
    int payloadLength = self.reportLength - self.reportHeaderLength;
    int imageLen = (int)data.length;
    int bytesRemaining = imageLen;
    int pageNumber = 0;
    const uint8_t *imageBuf = data.bytes;
    IOReturn result;

    while (bytesRemaining > 0) {
        int reportLength = MIN(bytesRemaining, payloadLength);
        int bytesSent = pageNumber * payloadLength;

        // Set our current page number
        reportMagic[6] = pageNumber & 0xFF;
        reportMagic[7] = pageNumber >> 8;

        // Set our current page length
        reportMagic[4] = reportLength & 0xFF;
        reportMagic[5] = reportLength >> 8;

        // Set if we're the last page of data
        if (bytesRemaining <= payloadLength) reportMagic[3] = 1;

        NSMutableData *report = [NSMutableData dataWithLength:self.reportLength];
        [report replaceBytesInRange:NSMakeRange(0, self.reportHeaderLength) withBytes:reportMagic];
        [report replaceBytesInRange:NSMakeRange(self.reportHeaderLength, reportLength) withBytes:imageBuf+bytesSent length:reportLength];

        result = IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, reportMagic[0], report.bytes, (int)report.length);
        if (result != kIOReturnSuccess) {
            NSLog(@"WARNING: writing an image with hs.streamdeck encountered a failure on page %d: %d", pageNumber, result);
        }
        bytesRemaining = bytesRemaining - (int)report.length;
        pageNumber++;
    }
}

@end
