@import Cocoa;
@import LuaSkin;

#import "HSRazerManager.h"
#import "HSRazerDevice.h"
#import "razer.h"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSRazerManager *razerManager;
LSRefTable razerRefTable = LUA_NOREF;

#pragma mark - Lua API

static int razer_gc(lua_State *L __unused) {
    [razerManager stopHIDManager];
    [razerManager doGC];
    return 0;
}

#pragma mark - hs.razer: Common Functions

/// hs.razer.init(fn)
/// Function
/// Initialises the Razer driver and sets a discovery callback.
///
/// Parameters:
///  * fn - A function that will be called when a Razer device is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.razer object, being the device that was connected/disconnected
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used
static int razer_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    razerManager = [[HSRazerManager alloc] init];
    razerManager.discoveryCallbackRef = [skin luaRef:razerRefTable atIndex:1];
    [razerManager startHIDManager];

    return 0;
}

/// hs.razer.discoveryCallback(fn) -> none
/// Function
/// Sets/clears a callback for reacting to device discovery events
///
/// Parameters:
///  * fn - A function that will be called when a Razer device is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.razer object, being the device that was connected/disconnected
///
/// Returns:
///  * None
static int razer_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    if (!razerManager) {
        razerManager = [[HSRazerManager alloc] init];
    }
    razerManager.discoveryCallbackRef = [skin luaUnref:razerRefTable ref:razerManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        razerManager.discoveryCallbackRef = [skin luaRef:razerRefTable atIndex:1];
    }

    return 0;
}

/// hs.razer.numDevices() -> number
/// Function
/// Gets the number of Razer devices connected
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Razer devices attached to the system
static int razer_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, razerManager.devices.count);
    return 1;
}

/// hs.razer.getDevice(num) -> razerObject | nil
/// Function
/// Gets an hs.razer object for the specified device
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices
///
/// Returns:
///  * An hs.razer object or `nil` if something goes wrong
static int razer_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];

    unsigned long deviceNumber = lua_tointeger(skin.L, 1) - 1;

    if (deviceNumber > razerManager.devices.count) {
        lua_pushnil(L);
        return 1;
    }

    HSRazerDevice *razer = razerManager.devices[deviceNumber];

    if (razer) {
        [skin pushNSObject:razer];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

#pragma mark - hs.razer: Common Methods

/// hs.razer:name() -> string
/// Method
/// Returns the human readible device name of the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The device name as a string.
static int razer_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSString *name          = razer.name;

    [skin pushNSObject:name];
    return 1;
}

#pragma mark - hs.razer: Callback Methods

/// hs.razer:callback(callbackFn) -> razerObject
/// Method
/// Sets or removes a callback function for the `hs.razer` object.
///
/// Parameters:
///  * `callbackFn` - a function to set as the callback for this `hs.razer` object.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.razer` object
///
/// Notes:
///  * The callback function should expect 4 arguments and should not return anything:
///    * `razerObject` - The serial port object that triggered the callback.
///    * `buttonName` - The name of the button as a string.
///    * `buttonAction` - A string containing "pressed", "released", "up" or "down".
static int razer_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSRazerDevice *device = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    device.buttonCallbackRef = [skin luaUnref:razerRefTable ref:device.buttonCallbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.buttonCallbackRef = [skin luaRef:razerRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

#pragma mark - hs.razer: Private Methods

// hs.razer:_remapping() -> table
// Method
// Returns a table of the remapping data.
//
// Parameters:
//  * None
//
// Returns:
//  * A table of remapping data used by the `:keyboardDisableDefaults()` and `:keyboardEnableDefaults()` methods.
static int razer_remapping(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSDictionary *remapping = razer.remapping;

    [skin pushNSObject:remapping];
    return 1;
}

// hs.razer:_productID() -> number
// Method
// Returns the product ID of a `hs.razer` object.
//
// Parameters:
//  * None
//
// Returns:
//  * The product ID as a number.
static int razer_productID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSNumber *productID     = [NSNumber numberWithInt:razer.productID];

    [skin pushNSObject:productID];
    return 1;
}

#pragma mark - hs.razer: Brightness Methods

/// hs.razer:brightness(value) -> razerObject, number | nil, string | nil
/// Method
/// Gets or sets the brightness of a Razer keyboard.
///
/// Parameters:
///  * value - The brightness value - a number between 0 (off) and 100 (brightest).
///
/// Returns:
///  * The `hs.razer` object.
///  * The brightness as a number or `nil` if something goes wrong.
///  * A plain text error message if not successful.
static int razer_brightness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    if (lua_gettop(L) == 1) {
        // Getter:
        HSRazerResult *result = [razer getBrightness];
        if ([result success]) {
            lua_pushvalue(L, 1);
            [skin pushNSObject:[result brightness]];
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    else {
        // Setter:
        NSNumber *brightness = [skin toNSObjectAtIndex:2];

        if ([brightness intValue] < 0 || [brightness intValue] > 100) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, false);
            [skin pushNSObject:@"The brightness must be between 0 and 100."];
            return 3;
        }

        HSRazerResult *result = [razer setBrightness:brightness];
        if ([result success]){
            lua_pushvalue(L, 1);
            [skin pushNSObject:[result brightness]];
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    return 3;
}

#pragma mark - hs.razer: Status Light Methods

/// hs.razer:orangeStatusLight(value) -> razerObject, boolean | nil, string | nil
/// Method
/// Gets or sets the orange status light.
///
/// Parameters:
///  * value - `true` for on, `false` for off`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` for on, `false` for off`, or `nil` if something has gone wrong
///  * A plain text error message if not successful.
static int razer_orangeStatusLight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    if (lua_gettop(L) == 1) {
        // Getter:
        HSRazerResult *result = [razer getOrangeStatusLight];
        if ([result success]) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, [result orangeStatusLight]);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    else {
        // Setter:
        BOOL active = lua_toboolean(L, 2);

        HSRazerResult *result = [razer setOrangeStatusLight:active];
        if ([result success]){
            lua_pushvalue(L, 1);
            lua_pushboolean(L, active);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    return 3;
}

/// hs.razer:greenStatusLight(value) -> razerObject, boolean | nil, string | nil
/// Method
/// Gets or sets the green status light.
///
/// Parameters:
///  * value - `true` for on, `false` for off`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` for on, `false` for off`, or `nil` if something has gone wrong
///  * A plain text error message if not successful.
static int razer_greenStatusLight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    if (lua_gettop(L) == 1) {
        // Getter:
        HSRazerResult *result = [razer getGreenStatusLight];
        if ([result success]) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, [result greenStatusLight]);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    else {
        // Setter:
        BOOL active = lua_toboolean(L, 2);

        HSRazerResult *result = [razer setGreenStatusLight:active];
        if ([result success]){
            lua_pushvalue(L, 1);
            lua_pushboolean(L, active);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    return 3;
}

/// hs.razer:blueStatusLight(value) -> razerObject, boolean | nil, string | nil
/// Method
/// Gets or sets the blue status light.
///
/// Parameters:
///  * value - `true` for on, `false` for off`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` for on, `false` for off`, or `nil` if something has gone wrong
///  * A plain text error message if not successful.
static int razer_blueStatusLight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    if (lua_gettop(L) == 1) {
        // Getter:
        HSRazerResult *result = [razer getBlueStatusLight];
        if ([result success]) {
            lua_pushvalue(L, 1);
            lua_pushboolean(L, [result blueStatusLight]);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    else {
        // Setter:
        BOOL active = lua_toboolean(L, 2);

        HSRazerResult *result = [razer setBlueStatusLight:active];
        if ([result success]){
            lua_pushvalue(L, 1);
            lua_pushboolean(L, active);
            lua_pushnil(L);
        } else {
            lua_pushvalue(L, 1);
            lua_pushnil(L);
            [skin pushNSObject:[result errorMessage]];
        }
    }
    return 3;
}

#pragma mark - hs.razer: Backlights Methods

/// hs.razer:backlightsStatic(color) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to a single static color.
///
/// Parameters:
///  * color - A `hs.drawing.color` object.
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`.
///  * A plain text error message if not successful.
static int razer_backlightsStatic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSColor *color          = [skin luaObjectAtIndex:2 toClass:"NSColor"];

    HSRazerResult *result   = [razer setBacklightToStaticColor:color];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsOff() -> razerObject, boolean, string | nil
/// Method
/// Turns all the keyboard backlights off.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`.
///  * A plain text error message if not successful.
static int razer_backlightsOff(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    HSRazerResult *result   = [razer setBacklightToOff];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsWave(speed, direction) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to the wave mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 255 (slow)
///  * direction - "left" or "right" as a string
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
static int razer_backlightsWave(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TSTRING, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSNumber *speed         = [skin toNSObjectAtIndex:2];
    NSString *direction     = [skin toNSObjectAtIndex:3];

    if ([speed intValue] < 1 || [speed intValue] > 255) {
        lua_pushvalue(L, 1);
        lua_pushboolean(L, false);
        [skin pushNSObject:@"The speed must be between 1 and 255."];
        return 3;
    }

    if (![direction isEqualToString:@"left"] && ![direction isEqualToString:@"right"]) {
       lua_pushvalue(L, 1);
       lua_pushboolean(L, false);
       [skin pushNSObject:@"The direction must be 'left' or 'right'."];
       return 3;
    }

    HSRazerResult *result   = [razer setBacklightToWaveWithSpeed:speed direction:direction];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsSpectrum() -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to the spectrum mode.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
static int razer_backlightsSpectrum(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    HSRazerResult *result   = [razer setBacklightToSpectrum];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsReactive(speed, color) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to the reactive mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 4 (slow)
///  * color - A `hs.drawing.color` object
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
static int razer_backlightsReactive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TBREAK];

    HSRazerDevice *razer    = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSNumber *speed         = [skin toNSObjectAtIndex:2];
    NSColor *color          = [skin luaObjectAtIndex:3 toClass:"NSColor"];

    if ([speed intValue] < 1 || [speed intValue] > 4) {
        lua_pushvalue(L, 1);
        lua_pushboolean(L, false);
        [skin pushNSObject:@"The speed must be between 1 and 4."];
        return 3;
    }

    HSRazerResult *result = [razer setBacklightToReactiveWithColor:color speed:speed];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsStarlight(speed, [color], [secondaryColor]) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to the Starlight mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 3 (slow)
///  * [color] - An optional `hs.drawing.color` value
///  * [secondaryColor] - An optional secondary `hs.drawing.color`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
///
/// Notes:
///  * If neither `color` nor `secondaryColor` is provided, then random colors will be used.
static int razer_backlightsStarlight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSNumber *speed = [skin toNSObjectAtIndex:2];

    if ([speed intValue] < 1 || [speed intValue] > 3) {
        lua_pushvalue(L, 1);
        lua_pushboolean(L, false);
        [skin pushNSObject:@"The speed must be between 1 and 3."];
        return 3;
    }

    NSColor *color;
    NSColor *secondaryColor;

    if (lua_type(L, 3) == LUA_TTABLE) {
        color = [skin luaObjectAtIndex:3 toClass:"NSColor"];
    }

    if (lua_type(L, 4) == LUA_TTABLE) {
        secondaryColor = [skin luaObjectAtIndex:4 toClass:"NSColor"];
    }

    HSRazerResult *result = [razer setBacklightToStarlightWithColor:color secondaryColor:secondaryColor speed:speed];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsBreathing([color], [secondaryColor]) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to the breath mode.
///
/// Parameters:
///  * [color] - An optional `hs.drawing.color` value
///  * [secondaryColor] - An optional secondary `hs.drawing.color`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
///
/// Notes:
///  * If neither `color` nor `secondaryColor` is provided, then random colors will be used.
static int razer_backlightsBreathing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    NSColor *color;
    NSColor *secondaryColor;

    if (lua_type(L, 2) == LUA_TTABLE) {
        color = [skin luaObjectAtIndex:2 toClass:"NSColor"];
    }

    if (lua_type(L, 3) == LUA_TTABLE) {
        secondaryColor = [skin luaObjectAtIndex:3 toClass:"NSColor"];
    }

    HSRazerResult *result = [razer setBacklightToBreathingWithColor:color secondaryColor:secondaryColor];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

/// hs.razer:backlightsCustom(colors) -> razerObject, boolean, string | nil
/// Method
/// Changes the keyboard backlights to custom colours.
///
/// Parameters:
///  * colors - A table of `hs.drawing.color` objects for each individual button on your device (i.e. if there's 20 buttons, you should have twenty colors in the table).
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///  * A plain text error message if not successful.
///
/// Notes:
///  * The order is top to bottom, left to right. You can use `nil` for any buttons you don't want to light up.
///  * Example usage: ```lua
///   hs.razer.new(0):backlightsCustom({hs.drawing.color.red, nil, hs.drawing.color.green, hs.drawing.color.blue})
///   ```
static int razer_backlightsCustom(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];

    HSRazerDevice *razer = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];

    NSMutableDictionary *customColors = [NSMutableDictionary dictionary];

    lua_pushnil(L); // first key
    while (lua_next(L, 2) != 0) {
        customColors[@(lua_tonumber(L, -2))] = [skin luaObjectAtIndex:-1 toClass:"NSColor"];
        lua_pop(L, 1); // pop value but leave key on stack for `lua_next`
    }

    HSRazerResult *result = [razer setBacklightToCustomWithColors:customColors];

    lua_pushvalue(L, 1);
    lua_pushboolean(L, [result success]);
    [skin pushNSObject:[result errorMessage]];
    return 3;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSRazerDevice(lua_State *L, id obj) {
    HSRazerDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSRazerDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSRazerDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSRazerDevice *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSRazerDevice, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int razer_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSRazerDevice *obj = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
    NSString *title = [NSString stringWithFormat:@"%@", obj.name];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]];
    return 1;
}

static int razer_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSRazerDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSRazerDevice"];
        HSRazerDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSRazerDevice"];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

static int razer_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSRazerDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSRazerDevice, L, 1, USERDATA_TAG);
    if (theDevice) {
        theDevice.selfRefCount--;
        if (theDevice.selfRefCount == 0) {
            // Destroy the event tap:
            [theDevice destroyEventTap];

            theDevice.buttonCallbackRef = [skin luaUnref:razerRefTable ref:theDevice.buttonCallbackRef];
            theDevice = nil;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

#pragma mark - Lua Object Function Definitions

static const luaL_Reg userdata_metaLib[] = {
    // Common:
    {"name",                                razer_name},

    // Callback:
    {"callback",                            razer_callback},

    // Brightness:
    {"brightness",                          razer_brightness},

    // Backlights:
    {"backlightsOff",                       razer_backlightsOff},
    {"backlightsCustom",                    razer_backlightsCustom},
    {"backlightsWave",                      razer_backlightsWave},
    {"backlightsSpectrum",                  razer_backlightsSpectrum},
    {"backlightsReactive",                  razer_backlightsReactive},
    {"backlightsStatic",                    razer_backlightsStatic},
    {"backlightsStarlight",                 razer_backlightsStarlight},
    {"backlightsBreathing",                 razer_backlightsBreathing},

    // Status Lights:
    {"orangeStatusLight",                   razer_orangeStatusLight},
    {"greenStatusLight",                    razer_greenStatusLight},
    {"blueStatusLight",                     razer_blueStatusLight},

    // Private Functions:
    {"_remapping",                          razer_remapping},
    {"_productID",                          razer_productID},

    // Helpers:
    {"__tostring",                          razer_object_tostring},
    {"__eq",                                razer_object_eq},
    {"__gc",                                razer_object_gc},

    {NULL, NULL}
};

#pragma mark - Lua Library Function Definitions

static const luaL_Reg razerlib[] = {
    {"init",                                razer_init},
    {"discoveryCallback",                   razer_discoveryCallback},
    {"numDevices",                          razer_numDevices},
    {"getDevice",                           razer_getDevice},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", razer_gc},

    {NULL, NULL}
};

#pragma mark - Lua Initialiser

int luaopen_hs_librazer(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    razerRefTable = [skin registerLibrary:USERDATA_TAG functions:razerlib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSRazerDevice         forClass:"HSRazerDevice"];
    [skin registerLuaObjectHelper:toHSRazerDeviceFromLua forClass:"HSRazerDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

