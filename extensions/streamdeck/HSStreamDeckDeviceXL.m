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
        self.dataKeyOffset = 4;

        uint8_t resetHeader[] = {0x03, 0x02};
        self.resetCommand = [NSData dataWithBytes:resetHeader length:2];

        uint8_t brightnessHeader[] = {0x03, 0x08, 0xFF};
        self.setBrightnessCommand = [NSData dataWithBytes:brightnessHeader length:3];

        self.serialNumberCommand = 0x06;
        self.firmwareVersionCommand = 0x05;
    }
    return self;
}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    [self deviceV2WriteImage:data button:button];
}

@end
