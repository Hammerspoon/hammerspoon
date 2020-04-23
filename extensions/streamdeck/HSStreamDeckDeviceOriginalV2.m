//
//  HSStreamDeckDeviceXL.m
//  streamdeck
//
//  Created by Chris Jones on 08/01/2020.
//  Copyright © 2020 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDeviceOriginalV2.h"

@implementation HSStreamDeckDeviceOriginalV2

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck (V2)";
        self.keyRows = 3;
        self.keyColumns = 5;
        self.imageWidth = 72;
        self.imageHeight = 72;
        self.imageCodec = STREAMDECK_CODEC_JPEG;
        self.imageFlipX = YES;
        self.imageFlipY = YES;
        self.imageAngle = 0;
        self.simpleReportLength = 32;
        self.reportLength = 1024;
        self.reportHeaderLength = 8;
        self.dataKeyOffset = 4;
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
        NSLog(@"hs.streamdeck:reset() failed on %@ (%@)", self.deckType, self.serialNumber);
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

- (NSString *)cacheSerialNumber {
    if (!self.isValid) {
        return nil;
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
    uint8_t reportHeader[] = {0x02,   // Report ID
                             0x07,   // Unknown (always seems to be 7)
                             button - 1, // Deck button to set
                             0x00,   // Final page bool
                             0x00,   // Some kind of encoding of the length of the current page
                             0x00,   // Some other kind of encoding of the current page length
                             0x00,   // Some kind of encoding of the page number
                             0x00    // Some other kind of encoding of the page number
                            };

    // The Mini Stream Deck needs images sent in slices no more than 1016 bytes + the report header
    int maxPayloadLength = self.reportLength - self.reportHeaderLength;

    int bytesRemaining = (int)data.length;
    int bytesSent = 0;
    int pageNumber = 0;
    const uint8_t *imageBuf = data.bytes;

    IOReturn result;

    while (bytesRemaining > 0) {
        int thisPageLength = MIN(bytesRemaining, maxPayloadLength);
        bytesSent = pageNumber * maxPayloadLength;

        // Set our current page number
        reportHeader[6] = pageNumber & 0xFF;
        reportHeader[7] = pageNumber >> 8;

        // Set our current page length
        reportHeader[4] = thisPageLength & 0xFF;
        reportHeader[5] = thisPageLength >> 8;

        // Set if we're the last page of data
        if (bytesRemaining <= maxPayloadLength) reportHeader[3] = 1;

        NSMutableData *report = [NSMutableData dataWithLength:self.reportLength];
        [report replaceBytesInRange:NSMakeRange(0, self.reportHeaderLength)
                          withBytes:reportHeader];
        [report replaceBytesInRange:NSMakeRange(self.reportHeaderLength, thisPageLength)
                          withBytes:imageBuf+bytesSent
                             length:thisPageLength];

        result = IOHIDDeviceSetReport(self.device,
                                      kIOHIDReportTypeOutput,
                                      reportHeader[0],
                                      report.bytes,
                                      (int)report.length);
        if (result != kIOReturnSuccess) {
            NSLog(@"WARNING: writing an image with hs.streamdeck encountered a failure on page %d: %d", pageNumber, result);
        }

        bytesRemaining = bytesRemaining - thisPageLength;
        pageNumber++;
    }
}

@end
