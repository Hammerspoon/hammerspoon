@import Cocoa;
@import LuaSkin;

#import "HSSpeedEditorManager.h"
#import "HSSpeedEditorDevice.h"
#import "speededitor.h"

#define USERDATA_TAG "hs.speededitor"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSSpeedEditorManager *speedEditorManager;
int speedEditorRefTable = LUA_NOREF;

#pragma mark - Lua API
static int speededitor_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    LSGCCanary tmpLSUUID = speedEditorManager.lsCanary;
    [skin destroyGCCanary:&tmpLSUUID];
    speedEditorManager.lsCanary = tmpLSUUID;
    
    [speedEditorManager stopHIDManager];
    [speedEditorManager doGC];
    return 0;
}

/// hs.speededitor.init(fn) -> none
/// Function
/// Initialises the Speed Editor driver and sets a discovery callback
///
/// Parameters:
///  * fn - A function that will be called when a Speed Editor is connected or disconnected. It should take the following arguments:
///   * A boolean, `true` if a device was connected, `false` if a device was disconnected
///   * An `hs.speededitor` object, being the device that was connected/disconnected
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used.
static int speededitor_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    speedEditorManager = [[HSSpeedEditorManager alloc] init];
    speedEditorManager.discoveryCallbackRef = [skin luaRef:speedEditorRefTable atIndex:1];
    speedEditorManager.lsCanary = [skin createGCCanary];
    [speedEditorManager startHIDManager];

    return 0;
}

/// hs.speededitor.discoveryCallback(fn) -> none
/// Function
/// Sets/clears a callback for reacting to device discovery events
///
/// Parameters:
///  * fn - A function that will be called when a Speed Editor is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.speededitor object, being the device that was connected/disconnected
///
/// Returns:
///  * None
static int speededitor_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    speedEditorManager.discoveryCallbackRef = [skin luaUnref:speedEditorRefTable ref:speedEditorManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        speedEditorManager.discoveryCallbackRef = [skin luaRef:speedEditorRefTable atIndex:1];
    }

    return 0;
}

/// hs.speededitor.numDevices() -> number
/// Function
/// Gets the number of Speed Editor devices connected
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Gamepad devices attached to the system
static int speededitor_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, speedEditorManager.devices.count);
    return 1;
}

/// hs.speededitor.getDevice(num) -> speedEditorObject
/// Function
/// Gets an hs.speededitor object for the specified device
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices.
///
/// Returns:
///  * An `hs.speededitor` object or `nil` if something goes wrong.
static int speededitor_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];
    
    long deviceNumber = lua_tointeger(skin.L, 1) - 1;

    if (deviceNumber > speedEditorManager.devices.count) {
        lua_pushnil(L);
        return 1;
    }

    HSSpeedEditorDevice *device = speedEditorManager.devices[deviceNumber];

    if (device) {
        [skin pushNSObject:device];
    } else {
        lua_pushnil(L);
    }
    
    return 1;
}

/// hs.speededitor:callback(fn) -> speedEditorObject
/// Method
/// Sets/clears the button and jog wheel callback function for a Speed Editor
///
/// Parameters:
///  * fn - A function to be called when a button is pressed/released, or the jog wheel is rotated on the Speed Editor.
///
/// Returns:
///  * The hs.speededitor device
///  * The callback function should receive three arguments:
///   * The `hs.speededitor` userdata object
///   * A string containing the name of the button or "JOG WHEEL"
///   * A boolean indicating whether the button was pressed (true) or released (false). Not relevant if a Jog Wheel action.
///   * The Jog Wheel Mode (if not a button press)
///   * The Jog Wheel value (if not a button press)
///  * Possible buttons are: "SMART INSRT", "APPND", "RIPL OWR", "CLOSE UP", "PLACE ON TOP", "SRC_OWR", "IN", "OUT", "TRIM IN", "TRIM OUT", "ROLL", "SLIP SRC", "SLIP DEST", "TRANS DUR", "CUT", "DIS", "SMTH CUT", "SOURCE", "TIMELINE", "SHTL", "JOG", "SCRL", "ESC", "SYNC BIN", "AUDIO LEVEL", "FULL VIEW", "TRANS", "SPLIT", "SNAP", "RIPL DEL", "CAM 1", "CAM 2", "CAM 3", "CAM 4", "CAM 5", "CAM 6", "CAM 7", "CAM 8", "CAM 9", "LIVE OWR", "VIDEO ONLY", "AUDIO ONLY" and "STOP PLAY".
static int speededitor_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
    device.callbackRef = [skin luaUnref:speedEditorRefTable ref:device.callbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.callbackRef = [skin luaRef:speedEditorRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.speededitor:led(options) -> speedEditorObject
/// Method
/// Sets the status for the LED lights.
///
/// Parameters:
///  * options - A table where the key is the button ID, and the value is a boolean to turn the LED on or off.
///
/// Returns:
///  * The hs.speededitor device.
///
/// Notes:
///   * The possible keys for the options table should be: AUDIO ONLY, CAM1, CAM2, CAM3, CAM4, CAM5, CAM6, CAM7, CAM8, CAM9, CLOSE UP, CUT, DIS, JOG, LIVE OWR, SCRL, SHTL, SMTH CUT, SNAP, TRANS, VIDEO ONLY.
static int speededitor_led(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
    
    NSDictionary *options = [skin toNSObjectAtIndex:2];
    
    [device setJogLEDs:options];
    [device setLEDs:options];
    
    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.speededitor:battery() -> boolean, number
/// Method
/// Gets the battery status for the Speed Editor.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if charging, otherwise `false`
///  * The battery level between 0 and 100.
static int speededitor_battery(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
    
    [device getBatteryStatus];
    
    NSNumber *batteryLevel = device.batteryLevel;
    BOOL batteryCharging = device.batteryCharging;
        
    lua_pushboolean(skin.L, batteryCharging);
    [skin pushNSObject:batteryLevel];
        
    return 2;
}

/// hs.speededitor:serialNumber() -> string
/// Method
/// Gets the serial number for the Speed Editor.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The serial number as a string.
///
/// Notes:
///  * The serial number is the unique identifier from the USB Device, and not the product serial number that's on the sticker on the back of the Speed Editor.
static int speededitor_serialNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
    
    NSString *serialNumber = device.serialNumber;
    
    [skin pushNSObject:serialNumber];
        
    return 1;
}

/// hs.speededitor:jogMode(value) -> speedEditorObject
/// Method
/// Sets the Jog Mode for the Speed Editor
///
/// Parameters:
///  * value - "SHTL", "JOG", "SCRL" as a string.
///
/// Returns:
///  * The `hs.speededitor` device or `nil` if a wrong value is supplied.
///
/// Notes:
///  * "SHTL" provide relative position (i.e. positive value if turning clock-wise and negative if turning anti-clockwise).
///  * "JOG" sends an "absolute" position (based on the position when mode was set) -4096 -> 4096 range ~ half a turn.
///  * "SCRL" is the same as "RELATIVE 0" but with a small dead band around zero that maps to 0.
static int speededitor_jogMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];

    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"];
        
    NSString *jogMode = [skin toNSObjectAtIndex:2];
    
    if (![device.jogModeLookup objectForKey:jogMode]) {
        lua_pushnil(skin.L);
        return 1;
    }
    
    [device setJogMode:jogMode];
    
    lua_pushvalue(skin.L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSSpeedEditorDevice(lua_State *L, id obj) {
    HSSpeedEditorDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSSpeedEditorDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSSpeedEditorDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSSpeedEditorDevice, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int speededitor_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *device = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"] ;
    NSString *title = [NSString stringWithFormat:@"Speed Editor | serial: %@", device.serialNumber];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int speededitor_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSSpeedEditorDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSSpeedEditorDevice"] ;
        HSSpeedEditorDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSSpeedEditorDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int speededitor_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeedEditorDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSSpeedEditorDevice, L, 1, USERDATA_TAG) ;
    if (theDevice) {
        theDevice.selfRefCount-- ;
        if (theDevice.selfRefCount == 0) {
            theDevice.callbackRef = [skin luaUnref:speedEditorRefTable ref:theDevice.callbackRef] ;
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
    {"callback",                speededitor_callback},
    {"led",                     speededitor_led},
    {"battery",                 speededitor_battery},
    {"serialNumber",            speededitor_serialNumber},
    {"jogMode",                 speededitor_jogMode},
    
    {"__tostring",              speededitor_object_tostring},
    {"__eq",                    speededitor_object_eq},
    {"__gc",                    speededitor_object_gc},
    {NULL, NULL}
};

#pragma mark - Lua Library function definitions
static const luaL_Reg streamdecklib[] = {
    {"init",                    speededitor_init},
    {"discoveryCallback",       speededitor_discoveryCallback},
    {"numDevices",              speededitor_numDevices},
    {"getDevice",               speededitor_getDevice},
    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", speededitor_gc},
    {NULL, NULL}
};

#pragma mark - Lua initialiser
int luaopen_hs_libspeededitor(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
        
    speedEditorRefTable = [skin registerLibrary:USERDATA_TAG functions:streamdecklib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSSpeedEditorDevice         forClass:"HSSpeedEditorDevice"];
    [skin registerLuaObjectHelper:toHSSpeedEditorDeviceFromLua forClass:"HSSpeedEditorDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

