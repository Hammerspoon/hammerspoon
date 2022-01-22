#import "HSSpeedEditorDevice.h"

#include <stdint.h>
#include <stdio.h>

@interface HSSpeedEditorDevice ()
@end

@implementation HSSpeedEditorDevice
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super init];
    if (self) {
        self.device = device;
        self.isValid = YES;
        self.manager = manager;
        self.callbackRef = LUA_NOREF;
        self.selfRefCount = 0;
        
        self.firstTimeAuthenticating = YES;
        
        self.batteryCharging = NO;
        self.batteryLevel = @-1;
        
        self.ledLookup = @{
            @"CLOSE UP":                @(1 <<  0),
            @"CUT":                     @(1 <<  1),
            @"DIS":                     @(1 <<  2),
            @"SMTH CUT":                @(1 <<  3),
            @"TRANS":                   @(1 <<  4),
            @"SNAP":                    @(1 <<  5),
            @"CAM 7":                   @(1 <<  6),
            @"CAM 8":                   @(1 <<  7),
            @"CAM 9":                   @(1 <<  8),
            @"LIVE OWR":                @(1 <<  9),
            @"CAM 4":                   @(1 << 10),
            @"CAM 5":                   @(1 << 11),
            @"CAM 6":                   @(1 << 12),
            @"VIDEO ONLY":              @(1 << 13),
            @"CAM 1":                   @(1 << 14),
            @"CAM 2":                   @(1 << 15),
            @"CAM 3":                   @(1 << 16),
            @"AUDIO ONLY":              @(1 << 17),
        };
        
        self.jogLEDLookup = @{
            @"JOG":                     @(1 <<  0),
            @"SHTL":                    @(1 <<  1),
            @"SCRL":                    @(1 <<  2),
        };
        
        self.jogModeLookup = @{
            @"RELATIVE 0":              @0,        // Rela
            @"ABSOLUTE CONTINUOUS":     @1,        // Send an "absolute" position (based on the position when mode was set) -4096 -> 4096 range ~ half a turn
            @"RELATIVE 2":              @2,        // Same as mode 0 ?
            @"ABSOLUTE DEADZERO":       @3,        // Same as mode 1 but with a small dead band around zero that maps to 0
        };
                
        self.buttonLookup = @{
            @"SMART INSRT":             @0x01,
            @"APPND":                   @0x02,
            @"RIPL OWR":                @0x03,
            @"CLOSE UP":                @0x04,
            @"PLACE ON TOP":            @0x05,
            @"SRC_OWR":                 @0x06,
            @"IN":                      @0x07,
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
            @"SOURCE":                  @0x1a,
            @"TIMELINE":                @0x1b,
            @"SHTL":                    @0x1c,
            @"JOG":                     @0x1d,
            @"SCRL":                    @0x1e,
            @"ESC":                     @0x31,
            @"SYNC BIN":                @0x1f,
            @"AUDIO LEVEL":             @0x2c,
            @"FULL VIEW":               @0x2d,
            @"TRANS":                   @0x22,
            @"SPLIT":                   @0x2f,
            @"SNAP":                    @0x2e,
            @"RIPL DEL":                @0x2b,
            @"CAM 1":                   @0x33,
            @"CAM 2":                   @0x34,
            @"CAM 3":                   @0x35,
            @"CAM 4":                   @0x36,
            @"CAM 5":                   @0x37,
            @"CAM 6":                   @0x38,
            @"CAM 7":                   @0x39,
            @"CAM 8":                   @0x3a,
            @"CAM 9":                   @0x3b,
            @"LIVE OWR":                @0x30,
            @"VIDEO ONLY":              @0x25,
            @"AUDIO ONLY":              @0x26,
            @"STOP PLAY":               @0x3c
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
            @"SOURCE":                  @NO,
            @"TIMELINE":                @NO,
            @"SHTL":                    @NO,
            @"JOG":                     @NO,
            @"SCRL":                    @NO,
            @"ESC":                     @NO,
            @"SYNC BIN":                @NO,
            @"AUDIO LEVEL":             @NO,
            @"FULL VIEW":               @NO,
            @"TRANS":                   @NO,
            @"SPLIT":                   @NO,
            @"SNAP":                    @NO,
            @"RIPL DEL":                @NO,
            @"CAM 1":                   @NO,
            @"CAM 2":                   @NO,
            @"CAM 3":                   @NO,
            @"CAM 4":                   @NO,
            @"CAM 5":                   @NO,
            @"CAM 6":                   @NO,
            @"CAM 7":                   @NO,
            @"CAM 8":                   @NO,
            @"CAM 9":                   @NO,
            @"LIVE OWR":                @NO,
            @"VIDEO ONLY":              @NO,
            @"AUDIO ONLY":              @NO,
            @"STOP PLAY":               @NO,
        };
        
        self.buttonStateCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultButtonState];
        
        self.defaultLEDCache = @{
            @"CLOSE UP":                @NO,
            @"CUT":                     @NO,
            @"DIS":                     @NO,
            @"SMTH CUT":                @NO,
            @"TRANS":                   @NO,
            @"SNAP":                    @NO,
            @"CAM 7":                   @NO,
            @"CAM 8":                   @NO,
            @"CAM 9":                   @NO,
            @"LIVE OWR":                @NO,
            @"CAM 4":                   @NO,
            @"CAM 5":                   @NO,
            @"CAM 6":                   @NO,
            @"VIDEO ONLY":              @NO,
            @"CAM 1":                   @NO,
            @"CAM 2":                   @NO,
            @"CAM 3":                   @NO,
            @"AUDIO ONLY":              @NO,
            @"JOG":                     @NO,
            @"SHTL":                    @NO,
            @"SCRL":                    @NO,
        };
        
        self.ledCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultLEDCache];

        //NSLog(@"Added new Speed Editor device %p with IOKit device %p from manager %p", (__bridge void *)self, (void*)self.device, (__bridge void *)self.manager);
    }
    return self;
}

//
// The below authentication code below is based off:
// https://github.com/smunaut/blackmagic-misc
//
// Copyright (C) 2021 Sylvain Munaut <tnt@246tNt.com>
// SPDX-License-Identifier: Apache-2.0
//

uint64_t auth_even[] = {
    0x3ae1206f97c10bc8,
    0x2a9ab32bebf244c6,
    0x20a6f8b8df9adf0a,
    0xaf80ece52cfc1719,
    0xec2ee2f7414fd151,
    0xb055adfd73344a15,
    0xa63d2e3059001187,
    0x751bf623f42e0dde,
};
 
uint64_t auth_odd[] = {
    0x3e22b34f502e7fde,
    0x24656b981875ab1c,
    0xa17f3456df7bf8c3,
    0x6df72e1941aef698,
    0x72226f011e66ab94,
    0x3831a3c606296b42,
    0xfd7ff81881332c89,
    0x61a3f6474ff236c6,
};
 
uint64_t mask = 0xa79a63f585d37bf0;
 
// Rotate the 64 bits 8 spaces to the left (or, rotate the 8 bytes 1 byte to the left):
uint64_t rol8(uint64_t v){
    return ((v << 56) | (v >> 8));
}
 
// Rotate left n times:
uint64_t rol8n(uint64_t v, uint8_t n){
    for (int i = 0; i < n; i++){
        v = rol8(v);
    }
    return v;
}
 
uint64_t bmd_kbd_auth(uint64_t challenge){
    // Mask off lower three bits, use as iteration count:
    uint8_t n = challenge & 7;
 
    // Rotate challenge n times:
    uint64_t v = rol8n(challenge, n);
    
    uint64_t k;
    
    // Even parity of v[bit0] and (0x78 >> n):
    if ( (v & 1) == ((0x78 >> n) & 1) ){
        k = auth_even[n];
    }
    // Odd parity, xor with self rotated one last time:
    else {
        v = v ^ rol8(v);
        k = auth_odd[n];
    }
 
    // Return v xored with (self rol8 bitmasked with mask) xored with k:
    return v ^ (rol8(v) & mask) ^ k;
}

- (void) authenticate {
    //
    // The authentication is performed over SET_FEATURE/GET_FEATURE on Report ID 6.
    //
    IOReturn result;
    
    //
    // Reset the authentication state machine:
    //
    uint8_t resetAuthState[] = {0x06,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    NSData *resetAuthStateData = [NSData dataWithBytes:(const void *)resetAuthState length:10];
    result = [self deviceWriteFeatureReportWithData:resetAuthStateData];
    if (result != kIOReturnSuccess) {
        [LuaSkin logError:@"[hs.speededitor] Failed to send report to reset the authentication state machine, so aborting."];
        return;
    }
    
    //
    // Read the keyboard challenge (for keyboard to authenticate app):
    //
    NSData *challengeResponse = [self deviceReadWithLength:10 reportID:6];
    NSMutableData *challenge = [NSMutableData dataWithData:challengeResponse];
    [challenge replaceBytesInRange:NSMakeRange(0, 2) withBytes:NULL length:0];
    
    //
    // Validate the response:
    //
    const char* challengeResponseBytes = (const char*)[challengeResponse bytes];
    if (challengeResponseBytes[0] != 0x06 && challengeResponseBytes[1] != 0x00) {
        [LuaSkin logError:@"[hs.speededitor] Unexpected initial response from Speed Editor, so aborting authentication."];
        return;
    }
    
    //
    // Send our challenge to authenticate the keyboard:
    //
    uint8_t sendChallenge[] = {0x06,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    NSData *sendChallengeData = [NSData dataWithBytes:(const void *)sendChallenge length:10];
    result = [self deviceWriteFeatureReportWithData:sendChallengeData];
    if (result != kIOReturnSuccess) {
        [LuaSkin logError:@"[hs.speededitor] Failed to send report with our challenge, so aborting."];
        return;
    }
    
    //
    // Read the keyboard response:
    //
    NSData *challengeResponseTwo = [self deviceReadWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseTwoBytes = (const char*)[challengeResponseTwo bytes];
    if (challengeResponseTwoBytes[0] != 0x06 && challengeResponseTwoBytes[1] != 0x02) {
        [LuaSkin logError:@"[hs.speededitor] Unexpected response from Speed Editor when sending challenge, so aborting authentication."];
        return;
    }
    
    //
    // Solve the challenge:
    //
    uint64_t challengeToSend = 0;
    [challenge getBytes:&challengeToSend length:sizeof(challengeToSend)];
    uint64_t challengeReply = bmd_kbd_auth(challengeToSend);
    
    //
    // Send our response to the challenge:
    //
    NSMutableData *challengeReplyData = [NSMutableData dataWithBytes:&challengeReply length:sizeof(challengeReply)];
    uint8_t reponseHeader[] = {0x06, 0x03};
    NSMutableData *authResponse = [NSMutableData dataWithLength:0];
    [authResponse appendBytes:reponseHeader length:2];
    [authResponse appendData:challengeReplyData];
    result = [self deviceWriteFeatureReportWithData:authResponse];
    if (result != kIOReturnSuccess) {
        [LuaSkin logError:@"[hs.speededitor] Failed to send report with our response to the challenge, so aborting."];
        return;
    }

    //
    // Read the Speed Editor status:
    //
    NSData *challengeResponseThree = [self deviceReadWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseThreeBytes = (const char*)[challengeResponseThree bytes];
    if (challengeResponseThreeBytes[0] != 0x06 && challengeResponseThreeBytes[1] != 0x04) {
        [LuaSkin logError:@"[hs.speededitor] The Speed Editor did not accept the challenge response, so aborting authentication."];
        return;
    }
        
    //
    // Get the timeout (in seconds) from the response:
    //
    uint32_t timeout = challengeResponseThreeBytes[2] + (challengeResponseThreeBytes[3] << 8) + (challengeResponseThreeBytes[4] << 16);
    if (!timeout) {
        [LuaSkin logError:@"[hs.speededitor] The Speed Editor did not get an authentication timeout, so aborting authentication."];
        return;
    }
    [self createAuthenticationTimerWithIntervalInSeconds:timeout];
    
    //
    // Turn off all the LEDs if first time authenticating for a clean slate:
    //
    if (self.firstTimeAuthenticating) {
        [self turnOffAllLEDs];
        self.firstTimeAuthenticating = NO;
    }
    
}

//
// Destroy the Authentication Timer:
//
- (void)destoryAuthenticationTimer {
    if (self.authenticationTimer) {        
        if (self.authenticationTimer.isValid) {
            [self.authenticationTimer invalidate];
        }
        self.authenticationTimer = nil;
    }
}

//
// Create the Authentication Timer:
//
- (void)createAuthenticationTimerWithIntervalInSeconds:(uint32_t) timeout {
    [self destoryAuthenticationTimer];
    if (!timeout) {
        timeout = 600; // Default to 600 seconds
    }
    timeout--; // Let's remove a second, just to be safe.
    self.authenticationTimer = [NSTimer
                                timerWithTimeInterval:timeout
                                target:self
                                selector:@selector(authenticationTimerCallback:)
                                userInfo:nil
                                repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.authenticationTimer forMode:NSRunLoopCommonModes];
}

//
// Authentication Timer Callback:
//
- (void)authenticationTimerCallback:(NSTimer *)timer {
    [self authenticate];
}

//
// Invalidate the Speed Editor object:
//
- (void)invalidate {
    self.isValid = NO;
    [self destoryAuthenticationTimer];
    
    // Reset the caches:
    self.buttonStateCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultButtonState];
    self.ledCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultLEDCache];
}

//
// Write feature report to the Speed Editor:
//
- (IOReturn)deviceWriteFeatureReportWithData:(NSData *)report {
    const uint8_t *rawBytes = (const uint8_t*)report.bytes;
    return IOHIDDeviceSetReport(self.device, kIOHIDReportTypeFeature, rawBytes[0], rawBytes, report.length);
}

//
// Write output report to the Speed Editor:
//
- (IOReturn)deviceWriteOutputReportWithData:(NSData *)report {
    const uint8_t *rawBytes = (const uint8_t*)report.bytes;
    return IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput, rawBytes[0], rawBytes, report.length);
}

//
// Read data from the Speed Editor:
//
- (NSData *)deviceReadWithLength:(int)resultLength reportID:(CFIndex)reportID {
    CFIndex reportLength = resultLength;
    uint8_t *report = malloc(reportLength);

    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, reportID, report, &reportLength);
    NSData *data = [NSData dataWithBytes:report length:reportLength];
    free(report);
    
    return data;
}

//
// Set main button LEDs (everything except the Jog Wheel buttons):
//
- (void)setLEDs:(NSDictionary*) options {
    // Report ID: 2
    // (little-endian) unsigned char, unsigned int

    __block unsigned int ledStatus = 0;
    __block BOOL shouldSendReport = NO;
    
    [self.ledLookup enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([options objectForKey:key]) {
            // We've been requested to turn on the LED:
            shouldSendReport = YES;
            NSNumber *enabled = [options valueForKey:key];
            if ([enabled intValue] == 1) {
                NSNumber *lookupValue = [self.ledLookup objectForKey:key];
                ledStatus = ledStatus + [lookupValue intValue];
                self.ledCache[key] = @YES;
            } else {
                self.ledCache[key] = @NO;
            }
        } else {
            // Use the cached value:
            if ([self.ledCache[key] isEqual:@YES]) {
                NSNumber *lookupValue = [self.ledLookup objectForKey:key];
                ledStatus = ledStatus + [lookupValue intValue];
            }
        }
    }];
    
    if (shouldSendReport) {
        uint8_t sendChallenge[] = {2};
        NSMutableData *reportA = [NSMutableData dataWithBytes:(const void *)sendChallenge length:1];
        NSMutableData *reportB = [NSMutableData dataWithBytes:&ledStatus length:4];
        [reportA appendData:reportB];
        
        IOReturn result = [self deviceWriteOutputReportWithData:reportA];
        if (result != kIOReturnSuccess) {
            [LuaSkin logError:@"[hs.speededitor] Failed to send LED report."];
            return;
        }
    }
}

//
// Set the three jog wheel LEDs:
//
- (void)setJogLEDs:(NSDictionary*) options {
    // Report ID: 4
    // (little-endian) unsigned char, unsigned char

    __block unsigned char ledStatus = 0;
    __block BOOL shouldSendReport = NO;
    
    [options enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([self.jogLEDLookup objectForKey:key]) {
            shouldSendReport = YES;
            NSNumber *enabled = obj;
            if ([enabled intValue] == 1) {
                NSNumber *lookupValue = [self.jogLEDLookup objectForKey:key];
                ledStatus = ledStatus + [lookupValue intValue];
            }
        }
    }];
    
    if (shouldSendReport) {
        uint8_t sendChallenge[] = {4, ledStatus};
        NSData *report = [NSData dataWithBytes:(const void *)sendChallenge length:2];
        IOReturn result = [self deviceWriteOutputReportWithData:report];
        if (result != kIOReturnSuccess) {
            [LuaSkin logError:@"[hs.speededitor] Failed to send Jog LED report."];
            return;
        }
    }
}

//
// Turn all the LEDs off:
//
- (void)turnOffAllLEDs {
    NSDictionary *allOff = @{
        @"CLOSE UP":                @NO,
        @"CUT":                     @NO,
        @"DIS":                     @NO,
        @"SMTH CUT":                @NO,
        @"TRANS":                   @NO,
        @"SNAP":                    @NO,
        @"CAM7":                    @NO,
        @"CAM8":                    @NO,
        @"CAM9":                    @NO,
        @"LIVE OWR":                @NO,
        @"CAM4":                    @NO,
        @"CAM5":                    @NO,
        @"CAM6":                    @NO,
        @"VIDEO ONLY":              @NO,
        @"CAM1":                    @NO,
        @"CAM2":                    @NO,
        @"CAM3":                    @NO,
        @"AUDIO ONLY":              @NO,
        @"JOG":                     @NO,
        @"SHTL":                    @NO,
        @"SCRL":                    @NO,
    };
    
    [self setLEDs:allOff];
    [self setJogLEDs:allOff];
}

- (void)setJogMode {
    // Report ID: 3
    // (little-endian) unsigned char, unsigned char, unsigned int, unsigned char
    // 3, jogmode, 0, 255
    
    // TODO: Need to add method to set the jog mode.
}

//
// Triggered when the Jog Wheel is turned:
//
- (void)deviceJogWheelUpdateWithMode:(NSNumber*)mode value:(NSNumber*)value {
    
    if (!self.isValid) {
        return;
    }

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    if (self.callbackRef == LUA_NOREF || self.callbackRef == LUA_REFNIL) {
        [skin logError:@"hs.speededitor received a jog wheel input, but no callback has been set. See hs.speededitor:callback()"];
        return;
    }

    // TODO: This should be taken from self.jogModeLookup instead.
    NSDictionary *modes = @{
        [NSNumber numberWithInt:0]: @"RELATIVE 0",              // Relative
        [NSNumber numberWithInt:1]: @"ABSOLUTE CONTINUOUS",     // Send an "absolute" position (based on the position when mode was set) -4096 -> 4096 range ~ half a turn
        [NSNumber numberWithInt:2]: @"RELATIVE 2",              // Same as mode 0 ?
        [NSNumber numberWithInt:3]: @"ABSOLUTE DEADZERO",       // Same as mode 1 but with a small dead band around zero that maps to 0
    };
    
    NSString *currentMode = modes[mode];
    
    //
    // Trigger Lua Callback:
    //
    [skin pushLuaRef:speedEditorRefTable ref:self.callbackRef];
    [skin pushNSObject:self];
    [skin pushNSObject:@"JOG_WHEEL"];
    lua_pushboolean(skin.L, 1);
    [skin pushNSObject:currentMode];
    [skin pushNSObject:value];
    [skin protectedCallAndError:@"hs.speededitor:callback" nargs:5 nresults:0];
    
    _lua_stackguard_exit(skin.L);
}

//
// Triggered when a button is pressed or released:
//
- (void)deviceButtonUpdate:(NSMutableDictionary*)currentButtonState {
    
    if (!self.isValid) {
        return;
    }

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    if (self.callbackRef == LUA_NOREF || self.callbackRef == LUA_REFNIL) {
        [skin logError:@"hs.speededitor received a button input, but no callback has been set. See hs.speededitor:callback()"];
        return;
    }

    NSArray *allKeys = [self.buttonLookup allKeys];
    for (NSString *currentKey in allKeys) {
        NSNumber *beforeButtonState = [self.buttonStateCache valueForKeyPath:currentKey];
        NSNumber *afterButtonState = [currentButtonState valueForKeyPath:currentKey];
        if ([beforeButtonState isEqual:@NO] && [afterButtonState isEqual:@YES]) {
            //
            // Button Pushed:
            //
            [self.buttonStateCache setObject:@YES forKey:currentKey];
                        
            //
            // Trigger Lua Callback:
            //
            [skin pushLuaRef:speedEditorRefTable ref:self.callbackRef];
            [skin pushNSObject:self];
            [skin pushNSObject:currentKey];
            lua_pushboolean(skin.L, 1);
            [skin protectedCallAndError:@"hs.speededitor:callback" nargs:3 nresults:0];
        }
        else if ([beforeButtonState isEqual:@YES] && [afterButtonState isEqual:@NO]) {
            //
            // Button Released:
            //
            [self.buttonStateCache setObject:@NO forKey:currentKey];
                        
            //
            // Trigger Lua Callback:
            //
            [skin pushLuaRef:speedEditorRefTable ref:self.callbackRef];
            [skin pushNSObject:self];
            [skin pushNSObject:currentKey];
            lua_pushboolean(skin.L, 0);
            [skin protectedCallAndError:@"hs.speededitor:callback" nargs:3 nresults:0];
        }
    }
    
    _lua_stackguard_exit(skin.L);
}
    
@end
