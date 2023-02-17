//
//  HSStreamDeckDeviceMk2.m
//  streamdeck
//
//  Created by Chris Hocking on 16/02/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDevicePlus.h"

@implementation HSStreamDeckDevicePlus

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck Plus";
        self.keyRows = 2;
        self.keyColumns = 4;
        self.imageWidth = 120;
        self.imageHeight = 120;
        self.imageCodec = STREAMDECK_CODEC_JPEG;
        self.imageFlipX = NO;
        self.imageFlipY = NO;
        self.imageAngle = 0;
        self.simpleReportLength = 32;
        self.reportLength = 1024;
        self.reportHeaderLength = 8;
        
        self.dataKeyOffset = 4;
        self.dataEncoderOffset = 5;
        
        self.encoderColumns = 4;
        self.encoderRows = 1;
        
        self.lcdStripWidth = 800;
        self.lcdStripHeight = 100;
        
        self.lcdReportLength = 1024;        
        self.lcdReportHeaderLength = 16;

        uint8_t resetHeader[] = {0x03, 0x02};
        self.resetCommand = [NSData dataWithBytes:resetHeader length:2];

        uint8_t brightnessHeader[] = {0x03, 0x08, 0xFF};
        self.setBrightnessCommand = [NSData dataWithBytes:brightnessHeader length:3];

        self.serialNumberCommand = 0x06;
        self.firmwareVersionCommand = 0x05;

        self.serialNumberReadOffset = 2;
        self.firmwareReadOffset = 6;
    }
    return self;
}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    [self deviceV2WriteImage:data button:button];
}

@end
