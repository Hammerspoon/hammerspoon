#import "HSRazerTartarusV2Device.h"

@implementation HSRazerTartarusV2Device

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        // The name of the Razer Device. This should match the actual product name (i.e. Razer Tartarus V2).
        self.name               = @"Razer Tartarus V2";
        
        // The product ID of the Razer Device. This can be found in "About This Mac > System Report".
        // This should be a constant that's defined in razer.h, as you'll also need to manually update
        // HSRazerManger.m if you add a new Razer device to this extension.
        self.productID          = USB_PID_RAZER_TARTARUS_V2;
        
        //  16 bit parameter for request, low byte first. Each device can have a different index.
        self.index              = 0x01;
        
        // Number of backlight rows and columns:
        self.backlightRows      = 4;
        self.backlightColumns   = 6;
        
        // The ID of the scroll wheel. If supplied, this will enable the event tap which ignores scroll wheel movements:
        self.scrollWheelID      = 56;
        
        // Which modes does this device support?
        self.supportsBacklightToOff             = YES;
        self.supportsBacklightToStaticColor     = YES;
        self.supportsBacklightToWave            = YES;
        self.supportsBacklightToSpectrum        = YES;
        self.supportsBacklightToReactive        = YES;
        self.supportsBacklightToStarlight       = YES;
        self.supportsBacklightToBreathing       = YES;
        self.supportsBacklightToCustom          = YES;
        
        self.supportsBacklightToMode            = NO;
        
        self.supportsOrangeStatusLight          = YES;
        self.supportsGreenStatusLight           = YES;
        self.supportsBlueStatusLight            = YES;
        self.supportsYellowStatusLight          = NO;
                
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

/*
    Effects Names in Manual (https://cdn.cnetcontent.com/ee/5d/ee5df3cf-aa45-4dcc-bdb3-30762f249e51.pdf):
 
    - Breathing         The keypad lighting fades in and            Select up to 2 colors or randomize colors
                        out of the selected color(s)
    - Fire              The keypad will light up in warm colors     No further customization required
                        to mimic the motion of flames
    - Reactive          The pressed scroll wheel or key will        Select a color and a duration
                        light up and fade off after a specified
                        period of time
    - Ripple            The lighting will ripple away from          Select a color
                        the pressed scroll wheel or key
    - Spectrum cycling  The keypad lighting will cycle              No further customization required
                        between 16.8 million colors
                        indefinitely
    - Starlight         Each LED will have a chance of              Select up to 2 colors or randomize
                        fading in and out at a random               colors and select a duration
                        time and duration
    - Static            The keypad will remain lit in               Select a color
                        the selected color
    - Wave              The lighting will scroll in                 Select either left-to-right or
                        the direction selected                      right- to-left wave direction
 */

- (HSRazerResult*)setBacklightToOff {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x00,         // Effect ID
        @3 : @0x00,         // Reserved
        @4 : @0x00,         // Reserved
        @5 : @0x00,         // Reserved
        @6 : @0x00,         // Reserved
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
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
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x01,         // Effect ID
        @3 : @0x00,         // Reserved
        @4 : @0x00,         // Reserved
        @5 : @0x01,         // 0x01
        @6 : red,           // Red
        @7 : green,         // Green
        @8 : blue,          // Blue
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)setBacklightToWaveWithSpeed:(NSNumber*)speed direction:(NSString*)direction {
    
    NSNumber *directionValue = @1;
    if ([direction isEqualToString:@"right"]) {
        directionValue = @2;
    }
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,             // Variable Storage
        @1 : @0x05,             // LED ID
        @2 : @0x04,             // Effect ID
        @3 : directionValue,    // Direction
        @4 : speed,             // Speed
        @5 : @0x00,             // Reserved
        @6 : @0x00,             // Reserved
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)setBacklightToSpectrum {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x03,         // Effect ID
        @3 : @0x00,         // Reserved
        @4 : @0x00,         // Reserved
        @5 : @0x01,         // Reserved
        @6 : @0x00,         // Reserved
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)setBacklightToFire {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x06,         // Effect ID
        @3 : @0x00,         // Reserved
        @4 : @0x00,         // Reserved
        @5 : @0x01,         // Reserved
        @6 : @0x00,         // Reserved
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)setBacklightToReactiveWithColor:(NSColor*)color speed:(NSNumber*)speed {
    
    // Split NSColor into RGB Components:
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
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,         // Variable Storage
        @1 : @0x05,         // LED ID
        @2 : @0x05,         // Effect ID
        @3 : @0x00,         // Reserved
        @4 : speed,         // Speed (1-4)
        @5 : @0x01,         // Reserved
        @6 : red,           // Red
        @7 : green,         // Green
        @8 : blue,          // Blue
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
}

- (HSRazerResult*)setBacklightToStarlightWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor speed:(NSNumber*)speed {
    if (color && secondaryColor) {
        // Two colours:
        
        // Convert the colours into components:
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
        
        // Convert the secondary colours into components:
        convertedColor = [secondaryColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
        
        redIntValue = redFloatValue * 255.99999f;
        greenIntValue = greenFloatValue * 255.99999f;
        blueIntValue = blueFloatValue * 255.99999f;
        
        NSNumber *redSecondary = [NSNumber numberWithInt:redIntValue];
        NSNumber *greenSecondary = [NSNumber numberWithInt:greenIntValue];
        NSNumber *blueSecondary = [NSNumber numberWithInt:blueIntValue];
                
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x07,             // Effect ID
            @3 : @0x00,             // Reserved
            @4 : speed,             // Speed (1-3)
            @5 : @0x02,             // Starlight Mode
            @6 : red,               // Red
            @7 : green,             // Green
            @8 : blue,              // Blue
            @9 : redSecondary,      // Red Secondary
            @10: greenSecondary,    // Green Secondary
            @11: blueSecondary,     // Blue Secondary
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
    else if (color) {
        // One colour:

        // Convert the colours into components:
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
        
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x07,             // Effect ID
            @3 : @0x00,             // Reserved
            @4 : speed,             // Speed (1-3)
            @5 : @0x01,             // Starlight Mode
            @6 : red,               // Red
            @7 : green,             // Green
            @8 : blue,              // Blue
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
    else {
        // Random:
        
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x07,             // Effect ID
            @3 : @0x00,             // Reserved
            @4 : speed,             // Speed (1-3)
            @5 : @0x00,             // Starlight Mode
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
}

- (HSRazerResult*)setBacklightToBreathingWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor {
    if (color && secondaryColor) { // Two colours:
        // Convert the colours into components:
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
        
        // Convert the secondary colours into components:
        convertedColor = [secondaryColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
        
        redIntValue = redFloatValue * 255.99999f;
        greenIntValue = greenFloatValue * 255.99999f;
        blueIntValue = blueFloatValue * 255.99999f;
        
        NSNumber *redSecondary = [NSNumber numberWithInt:redIntValue];
        NSNumber *greenSecondary = [NSNumber numberWithInt:greenIntValue];
        NSNumber *blueSecondary = [NSNumber numberWithInt:blueIntValue];
        
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x02,             // Effect ID
            @3 : @0x02,             // Breath Mode
            @4 : @0x00,             // Reserved
            @5 : @0x02,             // Breath Mode
            @6 : red,               // Red
            @7 : green,             // Green
            @8 : blue,              // Blue
            @9 : redSecondary,      // Red Secondary
            @10: greenSecondary,    // Green Secondary
            @11: blueSecondary,     // Blue Secondary
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
    else if (color) { // One colour:
        // Convert the colours into components:
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
        
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x02,             // Effect ID
            @3 : @0x01,             // Breath Mode
            @4 : @0x00,             // Reserved
            @5 : @0x01,             // Breath Mode
            @6 : red,               // Red
            @7 : green,             // Green
            @8 : blue,              // Blue
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
    else { // Random:
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x01,             // Variable Storage
            @1 : @0x05,             // LED ID
            @2 : @0x02,             // Effect ID
            @3 : @0x00,             // Breath Mode
            @4 : @0x00,             // Reserved
            @5 : @0x00,             // Breath Mode
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
    }
}

- (HSRazerResult*)setBacklightToCustomWithColors:(NSMutableDictionary *)customColors {
    
    int customColorsCount = 1;
    for (int row = 0; row < self.backlightRows; row++)
    {
        NSMutableDictionary *arguments = [[NSMutableDictionary alloc]initWithCapacity:1];
        
        [arguments setObject:@0x00                                                  forKey:@0]; // Reserved
        [arguments setObject:@0x00                                                  forKey:@1]; // Reserved
        [arguments setObject:[NSNumber numberWithInt:row]                           forKey:@2]; // Row Index
        [arguments setObject:[NSNumber numberWithInt:0]                             forKey:@3]; // Start Column
        [arguments setObject:[NSNumber numberWithInt:self.backlightColumns - 1]     forKey:@4]; // Stop Column
                                            
        int count = 5;
        for (int column = 0; column < self.backlightColumns; column++)
        {
            NSColor *currentColor = customColors[@(customColorsCount++)];
            
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
        HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x03 arguments:arguments];
        if (![result success]) {
            // Abort early if something goes wrong:
            return result;
        }
    }
    
    // Setup Arguments:
    NSDictionary *modeArguments = @{
        @0  : @0x00,        // Variable Storage
        @1  : @0x00,        // LED ID
        @2  : @0x08,        // Effect ID
        @3  : @0x00,        // Reserved
        @4  : @0x00,        // Reserved
        @5  : @0x00,        // Reserved
        @6  : @0x00,        // Reserved
        @7  : @0x00,        // Reserved
        @8  : @0x00,        // Reserved
        @9  : @0x00,        // Reserved
        @10 : @0x00,        // Reserved
        @11 : @0x00,        // Reserved
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:modeArguments];
}

#pragma mark - LED Brightness

- (HSRazerResult*)getBrightness {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x00,         // LED ID
        @2 : @0x00,         // Effect ID
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x84 arguments:arguments];
    
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
        @0 : @0x00,         // Variable Storage
        @1 : @0x00,         // LED ID
        @2 : brightness,    // Brightness Value
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x04 arguments:arguments];
    
    // The brightness comes back on argument 2 as 0-255, so we convert it to 0-100 range:
    if ([result success]) {
        unsigned char argumentTwo = [result argumentTwo];
        result.brightness = @(round(argumentTwo / 2.55));
    }
    
    return result;
}

#pragma mark - Status Lights

- (HSRazerResult*)setOrangeStatusLight:(BOOL)active {
    
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
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getOrangeStatusLight {
            
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0C,         // LED ID
        @2 : @0x00,         // Reserved
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x80 arguments:arguments];
    
    // The status comes back on argument two:
    if ([result success]) {
        int argumentTwo = [result argumentTwo];
        if (argumentTwo == 1) {
            result.orangeStatusLight = YES;
        } else {
            result.orangeStatusLight = NO;
        }
    }
    
    return result;
}

- (HSRazerResult*)setGreenStatusLight:(BOOL)active {
    
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
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getGreenStatusLight {
            
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0D,         // LED ID
        @2 : @0x00,         // Reserved
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x80 arguments:arguments];
    
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
        @1 : @0x0E,         // LED ID
        @2 : @(onOrOff),    // Status Light Value
    };
        
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x00 arguments:arguments];
}

- (HSRazerResult*)getBlueStatusLight {
            
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x00,         // Variable Storage
        @1 : @0x0E,         // LED ID
        @2 : @0x00,         // Reserved
    };
        
    // Send the report to the Razer USB Device:
    HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x80 arguments:arguments];
    
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

@end
