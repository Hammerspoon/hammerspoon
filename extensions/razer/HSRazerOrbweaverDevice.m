#import "HSRazerOrbweaverDevice.h"

@implementation HSRazerOrbweaverDevice

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        // The name of the Razer Device. This should match the actual product name (i.e. Razer Tartarus V2).
        self.name               = @"Razer Orbweaver";

        // The product ID of the Razer Device. This can be found in "About This Mac > System Report".
        // This should be a constant that's defined in razer.h, as you'll also need to manually update
        // HSRazerManger.m if you add a new Razer device to this extension.
        self.productID          = USB_PID_RAZER_ORBWEAVER;
        
        //  16 bit parameter for request, low byte first. Each device can have a different index.
        self.index              = 0x01;
        
        // Which modes does this device support?
        self.supportsBacklightToMode            = YES;
        
        // Which Status Lights does this device support?
        self.supportsGreenStatusLight           = YES;
        self.supportsBlueStatusLight            = YES;
        self.supportsYellowStatusLight          = YES;

        // A dictionary of button names. On the left is what is returned by IOHID, on the right is what we want to
        // label the buttons in Hammerspoon:
        self.buttonNames        = @{
            @"53":  @"1",
            @"30":  @"2",
            @"31":  @"3",
            @"32":  @"4",
            @"33":  @"5",
            
            @"43":  @"6",
            @"20":  @"7",
            @"26":  @"8",
            @"8":   @"9",
            @"21":  @"10",
                        
            @"57":  @"11",
            @"4":   @"12",
            @"22":  @"13",
            @"7":   @"14",
            @"9":   @"15",
            
            @"225": @"16",
            @"29":  @"17",
            @"27":  @"18",
            @"6":   @"19",
            @"25":  @"20",
                        
            @"44":  @"21",
                        
            @"226": @"Mode",
            
            @"82":  @"Up",
            @"81":  @"Down",
            @"80":  @"Left",
            @"79":  @"Right"
        };
       
        // A dictionary of remapping values. On the left is "dummy" keys. On the right is actual HID Keyboard codes.
        // You can use this website to help determine the HID Keyboard codes: https://hidutil-generator.netlify.app
        self.remapping          = @{
            @"0x100000001" : @"0x70000001E",
            @"0x100000002" : @"0x70000001F",
            @"0x100000003" : @"0x700000020",
            @"0x100000004" : @"0x700000021",
            @"0x100000005" : @"0x700000022",
            @"0x100000006" : @"0x70000002B",
            @"0x100000007" : @"0x700000014",
            @"0x100000008" : @"0x70000001A",
            @"0x100000009" : @"0x700000008",
            @"0x100000010" : @"0x700000015",
            @"0x100000011" : @"0x700000039",
            @"0x100000012" : @"0x700000004",
            @"0x100000013" : @"0x700000016",
            @"0x100000014" : @"0x700000007",
            @"0x100000015" : @"0x700000009",
            @"0x100000016" : @"0x7000000E1",
            @"0x100000017" : @"0x70000001D",
            @"0x100000018" : @"0x70000001B",
            @"0x100000019" : @"0x700000006",
            @"0x100000020" : @"0x70000002C",
            @"0x100000021" : @"0x700000035",
            @"0x100000022" : @"0x700000052",
            @"0x100000023" : @"0x700000051",
            @"0x100000024" : @"0x700000050",
            @"0x100000025" : @"0x70000004F",
            @"0x100000026" : @"0x700000019"
        };
    }
    return self;
}

#pragma mark - LED Backlights

- (HSRazerResult*)setBacklightToMode:(NSString*)mode {
    NSNumber* theMode = @0;
    if ([mode isEqualToString:@"static"])   { theMode = @0; };
    if ([mode isEqualToString:@"flashing"]) { theMode = @1; };
    if ([mode isEqualToString:@"fading"])   { theMode = @2; };
        
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : theMode,       // Effect ID
    };

    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x02 arguments:arguments];
}

#pragma mark - Status Lights

- (HSRazerResult*)setGreenStatusLight:(BOOL)active {

    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0x01;
    }

    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0C,         // LED ID
        @2 : @(onOrOff),    // Status Light Value
    };

    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getGreenStatusLight {

    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0C,         // LED ID
        @2 : @0x00,         // Reserved
    };

    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x80 arguments:arguments];

    // The status comes back on argument two:
    if ([result success]) {
        int argumentTwo = [result argumentTwo];
        if (argumentTwo == 1) {
            result.greenStatusLight = YES;
        } else {
            result.greenStatusLight = NO;
        }
    }

    return result;
}

- (HSRazerResult*)setBlueStatusLight:(BOOL)active {

    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0x01;
    }

    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0D,         // LED ID
        @2 : @(onOrOff),    // Status Light Value
    };

    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getBlueStatusLight {

    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0D,         // LED ID
        @2 : @0x00,         // Reserved
    };

    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x80 arguments:arguments];

    // The status comes back on argument two:
    if ([result success]) {
        int argumentTwo = [result argumentTwo];
        if (argumentTwo == 1) {
            result.blueStatusLight = YES;
        } else {
            result.blueStatusLight = NO;
        }
    }

    return result;
}

- (HSRazerResult*)setYellowStatusLight:(BOOL)active {

    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0x01;
    }

    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0E,         // LED ID
        @2 : @(onOrOff),    // Status Light Value
    };

    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getYellowStatusLight {
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0E,         // LED ID
        @2 : @0x00,         // Reserved
    };

    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x00 commandClass:0x03 commandID:0x80 arguments:arguments];

    // The status comes back on argument two:
    if ([result success]) {
        int argumentTwo = [result argumentTwo];
        if (argumentTwo == 1) {
            result.yellowStatusLight = YES;
        } else {
            result.yellowStatusLight = NO;
        }
    }

    return result;
}

#pragma mark - LED Brightness

- (HSRazerResult*)getBrightness {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x00,         // Effect ID
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x83 arguments:arguments];
    
    // The brightness comes back on argument 2 as 0-255, so we convert it to 0-100 range:
    if ([result success]) {
        unsigned char argumentTwo = [result argumentTwo];
        result.brightness = @(round(argumentTwo / 2.55));
    }
    
    return result;
}

- (HSRazerResult*)setBrightness:(NSNumber *)brightness {
    
    // We get the brightness in a 0-100 range, and we need to convert it to 0-255:
    brightness = @(round([brightness integerValue] * 2.55));
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : brightness,    // Brightness Value
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x03 arguments:arguments];
    
    // The brightness comes back on argument 2 as 0-255, so we convert it to 0-100 range:
    if ([result success]) {
        unsigned char argumentTwo = [result argumentTwo];
        result.brightness = @(round(argumentTwo / 2.55));
    }
    
    return result;
}

@end
