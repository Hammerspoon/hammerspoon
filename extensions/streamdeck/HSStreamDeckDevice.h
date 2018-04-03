//
//  HSStreamDeckDevice.h
//  Hammerspoon
//
//  Created by Chris Jones on 06/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

@import Foundation;
@import Cocoa;
@import IOKit;
@import IOKit.hid;
@import LuaSkin;

#import "NSImage+BMP.h"
#import "streamdeck.h"

@interface HSStreamDeckDevice : NSObject
@property (nonatomic) IOHIDDeviceRef device;
@property (nonatomic) id manager;
@property (nonatomic) int selfRefCount;
@property (nonatomic) int buttonCallbackRef;
@property (nonatomic) BOOL isValid;

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager;
- (void)invalidate;
- (void)deviceDidSendInput:(NSNumber*)button isDown:(NSNumber*)isDown;
- (BOOL)setBrightness:(int)brightness;
- (void)reset;
- (NSString *)serialNumber;
- (NSString *)firmwareVersion;
- (void)setColor:(NSColor*)color forButton:(int)button;
- (void)setImage:(NSImage*)image forButton:(int)button;
@end
