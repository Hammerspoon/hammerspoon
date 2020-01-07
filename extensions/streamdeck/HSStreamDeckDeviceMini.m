//
//  HSStreamDeckDeviceMini.m
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//
// Stream Deck Mini support was made possible by examining https://github.com/abcminiuser/python-elgato-streamdeck/tree/master/src/StreamDeck/Devices

#import "HSStreamDeckDeviceMini.h"

@implementation HSStreamDeckDeviceMini

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck (Mini)";
        self.keyRows = 3;
        self.keyColumns = 2;
        self.keyCount = self.keyRows * self.keyColumns;
        self.imageWidth = 80;
        self.imageHeight = 80;
        self.imageCodec = BMP;
        self.imageFlipX = NO;
        self.imageFlipY = YES;
        self.imageAngle = 90;
        self.reportLength = 1024;
        self.reportHeaderLength = 16;
    }
    return self;
}

- (void)reset {
    if (!self.isValid) {
        return;
    }

    uint8_t resetHeader[] = {0x0B, 0x63};
    NSData *reportData = [NSData dataWithBytes:resetHeader length:2];
    IOReturn result = [self deviceWrite:reportData];
    if (result != kIOReturnSuccess) {
        NSLog(@"hs.streamdeck:reset() failed on %@ (%@)", self.deckType, [self serialNumber]);
    }
}

- (BOOL)setBrightness:(int)brightness {
    if (!self.isValid) {
        return NO;
    }

    uint8_t brightnessHeader[] = {0x05, 0x55, 0xAA, 0xD1, 0x01, brightness};
    int brightnessLength = 17;

    NSMutableData *reportData = [NSMutableData dataWithLength:brightnessLength];
    [reportData replaceBytesInRange:NSMakeRange(0, 6) withBytes:brightnessHeader];
    IOReturn res = [self deviceWrite:reportData];

    return res == kIOReturnSuccess;
}

- (NSString*)serialNumber {
    if (!self.isValid) {
        return @"INVALID DEVICE";
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
                             0x00,  // Page Number
                             0x00,  // Padding
                             0x00,  // Continuation Bool
                             button // Deck button to set
                            };

    // The Mini Stream Deck needs images sent in slices no more than 1008 bytes
    int payloadLength = self.reportLength - 16;
    int imageLen = (int)data.length;
    int bytesRemaining = imageLen;
    int pageNumber = reportMagic[2];
    const uint8_t *imageBuf = data.bytes;
    IOReturn result;

    while (bytesRemaining > 0) {
        int reportLength = MIN(bytesRemaining, payloadLength);
        int bytesSent = pageNumber * payloadLength;

        // Set our current page number and thus whether we're a continuation page or not
        reportMagic[2] = pageNumber;
        if (pageNumber > 0) reportMagic[4] = 1;

        NSMutableData *report = [NSMutableData dataWithLength:self.reportLength];
        [report replaceBytesInRange:NSMakeRange(0, 6) withBytes:reportMagic];
        [report replaceBytesInRange:NSMakeRange(16, reportLength) withBytes:imageBuf+bytesSent length:reportLength];

        result = IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, reportMagic[0], report.bytes, (int)report.length);
        if (result != kIOReturnSuccess) {
            NSLog(@"WARNING: writing an image with hs.streamdeck encountered a failure on page %d: %d", pageNumber, result);
        }
        bytesRemaining = bytesRemaining - (int)report.length;
        pageNumber++;
    }
}
@end
