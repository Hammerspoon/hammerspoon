// Import the Lua API so we can do Lua things here
#import <LuaSkin/LuaSkin.h>

#ifndef HS_EXTERNAL_MODULE
// Import the Crashlytics API so we can define our own crashlog+NSLog call
#import "../Crashlytics.framework/Headers/Crashlytics.h"
#define CLS_NSLOG(__FORMAT__, ...) CLSNSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define CLS_NSLOG NSLog
#endif

// Define some useful utility functions

// Let extensions get the canonical lua_State object, for comparison with one they have stored already
extern lua_State* MJGetActiveLuaState();

// Generic Lua-stack-C-string to NSString converter
#define lua_to_nsstring(L, idx) [NSString stringWithUTF8String:luaL_checkstring(L, idx)]

// Print a C string to the Hammerspoon console window
void printToConsole(lua_State *L, char *message) {
    lua_getglobal(L, "print");
    lua_pushstring(L, message);
    lua_call(L, 1, 0);
    return;
}

// Print a C string to the Hammerspoon console as an error
void showError(lua_State *L, char *message) {
    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "showError");
    lua_remove(L, -2);
    lua_pushstring(L, message);
    lua_pcall(L, 1, 0, 0);
}


// For using hs.image to wrap images for hs.drawing

#define IMAGE_USERDATA_TAG "hs.image"

NSImage *get_image_from_hsimage(lua_State* L, int idx) {
    // make sure hs.image has been loaded...
    lua_getglobal(L, "require"); lua_pushstring(L, IMAGE_USERDATA_TAG); lua_call(L, 1, 1); lua_pop(L, 1) ;

    void **thingy = luaL_checkudata(L, idx, IMAGE_USERDATA_TAG) ;
    return (__bridge NSImage *) *thingy ;
}

int store_image_as_hsimage(lua_State* L, NSImage* theImage) {
    // make sure hs.image has been loaded...
    lua_getglobal(L, "require"); lua_pushstring(L, IMAGE_USERDATA_TAG); lua_call(L, 1, 1); lua_pop(L, 1) ;

    theImage.cacheMode = NSImageCacheNever ;

    void** imagePtr = lua_newuserdata(L, sizeof(NSImage *));
    *imagePtr = (__bridge_retained void *)theImage;

    luaL_getmetatable(L, IMAGE_USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1 ;
}
