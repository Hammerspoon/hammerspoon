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

NSString* HSAppleScriptRunString(executeLua *self, NSString* command) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    lua_State* L = skin.L;
    _lua_stackguard_entry(L);

    lua_getglobal(L, "hs") ;
    if (lua_getfield(L, -1, "__appleScriptRunString") != LUA_TFUNCTION) {
        [skin logError:[NSString stringWithFormat:@"hs.__appleScriptRunString is not a function; found %s", lua_typename(L, lua_type(L, -1))]] ;
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:@"hs.__appleScriptRunString is not a function"];
        lua_pop(L, 2) ; // "hs", and whatever "hs.__appleScriptRunString" is (could be nil)
        _lua_stackguard_exit(L);
        return @"Error";
    }

    lua_pushstring(L, [command UTF8String]);
    if ([skin protectedCallAndTraceback:1 nresults:2] == NO) {
        NSString *errMsg = [NSString stringWithFormat:@"hs.__apleScriptRunString callback error:%s", lua_tostring(L, -1)] ;
        [skin logError:errMsg];
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:errMsg];
        lua_pop(L, 2) ; // "hs", and error message
        _lua_stackguard_exit(L);
        return @"Error";
    }

    NSString *str = [skin toNSObjectAtIndex:-1] ; // modern LuaSkin forces a string to be UTF8 clean if we don't give it options
    BOOL     good = lua_toboolean(L, -2) ;
    lua_pop(L, 3) ; // "hs" and two results from hs.__apleScriptRunString: boolean, string
    if (good) {
        _lua_stackguard_exit(L);
        return str;
    } else {
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:str];
        _lua_stackguard_exit(L);
        return @"Error";
    }
    _lua_stackguard_exit(L);
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
        return HSAppleScriptRunString(self, stringToExecute);
    } else {
        // Raise Error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:appleScriptErrorMessage];
        return @"Error";
    }
}

@end
