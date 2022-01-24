//
//  HSStreamDeckDeviceMk2.m
//  streamdeck
//
//  Created by Chris Jones on 24/01/2022.
//  Copyright © 2022 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDeviceMk2.h"

@implementation HSStreamDeckDeviceMk2

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck (Mk2)";
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
