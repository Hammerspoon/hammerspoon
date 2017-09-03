//
//  HSAppleScript.m
//  Hammerspoon
//
//  Created by Chris Hocking on 5/4/17.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSAppleScript.h"
#import "MJLua.h"
#import "variables.h"
#import "MJConsoleWindowController.h"
#import "MJPreferencesWindowController.h"
#import "MJDockIcon.h"

//
// Run String:
//
static LuaSkin* MJLuaState;
static int evalfn;
int asRefTable;

static int applescript_cleanUTF8(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    [skin pushNSObject:[skin getValidUTF8AtIndex:1]] ;
    return 1 ;
}

NSString* HSAppleScriptRunString(NSString* command) {
    lua_State* L = MJLuaState.L;
    
    [MJLuaState pushLuaRef:asRefTable ref:evalfn];
    if (!lua_isfunction(L, -1)) {
        HSNSLOG(@"ERROR: MJLuaRunString doesn't seem to have an evalfn");
        if (lua_isstring(L, -1)) {
            HSNSLOG(@"evalfn appears to be a string: %s", lua_tostring(L, -1));
        }
        return @"";
    }
    lua_pushstring(L, [command UTF8String]);
    if ([MJLuaState protectedCallAndTraceback:1 nresults:1] == NO) {
        const char *errorMsg = lua_tostring(L, -1);
        [MJLuaState logError:[NSString stringWithUTF8String:errorMsg]];
    }
    
    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    if (str == nil) {
        lua_pushcfunction(L, applescript_cleanUTF8) ;
        lua_pushvalue(L, -2) ;
        if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
            s = lua_tolstring(L, -1, &len);
            str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
            lua_pop(L, 1) ;
        } else {
            str = [[NSString alloc] initWithFormat:@"-- unable to clean for utf8 output: %s", lua_tostring(L, -1)] ;
            lua_pop(L, 1) ;
        }
    }
    lua_pop(L, 1);
    
    return str;
}

//
// Error Message:
//
NSString *appleScriptErrorMessage = @"Hammerspoon's AppleScript support is currently disabled. Please enable it in Hammerspoon by using the hs.allowAppleScript(true) command.";

//
// Enable & Disable AppleScript Support:
//
BOOL HSAppleScriptEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSAppleScriptEnabledKey];
}

void HSAppleScriptSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled
                                            forKey:HSAppleScriptEnabledKey];
}

//
// Execute Lua Code:
//
@implementation executeLua

-(id)performDefaultImplementation {

    // Get the arguments:
    NSDictionary *args = [self evaluatedArguments];
    NSString *stringToExecute = @"";
    if(args.count) {
        stringToExecute = [args valueForKey:@""];    // Get the direct argument
    } else {
        // Raise Error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:@"A Parameter is expected for the verb 'execute'. You need to tell Hammerspoon what Lua code you want to execute."];
        return @"Error";
    }

    if (HSAppleScriptEnabled()) {
        // Execute Lua Code:
        return HSAppleScriptRunString(stringToExecute);
    } else {
        // Raise Error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:appleScriptErrorMessage];
        return @"Error";
    }
}

@end
