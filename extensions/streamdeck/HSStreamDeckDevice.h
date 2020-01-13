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
#import "NSImage+JPEG.h"
#import "NSImage+Rotated.h"
#import "NSImage+Flipped.h"

#import "streamdeck.h"


typedef enum : NSUInteger {
    STREAMDECK_CODEC_UNKNOWN,
    STREAMDECK_CODEC_BMP,
    STREAMDECK_CODEC_JPEG,
} HSStreamDeckImageCodec;

@interface HSStreamDeckDevice : NSObject {
    NSString *serialNumberCache;
}
@property (nonatomic) IOHIDDeviceRef device;
@property (nonatomic) id manager;
@property (nonatomic) int selfRefCount;
@property (nonatomic) int buttonCallbackRef;
@property (nonatomic) BOOL isValid;

@property (nonatomic) NSString *deckType;
@property (nonatomic, readonly, getter=getKeyCount) int keyCount;
@property (nonatomic) int keyColumns;
@property (nonatomic) int keyRows;
@property (nonatomic) int imageWidth;
@property (nonatomic) int imageHeight;
@property (nonatomic) HSStreamDeckImageCodec imageCodec;
@property (nonatomic) BOOL imageFlipX;
@property (nonatomic) BOOL imageFlipY;
@property (nonatomic) int imageAngle;
@property (nonatomic) int simpleReportLength;
@property (nonatomic) int reportLength;
@property (nonatomic) int reportHeaderLength;
@property (nonatomic) int dataKeyOffset;

@property (nonatomic) NSMutableArray *buttonStateCache;
@property (nonatomic, readonly, getter=getSerialNumber) NSString *serialNumber;

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager;
- (void)invalidate;
- (void)initialiseCaches;

- (IOReturn)deviceWriteSimpleReport:(uint8_t *)report reportLen:(int)reportLen;
- (IOReturn)deviceWrite:(NSData *)report;
- (void)deviceWriteImage:(NSData *)data button:(int)button;
- (NSData *)deviceRead:(int)resultLength reportID:(CFIndex)reportID;

- (int)transformKeyIndex:(int)sourceKey;
- (void)deviceDidSendInput:(NSArray*)newButtonStates;
- (BOOL)setBrightness:(int)brightness;
- (void)reset;

- (NSString *)cacheSerialNumber;
- (NSString *)firmwareVersion;
- (int)getKeyCount;

- (void)clearImage:(int)button;
- (void)setColor:(NSColor*)color forButton:(int)button;
- (void)setImage:(NSImage*)image forButton:(int)button;

@end
