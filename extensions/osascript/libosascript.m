@import OSAKit;
#import <LuaSkin/LuaSkin.h>
#import "NSAppleEventDescriptor+Parsing.h"

/// hs.osascript._osascript(source, language) -> bool, object, descriptor
/// Function
/// Runs osascript code
///
/// Parameters:
///  * source - Some osascript code to execute
///  * language - A string containing the OSA language, either 'AppleScript' or 'JavaScript'. Defaults to AppleScript if invalid language
///
/// Returns:
///  * A boolean value indicating whether the code succeeded or not
///  * An object containing the parsed output that can be any type, or nil if unsuccessful
///  * A string containing the raw output of the code and/or its errors
static int runosascript(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    NSString* source = [skin toNSObjectAtIndex:1];
    NSString* language = [skin toNSObjectAtIndex:2];

    OSAScript *osa = [[OSAScript alloc] initWithSource:source language:[OSALanguage languageForName:language]];
    NSDictionary *__autoreleasing compileError;
    [osa compileAndReturnError:&compileError];

    if (compileError) {
        lua_pushboolean(skin.L, NO);
        lua_pushnil(skin.L);
        [skin pushNSObject:[NSString stringWithFormat:@"%@", compileError]];
        [skin logError:[NSString stringWithFormat:@"Unable to initialize script: %@", compileError]];
        return 3;
    }

    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [osa executeAndReturnError:&error];
    BOOL didSucceed = (result != nil);

    lua_pushboolean(skin.L, didSucceed);
    [skin pushNSObject:didSucceed ? [result objectValue] : [NSNull null]];
    [skin pushNSObject:[NSString stringWithFormat:@"%@", didSucceed ? result : error]];
    return 3;
}

static const luaL_Reg scriptlib[] = {
    {"_osascript", runosascript},
    {NULL, NULL}
};

int luaopen_hs_libosascript(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.osascript" functions:scriptlib metaFunctions:nil];

    return 1;
}
