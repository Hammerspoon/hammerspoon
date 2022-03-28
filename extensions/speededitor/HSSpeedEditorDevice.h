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
@property (nonatomic) LSGCCanary lsCanary;

@property (nonatomic) NSString *serialNumber;

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
@property (nonatomic) NSDictionary *jogModeReverseLookup;

@property (nonatomic) NSMutableDictionary *buttonStateCache;
@property (nonatomic) NSMutableDictionary *ledCache;

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager serialNumber:serialNumber;
- (void)invalidate;

- (void)authenticate;

- (void)getBatteryStatus;

- (void)setJogLEDs:(NSDictionary*) options;
- (void)setLEDs:(NSDictionary*) options;
- (void)setJogMode:(NSString*) mode;

- (IOReturn)deviceWriteFeatureReportWithData:(NSData *)report;
- (IOReturn)deviceWriteOutputReportWithData:(NSData *)report;

- (NSData *)deviceReadFeatureReportWithLength:(int)resultLength reportID:(CFIndex)reportID;
- (NSData *)deviceReadInputReportWithLength:(int)resultLength reportID:(CFIndex)reportID;

- (void)deviceButtonUpdate:(NSMutableDictionary*)currentButtonState;
- (void)deviceJogWheelUpdateWithMode:(NSNumber*)mode value:(NSNumber*)value;

@end
