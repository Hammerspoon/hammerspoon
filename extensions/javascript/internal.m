#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// Check out NSScriptClassDescription for expanding obj return values...

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
    NSString* source = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    // create temp file for osacompile
    NSString* tmpdir = @"/tmp";
    NSString* templateStr = [NSString stringWithFormat:@"%@/osacompile-XXXXXX", tmpdir];
    char template[templateStr.length + 1];
    strcpy(template, [templateStr cStringUsingEncoding:NSASCIIStringEncoding]);
        
    char* filenameC = mktemp(template);
    if (filenameC == NULL) {
        NSLog(@"Could not create file in directory %@", tmpdir);
        return 1;
    }

    NSString* filename = [NSString stringWithCString:filenameC encoding:NSASCIIStringEncoding];
    NSString* infile = [NSString stringWithFormat:@"%@.js", filename];
    NSString* outfile = [NSString stringWithFormat:@"%@.scpt", filename];

    // Write js source to file and call osascript which only works with files
    [source writeToFile:infile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/osacompile"];
    [task setArguments:@[ @"-l", @"JavaScript", @"-o", outfile, infile ]];
    [task launch];
    [task waitUntilExit];

    NSURL *compiledScriptPath = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", outfile]];
    NSAppleScript* script = [[NSAppleScript alloc] initWithContentsOfURL:compiledScriptPath error:nil];

    if (script == nil) {
        showError(L, "Unable to initialize script - perhaps you have a syntax error?");
        lua_pushboolean(L, NO);
        lua_pushstring(L, "Unable to initialize script - perhaps you have a syntax error?");
        return 2;
    }

    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [script executeAndReturnError:&error];

    lua_pushboolean(L, (result != nil));
    if (result == nil)
//         mjolnir_push_luavalue_for_nsobject(L, (NSArray *)error); // I don't think this ever worked, but it is what was in Hydra
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", error] UTF8String]);
    else {
//         lua_pushstring(L, [[result stringValue] UTF8String]); // worked only for string results...
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", result] UTF8String]); // ugly, but parseable in Lua, sorta...
//         mjolnir_push_luavalue_for_nsobject(L, arrayFromDescriptor(result)); // my pipe dream, but not yet...
    }
    return 2;
}

static const luaL_Reg scriptlib[] = {
    {"_javascript", runjavascript},
    {NULL, NULL}
};

int luaopen_hs_javascript_internal(lua_State* L) {
    luaL_newlib(L, scriptlib);

    return 1;
}
