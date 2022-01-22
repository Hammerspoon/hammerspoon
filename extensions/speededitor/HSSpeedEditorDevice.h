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

@property (nonatomic) BOOL batteryCharging;
@property (nonatomic) NSNumber *batteryLevel;

@property (nonatomic) BOOL firstTimeAuthenticating;

@property NSTimer *authenticationTimer;

@property (nonatomic) NSDictionary *defaultButtonState;
@property (nonatomic) NSDictionary *defaultLEDCache;

@property (nonatomic) NSDictionary *buttonLookup;
@property (nonatomic) NSDictionary *ledLookup;
@property (nonatomic) NSDictionary *jogLEDLookup;
@property (nonatomic) NSDictionary *jogModeLookup;

@property (nonatomic) NSMutableDictionary *buttonStateCache;
@property (nonatomic) NSMutableDictionary *ledCache;

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager;
- (void)invalidate;

- (void)authenticate;

- (void)setJogLEDs:(NSDictionary*) options;
- (void)setLEDs:(NSDictionary*) options;

- (IOReturn)deviceWriteFeatureReportWithData:(NSData *)report;
- (IOReturn)deviceWriteOutputReportWithData:(NSData *)report;

- (NSData *)deviceReadWithLength:(int)resultLength reportID:(CFIndex)reportID;

- (void)deviceButtonUpdate:(NSMutableDictionary*)currentButtonState;
- (void)deviceJogWheelUpdateWithMode:(NSNumber*)mode value:(NSNumber*)value;

@end
