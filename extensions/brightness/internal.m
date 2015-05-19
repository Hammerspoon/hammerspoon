#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#import <lua/lauxlib.h>
#import "math.h"

/// hs.brightness.set(brightness) -> boolean
/// Function
/// Sets the display brightness
///
/// Parameters:
///  * brightness - A number between 0 and 100
///
/// Returns:
///  * True if the brightness was set, false if not
static int brightness_set(lua_State* L) {
    double level = MIN(MAX(luaL_checknumber(L, 1) / 100.0, 0.0), 1.0);
    bool found = false;
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                        IOServiceMatching("IODisplayConnect"),
                                                        &iterator);

    if (result == kIOReturnSuccess)
    {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), level);

            IOObjectRelease(service);
            found = true;
        }
    }
    lua_pushboolean(L, found);
    return 1;
}


/// hs.brightness.get() -> number
/// Function
/// Returns the current brightness of the display
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the brightness of the display, between 0 and 100
static int brightness_get(lua_State *L) {
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                        IOServiceMatching("IODisplayConnect"),
                                                        &iterator);

    if (result == kIOReturnSuccess)
    {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            float level;
            IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &level);

            IOObjectRelease(service);
            lua_pushnumber(L, level * 100.0);
            return 1;
        }
    }

    lua_pushnil(L);
    return 1;
}


static const luaL_Reg brightnessLib[] = {
    {"set", brightness_set},
    {"get", brightness_get},
    {NULL, NULL}
};

int luaopen_hs_brightness_internal(lua_State* L) {
    luaL_newlib(L, brightnessLib);
    return 1;
}
