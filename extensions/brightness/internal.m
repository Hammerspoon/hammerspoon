#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#import <LuaSkin/LuaSkin.h>
#import "math.h"

uint64_t LMUtoLux(uint64_t value) {
  //Conversion formula from regression.
  // -3*(10^-27)*x^4 + 2.6*(10^-19)*x^3 + -3.4*(10^-12)*x^2 + 3.9*(10^-5)*x - 0.19
  uint64_t x = value;
  uint64_t lux = (-3*pow(10, -27))*pow(x, 4) + (2.6*pow(10, -19))*pow(x, 3) - (3.4*pow(10,-12))*pow(x, 2) + (3.9*pow(10, -5))*x - 0.19;
  return lux;
}

/// hs.brightness.ambient() -> number
/// Function
/// Gets the current ambient brightness
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the current ambient brightness, measured in lux. If an error occurred, the number will be -1
///
/// Notes:
///  * Even though external Apple displays include an ambient light sensor, their data is typically not available, so this function will likely only be useful to MacBook users
///  * The raw sensor data is converted to lux via an algorithm used by Mozilla Firefox and is not guaranteed to give an accurate lux value
static int brightness_ambient(lua_State* L) {
    kern_return_t result;
    io_service_t serviceObject;
    io_connect_t dataPort = 0;
    uint32_t outputs = 2;
    uint64_t values[outputs];
    uint64_t lux = -1;

    serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"));
    if (!serviceObject) goto final;

    result = IOServiceOpen(serviceObject, mach_task_self(), 0, &dataPort);
    IOObjectRelease(serviceObject);
    if (result != KERN_SUCCESS) goto final;

    result = IOConnectCallMethod(dataPort, 0, nil, 0, nil, 0, values, &outputs, nil, 0);
    IOServiceClose(dataPort);
    if (result != KERN_SUCCESS) goto final;

    // Take the mean of the two sensor values (note that most modern MacBooks only have one sensor, so the values are identical)
    lux = LMUtoLux((values[0] + values[1])/2);

final:
    lua_pushinteger(L, lux);
    return 1;
}

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
    double level = MIN(MAX(luaL_checkinteger(L, 1) / 100.0, 0.0), 1.0);
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
            lua_pushinteger(L, level * 100.0);
            return 1;
        }
    }

    lua_pushnil(L);
    return 1;
}


static const luaL_Reg brightnessLib[] = {
    {"set", brightness_set},
    {"get", brightness_get},
    {"ambient", brightness_ambient},
    {NULL, NULL}
};

int luaopen_hs_brightness_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:brightnessLib metaFunctions:nil];

    return 1;
}
