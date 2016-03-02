@import OSAKit;
#import <LuaSkin/LuaSkin.h>
#import "NSAppleEventDescriptor+Parsing.h"

/// hs.osascript._osascript(source, language) -> bool, result, object
/// Function
/// Runs osascript code
///
/// Parameters:
///  * source - Some osascript code to execute
///  * language - A string containing the OSA language, either 'AppleScript' or 'JavaScript'. Defaults to AppleScript if invalid language
///
/// Returns:
///  * A boolean value indicating whether the code succeeded or not
///  * A string containing the output of the code and/or its errors
///  * An object containing the parsed output that can be any type, or nil if unsuccessful
static int runosascript(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];
    
    NSString* source = [skin toNSObjectAtIndex:1];
    NSString* language = [skin toNSObjectAtIndex:2];
    
    OSAScript *osa = [[OSAScript alloc] initWithSource:source language:[OSALanguage languageForName:language]];
    NSDictionary *__autoreleasing compileError;
    [osa compileAndReturnError:&compileError];
    
    if (compileError) {
        const char *compileErrorMessage = "Unable to initialize script - perhaps you have a syntax error?";
        [skin logError:[NSString stringWithUTF8String:compileErrorMessage]];
        lua_pushboolean(L, NO);
        lua_pushstring(L, compileErrorMessage);
        lua_pushnil(L);
        return 3;
    }

    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [osa executeAndReturnError:&error];
    BOOL didSucceed = (result != nil);

    lua_pushboolean(L, didSucceed);
    [skin pushNSObject:[NSString stringWithFormat:@"%@", didSucceed ? result : error]];
    [skin pushNSObject:didSucceed ? [result objectValue] : [NSNull null]];
    return 3;
}

static const luaL_Reg scriptlib[] = {
    {"_osascript", runosascript},
    {NULL, NULL}
};

int luaopen_hs_osascript_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:scriptlib metaFunctions:nil];
    
    return 1;
}
