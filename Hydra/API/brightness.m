#import "helpers.h"
#include "math.h"

/// === brightness ===
///
/// Functions for manipulating display brightness.



/// brightness.set(number) -> boolean
/// Sets the display brightness. Number should be between 0 and 100.
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


/// brightness.get() -> number
/// Returns the current brightness of the display.
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


static const luaL_Reg mouselib[] = {
    {"set", &brightness_set},
    {"get", &brightness_get},
    {NULL, NULL}
};

int luaopen_brightness(lua_State* L) {
    luaL_newlib(L, mouselib);
    return 1;
}
