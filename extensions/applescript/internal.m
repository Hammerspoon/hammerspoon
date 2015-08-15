#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

/// hs.applescript._applescript(string) -> bool, result
/// Function
/// Runs AppleScript code
///
/// Parameters:
///  * string - Some AppleScript code to execute
///
/// Returns:
///  * A boolean value indicating whether the code succeeded or not
///  * A string containing the output of the code and/or its errors
static int runapplescript(lua_State* L) {
    NSString* source = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    NSAppleScript* script = [[NSAppleScript alloc] initWithSource:source];
    if (script == nil) {
        showError(L, "Unable to create AppleScript - perhaps you have a syntax error?");
        lua_pushboolean(L, NO);
        lua_pushstring(L, "Unable to create AppleScript - perhaps you have a syntax error?");
        return 2;
    }

    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [script executeAndReturnError:&error];

    lua_pushboolean(L, (result != nil));
    if (result == nil) {
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", error] UTF8String]);
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", result] UTF8String]); // ugly, but parseable in Lua, sorta...
    }
    return 2;
}

static const luaL_Reg scriptlib[] = {
    {"_applescript", runapplescript},
    {NULL, NULL}
};

int luaopen_hs_applescript_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:scriptlib metaFunctions:nil];

    return 1;
}
