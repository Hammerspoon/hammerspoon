// Import the Lua API so we can do Lua things here
#import <LuaSkin/LuaSkin.h>

#ifndef HS_EXTERNAL_MODULE
// Import the Crashlytics API so we can define our own crashlog+NSLog call
#import <Crashlytics/Crashlytics.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
#define CLS_NSLOG(__FORMAT__, ...) CLSNSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#pragma clang diagnostic pop
#ifdef CLS_LOG
#undef CLS_LOG
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
#define CLS_LOG(__FORMAT__, ...) CLSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#pragma clang diagnostic pop
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


// Do not use.  Instead make sure your module requires "hs.image" and then use:
//
//    NSImage *theImage = [[LuaSkin shared] luaObjectAtIndex:idx toClass:"NSImage"] ;
//  and
//    [[LuaSkin shared] pushNSObject:theImage] ;

// #define IMAGE_USERDATA_TAG "hs.image"
//
// NSImage *get_image_from_hsimage(lua_State* L, int idx) {
//     // make sure hs.image has been loaded...
//     lua_getglobal(L, "require"); lua_pushstring(L, IMAGE_USERDATA_TAG); lua_call(L, 1, 1); lua_pop(L, 1) ;
//
//     void **thingy = luaL_checkudata(L, idx, IMAGE_USERDATA_TAG) ;
//     return (__bridge NSImage *) *thingy ;
// }
//
// int store_image_as_hsimage(lua_State* L, NSImage* theImage) {
//     // make sure hs.image has been loaded...
//     lua_getglobal(L, "require"); lua_pushstring(L, IMAGE_USERDATA_TAG); lua_call(L, 1, 1); lua_pop(L, 1) ;
//
//     theImage.cacheMode = NSImageCacheNever ;
//
//     void** imagePtr = lua_newuserdata(L, sizeof(NSImage *));
//     *imagePtr = (__bridge_retained void *)theImage;
//
//     luaL_getmetatable(L, IMAGE_USERDATA_TAG);
//     lua_setmetatable(L, -2);
//
//     return 1 ;
// }

// Do not use.  Instead make sure your module requires "hs.drawing" (or more specifically,
// "hs.drawing.color") in its init.lua file and then use:
//
//    NSColor *theColor = [[LuaSkin shared] tableAtIndex:idx toClass:"NSColor"] ;
//
// NSColor *getColorWithDefaultFromStack(lua_State *L, int idx, NSColor *defaultColor) {
//     CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0 ;
//
//     switch (lua_type(L, idx)) {
//         case LUA_TTABLE:
//             if (lua_getfield(L, idx, "red") == LUA_TNUMBER)
//                 red = lua_tonumber(L, -1);
//             lua_pop(L, 1);
//
//             if (lua_getfield(L, idx, "green") == LUA_TNUMBER)
//                 green = lua_tonumber(L, -1);
//             lua_pop(L, 1);
//
//             if (lua_getfield(L, idx, "blue") == LUA_TNUMBER)
//                 blue = lua_tonumber(L, -1);
//             lua_pop(L, 1);
//
//             if (lua_getfield(L, idx, "alpha") == LUA_TNUMBER)
//                 alpha = lua_tonumber(L, -1);
//             lua_pop(L, 1);
//
//             break;
//         case LUA_TNIL:
//         case LUA_TNONE:
//             return defaultColor ;
//             break;
//         default:
//             CLS_NSLOG(@"ERROR: Unexpected type passed as a color: %d", lua_type(L, idx));
//             luaL_error(L, [[NSString stringWithFormat:@"Unexpected type passed as a color: %s", lua_typename(L, lua_type(L, idx))] UTF8String]) ;
//             return nil ;
//             break;
//     }
//
//     return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
// }
//
// NSColor *getColorFromStack(lua_State *L, int idx) {
//     return getColorWithDefaultFromStack(L, idx, [NSColor blackColor]) ;
// }


