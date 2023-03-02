//
//  HSStreamDeckDevicePedal.m
//  streamdeck
//
//  Created by Chris Hocking on 02/03/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

#import "HSStreamDeckDevicePedal.h"

@implementation HSStreamDeckDevicePedal

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        self.deckType = @"Elgato Stream Deck Pedal";
        self.keyRows = 1;
        self.keyColumns = 3;
        
        self.simpleReportLength = 32;
        self.reportLength = 1024;
        self.reportHeaderLength = 8;
        self.dataKeyOffset = 4;

        uint8_t resetHeader[] = {0x03, 0x02};
        self.resetCommand = [NSData dataWithBytes:resetHeader length:2];

        self.serialNumberCommand = 0x06;
        self.firmwareVersionCommand = 0x05;

        self.serialNumberReadOffset = 2;
        self.firmwareReadOffset = 6;
    }
    return self;
}

- (void)setImage:(NSImage *)image forButton:(int)button {
    // Do nothing
}

- (void)deviceWriteImage:(NSData *)data button:(int)button {
    // Do nothing
}

- (void)setLCDImage:(NSImage *)image forEncoder:(int)encoder {
    // Do nothing
}

@end
