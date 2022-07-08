#import "HSRazerOrbweaverChromaDevice.h"

@implementation HSRazerOrbweaverChromaDevice

- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super initWithDevice:device manager:manager];
    if (self) {
        // The name of the Razer Device. This should match the actual product name (i.e. Razer Tartarus V2).
        self.name               = @"Razer Orbweaver Chroma";
        
        // The product ID of the Razer Device. This can be found in "About This Mac > System Report".
        // This should be a constant that's defined in razer.h, as you'll also need to manually update
        // HSRazerManger.m if you add a new Razer device to this extension.
        self.productID          = USB_PID_RAZER_ORBWEAVER_CHROMA;
        
        //  16 bit parameter for request, low byte first. Each device can have a different index.
        self.index              = 0x01;
        
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
            
        // Which Status Lights does this device support?
        self.supportsGreenStatusLight           = YES;
        self.supportsBlueStatusLight            = YES;
        self.supportsYellowStatusLight          = YES;
                
        // A dictionary of button names. On the left is what is returned by IOHID, on the right is what we want to
        // label the buttons in Hammerspoon:
        self.buttonNames        = @{
            @"53"   : @"1",
            @"30"   : @"2",
            @"31"   : @"3",
            @"32"   : @"4",
            @"33"   : @"5",
            
            @"43"   : @"6",
            @"20"   : @"7",
            @"26"   : @"8",
            @"8"    : @"9",
            @"21"   : @"10",
            
            @"57"   : @"11",
            @"4"    : @"12",
            @"22"   : @"13",
            @"7"    : @"14",
            @"9"    : @"15",
            
            @"225"  : @"16",
            @"29"   : @"17",
            @"27"   : @"18",
            @"6"    : @"19",
            @"25"   : @"20",
            
            @"44"   : @"21",
                        
            @"226"  : @"Mode",
            
            @"82"   : @"Up",
            @"81"   : @"Down",
            @"80"   : @"Left",
            @"79"   : @"Right"
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

- (HSRazerResult*)setBacklightToOff {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x06,         // Effect ID
        @1 : @0x00,         // Red
        @2 : @0x00,         // Green
        @3 : @0x00,         // Blue
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x3F commandClass:0x03 commandID:0x0A arguments:arguments];
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
        @0 : @0x06,         // Effect ID
        @1 : red,           // Red
        @2 : green,         // Green
        @3 : blue,          // Blue
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x3F commandClass:0x03 commandID:0x0A arguments:arguments];
}

- (HSRazerResult*)setBacklightToWaveWithSpeed:(NSNumber*)speed direction:(NSString*)direction {
    
    NSNumber *directionValue = @0x01;
    if ([direction isEqualToString:@"right"]) {
        directionValue = @0x02;
    }
    
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x01,             // Variable Storage
        @3 : directionValue,    // Direction
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x03 commandID:0x0A arguments:arguments];
}

- (HSRazerResult*)setBacklightToSpectrum {
    // Setup Arguments:
    NSDictionary *arguments = @{
        @0 : @0x04,         // Effect ID
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x0A arguments:arguments];
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
        @0 : @0x02,         // Effect ID
        @1 : speed,         // Speed (1-4)
        @2 : red,           // Red
        @3 : green,         // Green
        @4 : blue,          // Blue
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x0A arguments:arguments];
}

- (HSRazerResult*)setBacklightToStarlightWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor speed:(NSNumber*)speed {
    
    //
    // NOTE: We think the Orbweaver Chroma only support one colour for Starlight mode for whatever reason.
    //
    
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
        @0 : @0x19,             // Effect ID
        @1 : @0x01,             // 1 Colour
        @2 : speed,             // Speed (1-3)
        @3 : red,               // Red
        @4 : green,             // Green
        @5 : blue,              // Blue
        @6 : @0x00,             // Red - Unused
        @7 : @0x00,             // Green - Unused
        @8 : @0x00,             // Blue - Unused
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x1F commandClass:0x0F commandID:0x02 arguments:arguments];
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
            @0 : @0x03,             // Effect ID
            @1 : @0x02,             // Two Colour Breathing Type
            @2 : red,               // Red
            @3 : green,             // Green
            @4 : blue,              // Blue
            @5 : redSecondary,      // Red Secondary
            @6: greenSecondary,     // Green Secondary
            @7: blueSecondary,      // Blue Secondary
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x0A arguments:arguments];
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
            @0 : @0x03,             // Effect ID
            @1 : @0x01,             // One Colour Breathing Type
            @2 : red,               // Red
            @3 : green,             // Green
            @4 : blue,              // Blue
            @5 : @0x00,
            @6 : @0x00,
            @7 : @0x00,
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x0A arguments:arguments];
    }
    else { // Random:
        // Setup Arguments:
        NSDictionary *arguments = @{
            @0 : @0x03,             // Effect ID
            @1 : @0x03,             // Random Breathing Type
            @2 : @0x00,
            @3 : @0x00,
            @4 : @0x00,
            @5 : @0x00,
            @6 : @0x00,
            @7 : @0x00,
        };
        
        // Send the report to the Razer USB Device:
        return [self sendRazerReportToDeviceWithTransactionID:0xFF commandClass:0x03 commandID:0x0A arguments:arguments];
    }
}

- (HSRazerResult*)setBacklightToCustomWithColors:(NSMutableDictionary *)customColors {
    
    //
    // NOTE: The number of columns is 7, despite there only being 5 physical columns on the device,
    //       because on the last row, we seem to skip a number for no apparent reason. I assume
    //       because maybe they're using the same boards as other devices that have a scroll wheel
    //       or something?
    //
    
    int numberOfRows = 4;
    int numberOfColumns = 7;
    
    int skipCounter = 1;
    int customColorsCount = 1;
    for (int row = 1; row < (numberOfRows + 1); row++)
    {
        NSMutableDictionary *arguments = [[NSMutableDictionary alloc]initWithCapacity:1];
        
        [arguments setObject:@0xFF                                                  forKey:@0]; // Frame ID
        [arguments setObject:[NSNumber numberWithInt:row]                           forKey:@1]; // Row Index
        [arguments setObject:[NSNumber numberWithInt:1]                             forKey:@2]; // Start Column
        [arguments setObject:[NSNumber numberWithInt:numberOfColumns]               forKey:@3]; // Stop Column
                                            
        int count = 4;
        for (int column = 1; column < numberOfColumns; column++)
        {
            // We basically jump over 20:
            if (skipCounter == 20) {
                NSNumber *red = [NSNumber numberWithInt:0];
                NSNumber *green = [NSNumber numberWithInt:0];
                NSNumber *blue = [NSNumber numberWithInt:0];
                
                [arguments setObject:red    forKey:[NSNumber numberWithInt:count++]];
                [arguments setObject:green  forKey:[NSNumber numberWithInt:count++]];
                [arguments setObject:blue   forKey:[NSNumber numberWithInt:count++]];
            }
            
            // ...and skip 6, 12 and 18:
            if (skipCounter != 6 && skipCounter != 12 && skipCounter != 18) {
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
            
            // Increase the skip counter:
            skipCounter++;
        }
        
        // Send the report to the Razer USB Device:
        HSRazerResult* result = [self sendRazerReportToDeviceWithTransactionID:0x3F commandClass:0x03 commandID:0x0B arguments:arguments];
        if (![result success]) {
            // Abort early if something goes wrong:
            return result;
        }
    }
    
    // Setup Arguments:
    NSDictionary *modeArguments = @{
        @0  : @0x05,        // Effect ID
        @1  : @0x00,        // No Variable Storage
    };
    
    // Send the report to the Razer USB Device:
    return [self sendRazerReportToDeviceWithTransactionID:0x3F commandClass:0x03 commandID:0x0A arguments:modeArguments];
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

@end