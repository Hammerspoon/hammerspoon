#import "HSRazerTartarusProDevice.h"

@implementation HSRazerTartarusProDevice

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        // The name of the Razer Device. This should match the actual product name (i.e. Razer Tartarus V2).
        self.name               = @"Razer Tartarus Pro";
        
        // The product ID of the Razer Device. This can be found in "About This Mac > System Report".
        // This should be a constant that's defined in razer.h, as you'll also need to manually update
        // HSRazerManger.m if you add a new Razer device to this extension.
        self.productID          = USB_PID_RAZER_TARTARUS_PRO;
        
        //  16 bit parameter for request, low byte first. Each device can have a different index.
        self.index              = 0x02;
        
        // Number of backlight rows and columns:
        self.backlightRows      = 4;
        self.backlightColumns   = 6;
        
        // The ID of the scroll wheel. If supplied, this will enable the event tap which ignores scroll wheel movements:
        self.scrollWheelID      = 56;
        
        // Which modes does this device support?
        self.supportsBacklightToOff             = YES;
        self.supportsBacklightToStaticColor     = YES;
        self.supportsBacklightToCustom          = YES;
        
        //
        // NOTE: Whilst Synapse 3 supports more effects, I believe they're done in
        //       software, not hardware, unlike the Razer Tartarus V2.
        //
        
        // Which Status Lights does this device support?
        self.supportsOrangeStatusLight          = YES;
        self.supportsGreenStatusLight           = YES;
        self.supportsBlueStatusLight            = YES;
                
        // A dictionary of button names. On the left is what is returned by IOHID, on the right is what we want to
        // label the buttons in Hammerspoon:
        self.buttonNames        = @{
            @"30" : @"1",
            @"31": @"2",
            @"32": @"3",
            @"33": @"4",
            @"34": @"5",
            @"43": @"6",
            @"20": @"7",
            @"26": @"8",
            @"8": @"9",
            @"21": @"10",
            @"57": @"11",
            @"4": @"12",
            @"22": @"13",
            @"7": @"14",
            @"9": @"15",
            @"225": @"16",
            @"29": @"17",
            @"27": @"18",
            @"6": @"19",
            @"44": @"20",
            @"56": @"Scroll Wheel",
            @"226": @"Mode",
            @"82": @"Up",
            @"81": @"Down",
            @"80": @"Left",
            @"79": @"Right"
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
            @"0x100000025" : @"0x70000004F"
        };
    }
    return self;
}

#pragma mark - LED Backlights

- (HSRazerResult*)setBacklightToOff {
    return [self setBacklightToStaticColor:[NSColor blackColor]];
}

- (HSRazerResult*)setBacklightToStaticColor:(NSColor*)color {
    
    // Split NSColor into RGB Components:
    // SOURCE: https://developer.apple.com/library/archive/qa/qa1576/_index.html
    CGFloat redFloatValue, greenFloatValue, blueFloatValue;
    int redIntValue, greenIntValue, blueIntValue;
        
    NSColor *convertedColor = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
    
    redIntValue = redFloatValue * 255.99999f;
    greenIntValue = greenFloatValue * 255.99999f;
    blueIntValue = blueFloatValue * 255.99999f;
    
    NSNumber *red = [NSNumber numberWithInt:redIntValue];
    NSNumber *green = [NSNumber numberWithInt:greenIntValue];
    NSNumber *blue = [NSNumber numberWithInt:blueIntValue];
    
    /*
     ================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     ================================================================================================
     00          1f      000000      44          0f          03          00          00 00 00 14 ff0000 ff0000 ff0000 ff0000 ff0000
                                                                         0           1  2  3  4  5 6 7  8      11     14     17
     
                                                                                     ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000
                                                                                     20     23     26     29     32     35     38     41
     
                                                                                     ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 00
                                                                                     44     47     50     53     56     59     62     65     68
     */
    
    
    NSMutableDictionary *arguments = [[NSMutableDictionary alloc]initWithCapacity:69];
    
    [arguments setObject:@0x00 forKey:@0];
    [arguments setObject:@0x00 forKey:@1];
    [arguments setObject:@0x00 forKey:@2];
    [arguments setObject:@0x00 forKey:@3];
    [arguments setObject:@0x14 forKey:@4];
    // All the colour data goes here.
    [arguments setObject:@0x00 forKey:@68];
    
    int count = 5;
    for (int buttonID = 1; buttonID <= 21; buttonID++)
    {
        [arguments setObject:red    forKey:[NSNumber numberWithInt:count++]];
        [arguments setObject:green  forKey:[NSNumber numberWithInt:count++]];
        [arguments setObject:blue   forKey:[NSNumber numberWithInt:count++]];
    }
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x03 arguments:arguments];
}

- (HSRazerResult*)setBacklightToCustomWithColors:(NSMutableDictionary *)customColors {    
    /*
     ================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     ================================================================================================
     00          1f      000000      44          0f          03          00          00 00 00 14 ff0000 ff0000 ff0000 ff0000 ff0000
                                                                         0           1  2  3  4  5 6 7  8      11     14     17
     
                                                                                     ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000
                                                                                     20     23     26     29     32     35     38     41
     
                                                                                     ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 ff0000 00
                                                                                     44     47     50     53     56     59     62     65     68
     */
        
    NSMutableDictionary *arguments = [[NSMutableDictionary alloc]initWithCapacity:69];
    
    [arguments setObject:@0x00 forKey:@0];
    [arguments setObject:@0x00 forKey:@1];
    [arguments setObject:@0x00 forKey:@2];
    [arguments setObject:@0x00 forKey:@3];
    [arguments setObject:@0x14 forKey:@4];
    // All the colour data goes here between keys 5 and 67.
    [arguments setObject:@0x00 forKey:@68];
    
    int count = 5;
    for (int buttonID = 1; buttonID <= 21; buttonID++)
    {
        NSColor *currentColor = customColors[@(buttonID)];
        if (currentColor) {
            CGFloat redFloatValue, greenFloatValue, blueFloatValue;
            int redIntValue, greenIntValue, blueIntValue;
                
            NSColor *convertedColor = [currentColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
            [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
            
            redIntValue = redFloatValue * 255.99999f;
            greenIntValue = greenFloatValue * 255.99999f;
            blueIntValue = blueFloatValue * 255.99999f;
            
            NSNumber *red = [NSNumber numberWithInt:redIntValue];
            NSNumber *green = [NSNumber numberWithInt:greenIntValue];
            NSNumber *blue = [NSNumber numberWithInt:blueIntValue];
    
            [arguments setObject:red    forKey:[NSNumber numberWithInt:count++]];
            [arguments setObject:green  forKey:[NSNumber numberWithInt:count++]];
            [arguments setObject:blue   forKey:[NSNumber numberWithInt:count++]];
        } else {
            NSNumber *red = [NSNumber numberWithInt:0];
            NSNumber *green = [NSNumber numberWithInt:0];
            NSNumber *blue = [NSNumber numberWithInt:0];
            
            [arguments setObject:red    forKey:[NSNumber numberWithInt:count++]];
            [arguments setObject:green  forKey:[NSNumber numberWithInt:count++]];
            [arguments setObject:blue   forKey:[NSNumber numberWithInt:count++]];
        }
    }
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x03 arguments:arguments];
}

#pragma mark - LED Brightness

- (HSRazerResult*)getBrightness {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,
        @1 : @0x00,
        @2 : @0x00,
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x84 arguments:arguments];
    
    // The brightness comes back on argument 2 as 0-255, so we convert it to 0-100 range:
    if ([result success]) {
        unsigned char argumentTwo = [result argumentTwo];
        result.brightness = @(round(argumentTwo / 2.55));
    }
    
    return result;
}

- (HSRazerResult*)setBrightness:(NSNumber *)brightness {

    /*
     ================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     ================================================================================================
     00          1f      000000      03          0f          04          01          00 7f
                                                                         0           1  2
     */
    
    // We get the brightness in a 0-100 range, and we need to convert it to 0-255:
    brightness = @(round([brightness integerValue] * 2.55));
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Sub Command
        @1 : @0x00,         // Reserved
        @2 : brightness,    // Brightness Value
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x04 arguments:arguments];
    
    // The brightness comes back on argument 2 as 0-255, so we convert it to 0-100 range:
    if ([result success]) {
        unsigned char argumentTwo = [result argumentTwo];
        result.brightness = @(round(argumentTwo / 2.55));
    }
    
    return result;
}

#pragma mark - Status Lights
    
- (HSRazerResult*)setOrangeStatusLight:(BOOL)active {
    
    /*
     =======================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     =======================================================================================================
     00          1f      000000      09          0f          02          01          0b 01 00 01 01 ff 00 00
                                                                         0           1  2  3  4  5  6  7  8
    */
    
    // First we need to get the green and blue status:
    HSRazerResult *greenResult = [self getGreenStatusLight];
    HSRazerResult *blueResult = [self getBlueStatusLight];
    
    NSNumber *greenStatus = @0x00;
    if ([greenResult success]) {
        int argumentSeven = [greenResult argumentSeven];
        if (argumentSeven == 0xff) {
            greenStatus = @0xff;
        }
    }
    
    NSNumber *blueStatus = @0x00;
    if ([blueResult success]) {
        int argumentEight = [blueResult argumentEight];
        if (argumentEight == 0xff) {
            blueStatus = @0xff;
        }
    }
    
    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0xff;
    }
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : @(onOrOff),        // Orange
        @7 : greenStatus,       // Green
        @8 : blueStatus,        // Blue
    };

    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)getOrangeStatusLight {
    /*
     =======================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     =======================================================================================================
     00          1f      000000      06          0f          02          00          00 08 00 01 00
    */
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : @0x00,     // Orange Status
        @7 : @0x00,     // Green Status
        @8 : @0x00,     // Blue Status
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x82 arguments:arguments];
        
    // The status comes back on argument two:
    if ([result success]) {
        int argumentSix = [result argumentSix];
        if (argumentSix == 0xff) {
            result.orangeStatusLight = YES;
        } else {
            result.orangeStatusLight = NO;
        }
    }
    
    return result;
}

- (HSRazerResult*)setGreenStatusLight:(BOOL)active {
    /*
     =======================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     =======================================================================================================
     00          1f      000000      09          0f          02          01          0b 01 00 01 01 00 ff 00
                                                                         0           1  2  3  4  5  6  7  8
    */

    // First we need to get the orange and blue status:
    HSRazerResult *orangeResult = [self getOrangeStatusLight];
    HSRazerResult *blueResult = [self getBlueStatusLight];
    
    NSNumber *orangeStatus = @0x00;
    if ([orangeResult success]) {
        int argumentSix = [orangeResult argumentSix];
        if (argumentSix == 0xff) {
            orangeStatus = @0xff;
        }
    }
    
    NSNumber *blueStatus = @0x00;
    if ([blueResult success]) {
        int argumentEight = [blueResult argumentEight];
        if (argumentEight == 0xff) {
            blueStatus = @0xff;
        }
    }
    
    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0xff;
    }
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : orangeStatus,      // Orange
        @7 : @(onOrOff),        // Green
        @8 : blueStatus,        // Blue
    };
        
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)getGreenStatusLight {
            
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : @0x00,
        @7 : @0x00, // Green Status
        @8 : @0x00,
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x82 arguments:arguments];
    
    // The status comes back on argument two:
    if ([result success]) {
        int argumentSeven = [result argumentSeven];
        if (argumentSeven == 0xff) {
            result.greenStatusLight = YES;
        } else {
            result.greenStatusLight = NO;
        }
    }
    
    return result;
}

- (HSRazerResult*)setBlueStatusLight:(BOOL)active {
    /*
     =======================================================================================================
     Direction   ID      000000      # Params    CMD Class   Command     Sub-CMD     Params
     =======================================================================================================
     00          1f      000000      09          0f          02          01          0b 01 00 01 01 00 00 ff
                                                                         0           1  2  3  4  5  6  7  8
    */
    
    // First we need to get the orange and green status:
    HSRazerResult *orangeResult = [self getOrangeStatusLight];
    HSRazerResult *greenResult = [self getGreenStatusLight];
    
    NSNumber *orangeStatus = @0x00;
    if ([orangeResult success]) {
        int argumentSix = [orangeResult argumentSix];
        if (argumentSix == 0xff) {
            orangeStatus = @0xff;
        }
    }
    
    NSNumber *greenStatus = @0x00;
    if ([greenResult success]) {
        int argumentSeven = [greenResult argumentSeven];
        if (argumentSeven == 0xff) {
            greenStatus = @0xff;
        }
    }
    
    unsigned char onOrOff = 0x00;
    if (active) {
        onOrOff = 0xff;
    }
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : orangeStatus,
        @7 : greenStatus,
        @8 : @(onOrOff),
    };
        
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)getBlueStatusLight {
            
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,
        @1 : @0x0b,
        @2 : @0x01,
        @3 : @0x00,
        @4 : @0x01,
        @5 : @0x01,
        @6 : @0x00,
        @7 : @0x00,
        @8 : @0x00, // Blue Status
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1f commandClass:0x0f commandID:0x82 arguments:arguments];
    
    // The status comes back on argument two:
    if ([result success]) {
        int argumentEight = [result argumentEight];
        if (argumentEight == 0xff) {
            result.blueStatusLight = YES;
        } else {
            result.blueStatusLight = NO;
        }
    }
    
    return result;
}

@end
