@import Foundation;
@import Cocoa;
@import IOKit;
@import IOKit.hid;
@import LuaSkin;
@import Darwin.POSIX.sys.time;

#include <IOKit/usb/IOUSBLib.h>

#import "razer.h"

// HSRazerResult Object:
@interface HSRazerResult : NSObject {}
@property (nonatomic) BOOL                  success;
@property (nonatomic) NSString*             errorMessage;

@property (nonatomic) NSNumber*             brightness;

@property (nonatomic) BOOL                  orangeStatusLight;
@property (nonatomic) BOOL                  greenStatusLight;
@property (nonatomic) BOOL                  blueStatusLight;
@property (nonatomic) BOOL                  yellowStatusLight;
@property (nonatomic) BOOL                  redStatusLight;

@property unsigned char                     argumentTwo;
@property unsigned char                     argumentSix;
@property unsigned char                     argumentSeven;
@property unsigned char                     argumentEight;

@end

// HSRazerDevice Object:
@interface HSRazerDevice : NSObject {}

@property (nonatomic) IOHIDDeviceRef        device;
@property (nonatomic) id                    manager;
@property (nonatomic) int                   selfRefCount;
@property (nonatomic) int                   buttonCallbackRef;
@property (nonatomic) BOOL                  isValid;

@property (nonatomic) NSNumber*             locationID;

@property CFMachPortRef                     eventTap;

@property (nonatomic) NSString*             name;
@property (nonatomic) int                   productID;

@property (nonatomic) int                   index;

// Remapping Details:
@property (nonatomic) NSDictionary*         buttonNames;
@property (nonatomic) NSDictionary*         remapping;

// Backlight Details:
@property (nonatomic) int                   backlightRows;
@property (nonatomic) int                   backlightColumns;

// Does the devices support these methods?
@property (nonatomic) BOOL                  supportsBacklightToOff;
@property (nonatomic) BOOL                  supportsBacklightToStaticColor;
@property (nonatomic) BOOL                  supportsBacklightToWave;
@property (nonatomic) BOOL                  supportsBacklightToSpectrum;
@property (nonatomic) BOOL                  supportsBacklightToReactive;
@property (nonatomic) BOOL                  supportsBacklightToStarlight;
@property (nonatomic) BOOL                  supportsBacklightToBreathing;
@property (nonatomic) BOOL                  supportsBacklightToCustom;

@property (nonatomic) BOOL                  supportsBacklightToMode;

@property (nonatomic) BOOL                  supportsOrangeStatusLight;
@property (nonatomic) BOOL                  supportsGreenStatusLight;
@property (nonatomic) BOOL                  supportsBlueStatusLight;
@property (nonatomic) BOOL                  supportsYellowStatusLight;
@property (nonatomic) BOOL                  supportsRedStatusLight;

// Scroll Wheel:
@property (nonatomic) int                   scrollWheelID;
@property (nonatomic) BOOL                  scrollWheelPressed;

@property (nonatomic) double                lastScrollWheelEvent;

@property LSGCCanary                        lsCanary;

// Create & Destory the object:
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager;
- (void)invalidate;


// Event Taps:
- (void)setupEventTap;
- (void)destroyEventTap;

// Button Callback:
- (void)deviceButtonPress:(NSString*)scancode pressed:(long)pressed;

// Backlights:
- (HSRazerResult*)setBacklightToOff;
- (HSRazerResult*)setBacklightToStaticColor:(NSColor*)color;
- (HSRazerResult*)setBacklightToWaveWithSpeed:(NSNumber*)speed direction:(NSString*)direction;
- (HSRazerResult*)setBacklightToSpectrum;
- (HSRazerResult*)setBacklightToReactiveWithColor:(NSColor*)color speed:(NSNumber*)speed;
- (HSRazerResult*)setBacklightToStarlightWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor speed:(NSNumber*)speed;
- (HSRazerResult*)setBacklightToBreathingWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor;
- (HSRazerResult*)setBacklightToCustomWithColors:(NSMutableDictionary *)customColors;

- (HSRazerResult*)setBacklightToMode:(NSString*)mode;

// Brightness:
- (HSRazerResult*)getBrightness;
- (HSRazerResult*)setBrightness:(NSNumber *)brightness;

// Status Lights:
- (HSRazerResult*)getOrangeStatusLight;
- (HSRazerResult*)setOrangeStatusLight:(BOOL)active;

- (HSRazerResult*)getGreenStatusLight;
- (HSRazerResult*)setGreenStatusLight:(BOOL)active;

- (HSRazerResult*)getBlueStatusLight;
- (HSRazerResult*)setBlueStatusLight:(BOOL)active;

- (HSRazerResult*)getYellowStatusLight;
- (HSRazerResult*)setYellowStatusLight:(BOOL)active;

- (HSRazerResult*)getRedStatusLight;
- (HSRazerResult*)setRedStatusLight:(BOOL)active;

// Hardware Communication:
- (IOUSBDeviceInterface**)getUSBRazerDevice;
- (HSRazerResult*)sendRazerReportToDeviceWithTransactionID:(int)transactionID commandClass:(int)commandClass commandID:(int)commandID arguments:(NSDictionary*)arguments;

@end

// Razer USB Device Report Structure:
union HSTransactionID {
    unsigned char id;
    struct transaction_parts {
        unsigned char device:3;                     // 3-bits: Device identifier
        unsigned char id:5;                         // 5-bits: A unique transaction ID for grouping requests
    } parts;
};

union HSCommandID {
    unsigned char id;
    struct command_id_parts {
        unsigned char direction:1;                  // 1-bit: 1 = device to Mac; 0 = Mac to device
        unsigned char id:7;                         // 7-bits: Each command has a unique ID
    } parts;
};

struct HSRazerReport {
    unsigned char           status;                 // Always 0x00 for a New Command
    union HSTransactionID   transaction_id;         // Allows you to group requests if using multiple devices
    unsigned short          remaining_packets;      // Remaining Packets (using Big Endian Byte Order)
    unsigned char           protocol_type;          // Always seems to be 0x00
    unsigned char           data_size;              // How many arguments used in the report
    unsigned char           command_class;          // The type of command being triggered
    union HSCommandID       command_id;             // The ID of the command being triggered
    unsigned char           arguments[80];          // Slots for arguments for the command being triggered
    unsigned char           crc;                    // A simple checksum using XOR
    unsigned char           reserved;               // A reserved byte - always 0x00
};
