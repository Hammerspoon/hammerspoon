#import "HSBlackmagicDeviceKeyboard.h"

@interface HSBlackmagicDeviceKeyboard ()
@end

@implementation HSBlackmagicDeviceKeyboard
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager serialNumber:serialNumber {
    self = [super initWithDevice:device manager:manager serialNumber:serialNumber];
    if (self) {
        self.deviceType = @"Editor Keyboard";
        
        self.ledLookup = @{};
        
        self.jogLEDLookup = @{
            @"JOG":                     @(1 <<  0),
            @"SHTL":                    @(1 <<  1),
            @"SCRL":                    @(1 <<  2),
        };
        
        self.jogModeLookup = @{
            //@"MODE 1":                  @0,                   // Same as third mode.
            @"ABSOLUTE":                @1,                     // Returns an “absolute” position, based on when the mode was set. It has a range of -4096 (left of 0) to 4096 (right of 0), which is half a turn. On the Editor Keyboard it has mechanical hard stops at -4096 and 4096.
            @"RELATIVE":                @2,                     // Returns a “relative” position - a positive number if turning right, and a negative number if turning left. The faster you turn, the higher the number. One step is 360.
            @"ABSOLUTE ZERO":           @3,                     // Returns an “absolute” position, based on when the mode was set. It has a range of -4096 (left of 0) to 4096 (right of 0), which is half a turn. It also has a small dead band aroundzero, which is also a mechanical stop on the Editor Keyboard.
        };
        
        self.jogModeReverseLookup = @{
            //[NSNumber numberWithInt:0]: @"MODE 1",            // Same as third mode.
            [NSNumber numberWithInt:1]: @"ABSOLUTE",            // Returns an “absolute” position, based on when the mode was set. It has a range of -4096 (left of 0) to 4096 (right of 0), which is half a turn. On the Editor Keyboard it has mechanical hard stops at -4096 and 4096.
            [NSNumber numberWithInt:2]: @"RELATIVE",            // Returns a “relative” position - a positive number if turning right, and a negative number if turning left. The faster you turn, the higher the number. One step is 360.
            [NSNumber numberWithInt:3]: @"ABSOLUTE ZERO",       // Returns an “absolute” position, based on when the mode was set. It has a range of -4096 (left of 0) to 4096 (right of 0), which is half a turn. It also has a small dead band aroundzero, which is also a mechanical stop on the Editor Keyboard.
        };

        self.buttonLookup = @{
            @"SMART INSRT":             @0x01, // Top Left
            @"APPND":                   @0x02,
            @"RIPL OWR":                @0x03,
            @"CLOSE UP":                @0x04,
            @"PLACE ON TOP":            @0x05,
            @"SRC OWR":                 @0x06,

            @"IN":                      @0x07, // Bottom Left
            @"OUT":                     @0x08,
            @"TRIM IN":                 @0x09,
            @"TRIM OUT":                @0x0a,
            @"ROLL":                    @0x0b,
            @"SLIP SRC":                @0x0c,
            @"SLIP DEST":               @0x0d,
            @"TRANS DUR":               @0x0e,
            @"CUT":                     @0x0f,
            @"DIS":                     @0x10,
            @"SMTH CUT":                @0x11,
            
            @"TIME CODE":               @0x13, // Above Num Pad
            @"CAM":                     @0x14,
            @"DATE TIME":               @0x15,
            @"CLIP NAME":               @0x16,
            
            @"TRIM EDTOR":              @0x17, // Num Pad
            @"F TC":                    @0x18,
            @"DUR ENTER":               @0x19,
            @"00":                      @0x12,
            
            @"SOURCE":                  @0x1a, // Above Jog Wheel
            @"TIMELINE":                @0x1b,
            
            @"SHTL":                    @0x1c, // Above Jog Wheel
            @"JOG":                     @0x1d,
            @"SCRL":                    @0x1e,
            
            @"SYNC BIN":                @0x1f,  // F1
            @"INSRT BLACK":             @0x20,  // F2
            @"FREEZ":                   @0x21,  // F3
            @"TRANS":                   @0x22,  // F4
            @"PIC IN PIC":              @0x23,  // F5
            @"SWAP":                    @0x24,  // F6
            @"VIDEO ONLY":              @0x25,  // F7
            @"AUDIO ONLY":              @0x26,  // F8
            @"INSERT":                  @0x27,  // F9
            @"O WR":                    @0x28,  // F10
            @"REPL":                    @0x29,  // F11
            @"FIT TO FILL":             @0x2A,  // F12
            @"RIPL DEL":                @0x2B,  // Next to F12
        };
        
        self.defaultButtonState = @{
            @"SMART INSRT":             @NO,
            @"APPND":                   @NO,
            @"RIPL OWR":                @NO,
            @"CLOSE UP":                @NO,
            @"PLACE ON TOP":            @NO,
            @"SRC OWR":                 @NO,

            @"IN":                      @NO,
            @"OUT":                     @NO,
            @"TRIM IN":                 @NO,
            @"TRIM OUT":                @NO,
            @"ROLL":                    @NO,
            @"SLIP SRC":                @NO,
            @"SLIP DEST":               @NO,
            @"TRANS DUR":               @NO,
            @"CUT":                     @NO,
            @"DIS":                     @NO,
            @"SMTH CUT":                @NO,

            @"TIME CODE":               @NO,
            @"CAM":                     @NO,
            @"DATE TIME":               @NO,
            @"CLIP NAME":               @NO,

            @"TRIM EDTOR":              @NO,
            @"F TC":                    @NO,
            @"DUR ENTER":               @NO,
            @"00":                      @NO,

            @"SOURCE":                  @NO,
            @"TIMELINE":                @NO,

            @"SHTL":                    @NO,
            @"JOG":                     @NO,
            @"SCRL":                    @NO,

            @"SYNC BIN":                @NO,
            @"INSRT BLACK":             @NO,
            @"FREEZ":                   @NO,
            @"TRANS":                   @NO,
            @"PIC IN PIC":              @NO,
            @"SWAP":                    @NO,
            @"VIDEO ONLY":              @NO,
            @"AUDIO ONLY":              @NO,
            @"INSERT":                  @NO,
            @"O WR":                    @NO,
            @"REPL":                    @NO,
            @"FIT TO FILL":             @NO,
            @"RIPL DEL":                @NO,            
        };
        
        self.buttonStateCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultButtonState];
        
        self.defaultLEDCache = @{};
        
        self.ledCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultLEDCache];
    }
    return self;
}

@end
