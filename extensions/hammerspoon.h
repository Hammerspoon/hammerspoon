// Import the Lua API so we can do Lua things here
#import <lauxlib.h>

// Import the Crashlytics API so we can define our own crashlog+NSLog call
#import "../Crashlytics.framework/Headers/Crashlytics.h"
#define CLS_NSLOG(__FORMAT__, ...) CLSNSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

// Define some useful utility functions

// Generic Lua-stack-C-string to NSString converter
#define lua_to_nsstring(L, idx) [NSString stringWithUTF8String:luaL_checkstring(L, idx)]

// Print a C string to the Hammerspoon console window and NSLog and Crashlytics logs
void printToConsole(lua_State *L, char *message) {
    lua_getglobal(L, "print");
    lua_pushstring(L, message);
    lua_call(L, 1, 0);
    return;
}
