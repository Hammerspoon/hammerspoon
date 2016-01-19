#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#import <OSAKit/OSAKit.h>

/// hs.javascript._javascript(string) -> bool, result
/// Function
/// Runs JavaScript OSA code
///
/// Parameters:
///  * string - Some JavaScript code to execute
///
/// Returns:
///  * A boolean value indicating whether the code succeeded or not
///  * A string containing the output of the code and/or its errors
static int runjavascript(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    
    NSString* source = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    // https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_11/Objective-C/OSAKit.html
    OSAScript *osa = [[OSAScript alloc] initWithSource:source language:[OSALanguage languageForName:@"JavaScript"]];
    NSDictionary *__autoreleasing compileError;
    [osa compileAndReturnError:&compileError];
    
    if (compileError) {
        [skin logError:@"hs.javascript._javascript() Unable to initialize script - perhaps you have a syntax error?"];
        lua_pushboolean(L, NO);
        lua_pushstring(L, "Unable to initialize script - perhaps you have a syntax error?");
        return 2;
    }
    
    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [osa executeAndReturnError:&error];
    BOOL didSucceed = (result != nil);
    
    lua_pushboolean(L, didSucceed);
    lua_pushstring(L, [[NSString stringWithFormat:@"%@", didSucceed ? result : error] UTF8String]);

    return 2;
}

static const luaL_Reg scriptlib[] = {
    {"_javascript", runjavascript},
    {NULL, NULL}
};

int luaopen_hs_javascript_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:scriptlib metaFunctions:nil];
    
    return 1;
}
