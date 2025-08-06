@import Cocoa;
@import LuaSkin;

#import "HSBlackmagicManager.h"
#import "HSBlackmagicDevice.h"
#import "blackmagic.h"

#define USERDATA_TAG "hs.blackmagic"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSBlackmagicManager *blackmagicManager;
int blackmagicRefTable = LUA_NOREF;

#pragma mark - Lua API
static int blackmagic_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    LSGCCanary tmpLSUUID = blackmagicManager.lsCanary;
    [skin destroyGCCanary:&tmpLSUUID];
    blackmagicManager.lsCanary = tmpLSUUID;
    
    [blackmagicManager stopHIDManager];
    [blackmagicManager doGC];
    return 0;
}

/// hs.blackmagic.init(fn) -> none
/// Function
/// Initialises the Blackmagic driver and sets a discovery callback.
///
/// Parameters:
///  * fn - A function that will be called when a Blackmagic device is connected or disconnected. It should take the following arguments:
///   * A boolean, `true` if a device was connected, `false` if a device was disconnected.
///   * An `hs.blackmagic` object, being the device that was connected/disconnected.
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used.
static int blackmagic_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    blackmagicManager = [[HSBlackmagicManager alloc] init];
    blackmagicManager.discoveryCallbackRef = [skin luaRef:blackmagicRefTable atIndex:1];
    blackmagicManager.lsCanary = [skin createGCCanary];
    [blackmagicManager startHIDManager];

    return 0;
}

/// hs.blackmagic.discoveryCallback(fn) -> none
/// Function
/// Sets/clears a callback for reacting to device discovery events.
///
/// Parameters:
///  * fn - A function that will be called when a Blackmagic device is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected.
///   * An `hs.blackmagic` object, being the device that was connected/disconnected.
///
/// Returns:
///  * None
static int blackmagic_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    blackmagicManager.discoveryCallbackRef = [skin luaUnref:blackmagicRefTable ref:blackmagicManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        blackmagicManager.discoveryCallbackRef = [skin luaRef:blackmagicRefTable atIndex:1];
    }

    return 0;
}

/// hs.blackmagic.numDevices() -> number
/// Function
/// Gets the number of Blackmagic devices connected.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Blackmagic devices attached to the system.
static int blackmagic_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, blackmagicManager.devices.count);
    return 1;
}

/// hs.blackmagic.getDevice(num) -> `hs.blackmagic`
/// Function
/// Gets an `hs.blackmagic` object for the specified device.
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices.
///
/// Returns:
///  * An `hs.blackmagic` object or `nil` if something goes wrong.
static int blackmagic_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];
    
    long deviceNumber = lua_tointeger(skin.L, 1) - 1;

    if (deviceNumber > blackmagicManager.devices.count) {
        lua_pushnil(L);
        return 1;
    }

    HSBlackmagicDevice *device = blackmagicManager.devices[deviceNumber];

    if (device) {
        [skin pushNSObject:device];
    } else {
        lua_pushnil(L);
    }
    
    return 1;
}

/// hs.blackmagic:callback(fn) -> `hs.blackmagic`
/// Method
/// Sets/clears the button and jog wheel callback function for a Blackmagic device.
///
/// Parameters:
///  * fn - A function to be called when a button is pressed/released, or the jog wheel is rotated on the Blackmagic device.
///
/// Returns:
///  * The hs.blackmagic device
///  * The callback function should receive three arguments:
///   * The `hs.blackmagic` userdata object
///   * A string containing the name of the button or "JOG WHEEL"
///   * A boolean indicating whether the button was pressed (true) or released (false). Not relevant if a Jog Wheel action.
///   * The Jog Wheel Mode (if not a button press)
///   * The Jog Wheel value (if not a button press)
///  * You can use `hs.blackmagic.buttonNames[deviceType]` to get a table of possible values.
static int blackmagic_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    device.callbackRef = [skin luaUnref:blackmagicRefTable ref:device.callbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.callbackRef = [skin luaRef:blackmagicRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.blackmagic:led(options) -> `hs.blackmagic`
/// Method
/// Sets the status for the LED lights.
///
/// Parameters:
///  * options - A table where the key is the button ID, and the value is a boolean to turn the LED on or off.
///
/// Returns:
///  * The hs.blackmagic device.
///
/// Notes:
///  * You can also use `hs.blackmagic.ledNames[deviceType]` to get a table of possible values.
static int blackmagic_led(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    
    NSDictionary *options = [skin toNSObjectAtIndex:2];
    
    [device setJogLEDs:options];
    [device setLEDs:options];
    
    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.blackmagic:battery() -> boolean, number
/// Method
/// Gets the battery status for the Blackmagic device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if charging, otherwise `false`
///  * The battery level between 0 and 100.
static int blackmagic_battery(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    
    [device getBatteryStatus];
    
    NSNumber *batteryLevel = device.batteryLevel;
    BOOL batteryCharging = device.batteryCharging;
        
    lua_pushboolean(skin.L, batteryCharging);
    [skin pushNSObject:batteryLevel];
        
    return 2;
}

/// hs.blackmagic:serialNumber() -> string
/// Method
/// Gets the serial number for the Blackmagic device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The serial number as a string.
///
/// Notes:
///  * The serial number is the unique identifier from the USB Device, and not the product serial number that's on the sticker on the back of the Blackmagic device.
static int blackmagic_serialNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    
    NSString *serialNumber = device.serialNumber;
    
    [skin pushNSObject:serialNumber];
        
    return 1;
}

/// hs.blackmagic:deviceType() -> string
/// Method
/// Gets the device type for the Blackmagic device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The device type as a string - either "Speed Editor" or "Editor Keyboard".
static int blackmagic_deviceType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    
    NSString *deviceType = device.deviceType;
    
    [skin pushNSObject:deviceType];
        
    return 1;
}

/// hs.blackmagic:jogMode([value]) -> `hs.blackmagic`, string
/// Method
/// Gets or Sets the Jog Mode for the Blackmagic device.
///
/// Parameters:
///  * value - an optional string of "RELATIVE", "ABSOLUTE" and "ABSOLUTE ZERO" if setting.
///
/// Returns:
///  * The `hs.blackmagic` device
///  * "RELATIVE", "ABSOLUTE" and "ABSOLUTE ZERO" as a string, or `nil` if something has gone wrong.
///
/// Notes:
///  * You can use `hs.blackmagic.jogModeNames[deviceType]` to get a table of possible values.
///  * "RELATIVE" - Returns a “relative” position - a positive number if turning right, and a negative number if turning left. The faster you turn, the higher the number. One step is 360.
///  * "ABSOLUTE" - Returns an “absolute” position, based on when the mode was set. It has a range of -4096 (left of 0) to 4096 (right of 0). On the Editor Keyboard it has mechanical hard stops at -4096 and 4096, meaning you only use one half of the wheel.
///  * "ABSOLUTE ZERO" - The same as "ABSOLUTE", but has a small dead zone around 0 - which mechincally "snaps" to zero on a Editor Keyboard.
static int blackmagic_jogMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"];
    
    NSString *jogMode;
    
    if (lua_type(L, 2) != LUA_TNONE) {
        //
        // Setting:
        //
        jogMode = [skin toNSObjectAtIndex:2];
        
        if (![device.jogModeLookup objectForKey:jogMode]) {
            lua_pushvalue(skin.L, 1);
            lua_pushnil(skin.L);
            return 2;
        }
        
        [device setJogMode:jogMode];
    } else {
        //
        // Getting:
        //
        [device getJogMode];
        jogMode = device.jogModeCache;
    }
        
    lua_pushvalue(skin.L, 1);
    [skin pushNSObject:jogMode];
    return 2;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSBlackmagicDevice(lua_State *L, id obj) {
    HSBlackmagicDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSBlackmagicDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSBlackmagicDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSBlackmagicDevice *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSBlackmagicDevice, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int blackmagic_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSBlackmagicDevice *device = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"] ;
    NSString *title = [NSString stringWithFormat:@"%@ | serial: %@", device.deviceType, device.serialNumber];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int blackmagic_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSBlackmagicDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSBlackmagicDevice"] ;
        HSBlackmagicDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSBlackmagicDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int blackmagic_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSBlackmagicDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSBlackmagicDevice, L, 1, USERDATA_TAG) ;
    if (theDevice) {
        theDevice.selfRefCount-- ;
        if (theDevice.selfRefCount == 0) {
            theDevice.callbackRef = [skin luaUnref:blackmagicRefTable ref:theDevice.callbackRef] ;

            // Make sure we invalidate to prevent the authentication timer from triggering:
            [theDevice invalidate];

            theDevice = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

#pragma mark - Lua object function definitions
static const luaL_Reg userdata_metaLib[] = {
    {"callback",                blackmagic_callback},
    {"led",                     blackmagic_led},
    {"battery",                 blackmagic_battery},
    {"serialNumber",            blackmagic_serialNumber},
    {"deviceType",              blackmagic_deviceType},
    {"jogMode",                 blackmagic_jogMode},
    
    {"__tostring",              blackmagic_object_tostring},
    {"__eq",                    blackmagic_object_eq},
    {"__gc",                    blackmagic_object_gc},
    {NULL, NULL}
};

#pragma mark - Lua Library function definitions
static const luaL_Reg blackmagiclib[] = {
    {"init",                    blackmagic_init},
    {"discoveryCallback",       blackmagic_discoveryCallback},
    {"numDevices",              blackmagic_numDevices},
    {"getDevice",               blackmagic_getDevice},
    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", blackmagic_gc},
    {NULL, NULL}
};

#pragma mark - Lua initialiser
int luaopen_hs_libblackmagic(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
        
    blackmagicRefTable = [skin registerLibrary:USERDATA_TAG functions:blackmagiclib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSBlackmagicDevice         forClass:"HSBlackmagicDevice"];
    [skin registerLuaObjectHelper:toHSBlackmagicDeviceFromLua forClass:"HSBlackmagicDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

