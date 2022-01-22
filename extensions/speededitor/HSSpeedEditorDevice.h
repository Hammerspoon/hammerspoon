@import Foundation;
@import Cocoa;
@import IOKit;
@import IOKit.hid;
@import LuaSkin;

#import "speededitor.h"

@interface HSSpeedEditorDevice : NSObject {}

@property (nonatomic) IOHIDDeviceRef device;
@property (nonatomic) id manager;
@property (nonatomic) int selfRefCount;
@property (nonatomic) int callbackRef;
@property (nonatomic) BOOL isValid;

@property (nonatomic) NSDictionary *defaultButtonState;

@property (nonatomic) NSDictionary *buttonLookup;
@property (nonatomic) NSDictionary *ledLookup;

@property (nonatomic) NSMutableDictionary *buttonStateCache;

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager;
- (void)invalidate;

- (void)authenticate;

- (IOReturn)deviceWriteWithData:(NSData *)report;
- (NSData *)deviceReadWithLength:(int)resultLength reportID:(CFIndex)reportID;

- (void)deviceButtonUpdate:(NSMutableDictionary*)currentButtonState;
- (void)deviceJogWheelUpdateWithMode:(NSNumber*)mode value:(NSNumber*)value;

@end
