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
        
        self.ledLookup = @{
            @"CLOSE_UP":        @(1 <<  0),
            @"CUT":             @(1 <<  1),
            @"DIS":             @(1 <<  2),
            @"SMTH_CUT":        @(1 <<  3),
            @"TRANS":           @(1 <<  4),
            @"SNAP":            @(1 <<  5),
            @"CAM7":            @(1 <<  6),
            @"CAM8":            @(1 <<  7),
            @"CAM9":            @(1 <<  8),
            @"LIVE_OWR":        @(1 <<  9),
            @"CAM4":            @(1 << 10),
            @"CAM5":            @(1 << 11),
            @"CAM6":            @(1 << 12),
            @"VIDEO_ONLY":      @(1 << 13),
            @"CAM1":            @(1 << 14),
            @"CAM2":            @(1 << 15),
            @"CAM3":            @(1 << 16),
            @"AUDIO_ONLY":      @(1 << 17),
        };
        
        self.buttonLookup = @{
            @"SMART_INSRT":     @0x01,
            @"APPND":           @0x02,
            @"RIPL_OWR":        @0x03,
            @"CLOSE_UP":        @0x04,
            @"PLACE_ON_TOP":    @0x05,
            @"SRC_OWR":         @0x06,
            @"IN":              @0x07,
            @"OUT":             @0x08,
            @"TRIM_IN":         @0x09,
            @"TRIM_OUT":        @0x0a,
            @"ROLL":            @0x0b,
            @"SLIP_SRC":        @0x0c,
            @"SLIP_DEST":       @0x0d,
            @"TRANS_DUR":       @0x0e,
            @"CUT":             @0x0f,
            @"DIS":             @0x10,
            @"SMTH_CUT":        @0x11,
            @"SOURCE":          @0x1a,
            @"TIMELINE":        @0x1b,
            @"SHTL":            @0x1c,
            @"JOG":             @0x1d,
            @"SCRL":            @0x1e,
            @"ESC":             @0x31,
            @"SYNC_BIN":        @0x1f,
            @"AUDIO_LEVEL":     @0x2c,
            @"FULL_VIEW":       @0x2d,
            @"TRANS":           @0x22,
            @"SPLIT":           @0x2f,
            @"SNAP":            @0x2e,
            @"RIPL_DEL":        @0x2b,
            @"CAM1":            @0x33,
            @"CAM2":            @0x34,
            @"CAM3":            @0x35,
            @"CAM4":            @0x36,
            @"CAM5":            @0x37,
            @"CAM6":            @0x38,
            @"CAM7":            @0x39,
            @"CAM8":            @0x3a,
            @"CAM9":            @0x3b,
            @"LIVE_OWR":        @0x30,
            @"VIDEO_ONLY":      @0x25,
            @"AUDIO_ONLY":      @0x26,
            @"STOP_PLAY":       @0x3c
        };
        
        self.defaultButtonState = @{
            @"SMART_INSRT":     @NO,
            @"APPND":           @NO,
            @"RIPL_OWR":        @NO,
            @"CLOSE_UP":        @NO,
            @"PLACE_ON_TOP":    @NO,
            @"SRC_OWR":         @NO,
            @"IN":              @NO,
            @"OUT": @NO,
            @"TRIM_IN": @NO,
            @"TRIM_OUT": @NO,
            @"ROLL": @NO,
            @"SLIP_SRC": @NO,
            @"SLIP_DEST": @NO,
            @"TRANS_DUR": @NO,
            @"CUT": @NO,
            @"DIS": @NO,
            @"SMTH_CUT": @NO,
            @"SOURCE": @NO,
            @"TIMELINE": @NO,
            @"SHTL": @NO,
            @"JOG": @NO,
            @"SCRL": @NO,
            @"ESC": @NO,
            @"SYNC_BIN": @NO,
            @"AUDIO_LEVEL": @NO,
            @"FULL_VIEW": @NO,
            @"TRANS": @NO,
            @"SPLIT": @NO,
            @"SNAP": @NO,
            @"RIPL_DEL": @NO,
            @"CAM1": @NO,
            @"CAM2": @NO,
            @"CAM3": @NO,
            @"CAM4": @NO,
            @"CAM5": @NO,
            @"CAM6": @NO,
            @"CAM7": @NO,
            @"CAM8": @NO,
            @"CAM9": @NO,
            @"LIVE_OWR": @NO,
            @"VIDEO_ONLY": @NO,
            @"AUDIO_ONLY": @NO,
            @"STOP_PLAY": @NO,
        };
        
        self.buttonStateCache = [NSMutableDictionary dictionaryWithDictionary:self.defaultButtonState];

        NSLog(@"Added new Speed Editor device %p with IOKit device %p from manager %p", (__bridge void *)self, (void*)self.device, (__bridge void *)self.manager);
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
 
// Rotate the 64 bits 8 spaces to the left (or, rotate the 8 bytes 1 byte to the left)
uint64_t rol8(uint64_t v){
    return ((v << 56) | (v >> 8));
}
 
// Rotate left n times
uint64_t rol8n(uint64_t v, uint8_t n){
    for (int i = 0; i < n; i++){
        v = rol8(v);
    }
    return v;
}
 
uint64_t bmd_kbd_auth(uint64_t challenge){
    // Mask off lower three bits, use as iteration count
    uint8_t n = challenge & 7;
 
    // Rotate challenge n times
    uint64_t v = rol8n(challenge, n);
    
    uint64_t k;
    
    // Even parity of v[bit0] and (0x78 >> n)
    if ( (v & 1) == ((0x78 >> n) & 1) ){
        k = auth_even[n];
    }
    // Odd parity, xor with self rotated one last time
    else {
        v = v ^ rol8(v);
        k = auth_odd[n];
    }
 
    // Return v xored with (self rol8 bitmasked with mask) xored with k
    return v ^ (rol8(v) & mask) ^ k;
}

- (void) authenticate {
    //
    // The authentication is performed over SET_FEATURE/GET_FEATURE on Report ID 6.
    //
    
    //
    // Reset the authentication state machine:
    //
    uint8_t resetAuthState[] = {0x06,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    NSData *resetAuthStateData = [NSData dataWithBytes:(const void *)resetAuthState length:10];
    [self deviceWriteWithData:resetAuthStateData];
    
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
        NSLog(@"[hs.speededitor] Unexpected response from Speed Editor.");
        return;
    }
    
    //
    // Send our challenge to authenticate the keyboard:
    //
    uint8_t sendChallenge[] = {0x06,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    NSData *sendChallengeData = [NSData dataWithBytes:(const void *)sendChallenge length:10];
    [self deviceWriteWithData:sendChallengeData];
    
    //
    // Read the keyboard response:
    //
    NSData *challengeResponseTwo = [self deviceReadWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseTwoBytes = (const char*)[challengeResponseTwo bytes];
    if (challengeResponseTwoBytes[0] != 0x06 && challengeResponseTwoBytes[1] != 0x02) {
        NSLog(@"[hs.speededitor] Unexpected response from Speed Editor when sending challenge.");
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
    [self deviceWriteWithData:authResponse];
    
    //
    // Read the Speed Editor status:
    //
    NSData *challengeResponseThree = [self deviceReadWithLength:10 reportID:6];
    
    //
    // Validate the response:
    //
    const char* challengeResponseThreeBytes = (const char*)[challengeResponseThree bytes];
    if (challengeResponseThreeBytes[0] != 0x06 && challengeResponseThreeBytes[1] != 0x04) {
        NSLog(@"[hs.speededitor] The Speed Editor did not accept the challenge response.");
        return;
    }
    
    //
    // Get the timeout from the response:
    //
    
    /*
    # I "think" what gets returned here is the timeout after which auth
    # needs to be done again (returns 600 for me which is plausible)
    return int.from_bytes(data[2:4], 'little')
    */
    
    /*
    NSMutableData *timeout = [NSMutableData dataWithData:challengeResponseThree];
    [timeout replaceBytesInRange:NSMakeRange(0, 2) withBytes:NULL length:0];
    
    
    char timeoutBuffer[3];
    [challengeResponseThree getBytes:timeoutBuffer range:NSMakeRange(2, 3)];

    int i;
    sscanf(timeoutBuffer, "%d", &i);
    
    NSLog(@"timeout: %d", i); // 404005264 432657488
     
    */
}

- (void)invalidate {
    self.isValid = NO;
}

//
// Write data to the Speed Editor:
//
- (IOReturn)deviceWriteWithData:(NSData *)report {
    const uint8_t *rawBytes = (const uint8_t*)report.bytes;
    return IOHIDDeviceSetReport(self.device, kIOHIDReportTypeFeature, rawBytes[0], rawBytes, report.length);
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

    NSDictionary *modes = @{
        [NSNumber numberWithInt:0]: @"RELATIVE_0",              // Relative
        [NSNumber numberWithInt:1]: @"ABSOLUTE_CONTINUOUS",     // Send an "absolute" position (based on the position when mode was set) -4096 -> 4096 range ~ half a turn
        [NSNumber numberWithInt:2]: @"RELATIVE_2",              // Same as mode 0 ?
        [NSNumber numberWithInt:3]: @"ABSOLUTE_DEADZERO",       // Same as mode 1 but with a small dead band around zero that maps to 0
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
