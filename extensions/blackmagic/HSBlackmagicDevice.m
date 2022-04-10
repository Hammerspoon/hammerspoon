#import "HSBlackmagicDevice.h"

#include <stdint.h>
#include <stdio.h>

@interface HSBlackmagicDevice ()
@end

@implementation HSBlackmagicDevice
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager serialNumber:serialNumber {
    self = [super init];
    if (self) {
        self.serialNumber = serialNumber;
        self.device = device;
        self.isValid = YES;
        self.manager = manager;
        self.callbackRef = LUA_NOREF;
        self.selfRefCount = 0;
        
        self.firstTimeAuthenticating = YES;
        
        self.batteryCharging = NO;
        self.batteryLevel = @-1;
          
        //
        // The default authentication timeout (which hopefully is never used, as the device should tell us):
        //
        self.defaultAuthenticationTimeout = 600;
        
        //
        // How long we should wait before we re-attempt authentication if it fails:
        //
        self.retryAuthenticationInSeconds = 5;
        
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
        [LuaSkin logError:@"[hs.blackmagic] Failed to send report to reset the authentication state machine, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }
    
    //
    // Read the keyboard challenge (for keyboard to authenticate app):
    //
    NSData *challengeResponse = [self deviceReadFeatureReportWithLength:10 reportID:6];
    NSMutableData *challenge = [NSMutableData dataWithData:challengeResponse];
    [challenge replaceBytesInRange:NSMakeRange(0, 2) withBytes:NULL length:0];
    
    //
    // Validate the response:
    //
    const char* challengeResponseBytes = (const char*)[challengeResponse bytes];
    if (challengeResponseBytes[0] != 0x06 && challengeResponseBytes[1] != 0x00) {
        [LuaSkin logError:@"[hs.blackmagic] Unexpected initial response from Speed Editor, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }
    
    //
    // Send our challenge to authenticate the keyboard:
    //
    uint8_t sendChallenge[] = {0x06,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    NSData *sendChallengeData = [NSData dataWithBytes:(const void *)sendChallenge length:10];
    result = [self deviceWriteFeatureReportWithData:sendChallengeData];
    if (result != kIOReturnSuccess) {
        [LuaSkin logError:@"[hs.blackmagic] Failed to send report with our challenge, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }
    
    //
    // Read the keyboard response:
    //
    NSData *challengeResponseTwo = [self deviceReadFeatureReportWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseTwoBytes = (const char*)[challengeResponseTwo bytes];
    if (challengeResponseTwoBytes[0] != 0x06 && challengeResponseTwoBytes[1] != 0x02) {
        [LuaSkin logError:@"[hs.blackmagic] Unexpected response from Speed Editor when sending challenge, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
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
        [LuaSkin logError:@"[hs.blackmagic] Failed to send report with our response to the challenge, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }

    //
    // Read the Speed Editor status:
    //
    NSData *challengeResponseThree = [self deviceReadFeatureReportWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseThreeBytes = (const char*)[challengeResponseThree bytes];
    if (challengeResponseThreeBytes[0] != 0x06 && challengeResponseThreeBytes[1] != 0x04) {
        [LuaSkin logError:@"[hs.blackmagic] The Speed Editor did not accept the challenge response, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }
        
    //
    // Get the timeout (in seconds) from the response:
    //
    uint32_t timeout = challengeResponseThreeBytes[2] + (challengeResponseThreeBytes[3] << 8) + (challengeResponseThreeBytes[4] << 16);
    if (!timeout) {
        [LuaSkin logError:@"[hs.blackmagic] The Speed Editor did not get an authentication timeout, so aborting authentication. We'll try again in 5sec."];
        
        //
        // Try again...
        //
        [self createAuthenticationTimerWithIntervalInSeconds:self.retryAuthenticationInSeconds];
        return;
    }
    [self createAuthenticationTimerWithIntervalInSeconds:timeout];
    
    //
    // If this is the first time connecting...
    //
    if (self.firstTimeAuthenticating) {
        //
        // Turn off all the LEDs:
        //
        [self turnOffAllLEDs];
        
        //
        // Set the Jog Mode to SHTL:
        //
        [self setJogMode:@"SHTL"];
        
        //
        // Only do this once:
        //
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
        timeout = self.defaultAuthenticationTimeout;
    }
    if (timeout >= 2) {
        timeout--; // Let's remove a second, just to be safe.
    }
    self.authenticationTimer = [NSTimer
                                timerWithTimeInterval:timeout
                                target:self
                                selector:@selector(authenticationTimerCallback:)
                                userInfo:nil
                                repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.authenticationTimer forMode:NSRunLoopCommonModes];
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
// Read Feature Report from the Speed Editor:
//
- (NSData *)deviceReadFeatureReportWithLength:(int)resultLength reportID:(CFIndex)reportID {
    CFIndex reportLength = resultLength;
    uint8_t *report = malloc(reportLength);

    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, reportID, report, &reportLength);
    NSData *data = [NSData dataWithBytes:report length:reportLength];
    free(report);
    
    return data;
}

//
// Read Input Report from the Speed Editor:
//
- (NSData *)deviceReadInputReportWithLength:(int)resultLength reportID:(CFIndex)reportID {
    CFIndex reportLength = resultLength;
    uint8_t *report = malloc(reportLength);

    IOHIDDeviceGetReport(self.device, kIOHIDReportTypeFeature, reportID, report, &reportLength);
    NSData *data = [NSData dataWithBytes:report length:reportLength];
    free(report);
    
    return data;
}

//
// Request the Battery Status:
//
- (void)getBatteryStatus {
    //
    // BATTERY STATUS:
    //
    // Report ID: 07
    // u8 - Report ID
    // u8 - Charging (1) / Not-charging (0)
    // u8 - Battery level (0-100)
    //
    
    int reportLength = 3;
    CFIndex reportID = 7;
    
    NSData *data = [self deviceReadInputReportWithLength:reportLength reportID:reportID];
    const char* dataAsBytes = (const char*)[data bytes];
    
    self.batteryCharging = dataAsBytes[1];
    self.batteryLevel = [NSNumber numberWithChar:dataAsBytes[2]];
}

//
// Set main button LEDs (everything except the Jog Wheel buttons):
//
- (void)setLEDs:(NSDictionary*) options {
    //
    // Report ID: 2
    // (little-endian) unsigned char, unsigned int
    //

    if ([options count] == 0) {
        // The supplied options are empty, so abort!
        return;
    }
    
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
            [LuaSkin logError:@"[hs.blackmagic] Failed to send LED report."];
            return;
        }
    }
}

//
// Set the three jog wheel LEDs:
//
- (void)setJogLEDs:(NSDictionary*) options {
    //
    // Report ID: 4
    // (little-endian) unsigned char, unsigned char
    //
    
    if ([options count] == 0) {
        // The supplied options are empty, so abort!
        return;
    }

    __block unsigned char ledStatus = 0;
    __block BOOL shouldSendReport = NO;
    
    [self.jogLEDLookup enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([options objectForKey:key]) {
            // We've been requested to turn on the LED:
            shouldSendReport = YES;
            NSNumber *enabled = [options valueForKey:key];
            if ([enabled intValue] == 1) {
                NSNumber *lookupValue = [self.jogLEDLookup objectForKey:key];
                ledStatus = ledStatus + [lookupValue intValue];
                self.ledCache[key] = @YES;
            } else {
                self.ledCache[key] = @NO;
            }
        } else {
            // Use the cached value:
            if ([self.ledCache[key] isEqual:@YES]) {
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
            [LuaSkin logError:@"[hs.blackmagic] Failed to send Jog LED report."];
            return;
        }
    }
}

//
// Turn all the LEDs off:
//
- (void)turnOffAllLEDs {
    [self setLEDs:self.defaultLEDCache];
    [self setJogLEDs:self.defaultLEDCache];
}

- (void)setJogMode:(NSString*) mode {
    //
    // Report ID: 3
    // (little-endian) unsigned char, unsigned char, unsigned int, unsigned char
    // 3, jogmode, 0, 255
    //
    
    unsigned char jogMode = [self.jogModeLookup[mode] unsignedCharValue];
    
    uint8_t sendChallenge[] = {3, jogMode, 0, 0, 0, 0, 255};
    NSData *report = [NSData dataWithBytes:(const void *)sendChallenge length:7];
    IOReturn result = [self deviceWriteOutputReportWithData:report];
    if (result != kIOReturnSuccess) {
        [LuaSkin logError:@"[hs.blackmagic] Failed to send Jog Mode report."];
        return;
    }
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
        [skin logError:@"hs.blackmagic received a jog wheel input, but no callback has been set. See hs.blackmagic:callback()"];
        return;
    }

    NSString *currentMode = self.jogModeReverseLookup[mode];
    
    //
    // Trigger Lua Callback:
    //
    [skin pushLuaRef:blackmagicRefTable ref:self.callbackRef];
    [skin pushNSObject:self];
    [skin pushNSObject:@"JOG WHEEL"];
    lua_pushboolean(skin.L, 1);
    [skin pushNSObject:currentMode];
    [skin pushNSObject:value];
    [skin protectedCallAndError:@"hs.blackmagic:callback" nargs:5 nresults:0];
    
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
        [skin logError:@"hs.blackmagic received a button input, but no callback has been set. See hs.blackmagic:callback()"];
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
            [skin pushLuaRef:blackmagicRefTable ref:self.callbackRef];
            [skin pushNSObject:self];
            [skin pushNSObject:currentKey];
            lua_pushboolean(skin.L, 1);
            [skin protectedCallAndError:@"hs.blackmagic:callback" nargs:3 nresults:0];
        }
        else if ([beforeButtonState isEqual:@YES] && [afterButtonState isEqual:@NO]) {
            //
            // Button Released:
            //
            [self.buttonStateCache setObject:@NO forKey:currentKey];
                        
            //
            // Trigger Lua Callback:
            //
            [skin pushLuaRef:blackmagicRefTable ref:self.callbackRef];
            [skin pushNSObject:self];
            [skin pushNSObject:currentKey];
            lua_pushboolean(skin.L, 0);
            [skin protectedCallAndError:@"hs.blackmagic:callback" nargs:3 nresults:0];
        }
    }
    
    _lua_stackguard_exit(skin.L);
}
    
@end
