@import Cocoa;
@import LuaSkin;

#import "HSStreamDeckManager.h"
#import "HSStreamDeckDevice.h"
#import "streamdeck.h"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static HSStreamDeckManager *deckManager;
LSRefTable streamDeckRefTable = LUA_NOREF;

#pragma mark - Lua API
static int streamdeck_gc(lua_State *L __unused) {
    [deckManager stopHIDManager];
    [deckManager doGC];
    return 0;
}

/// hs.streamdeck.init(fn)
/// Function
/// Initialises the Stream Deck driver and sets a discovery callback
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.streamdeck object, being the device that was connected/disconnected
///
/// Returns:
///  * None
///
/// Notes:
///  * This function must be called before any other parts of this module are used
static int streamdeck_init(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager = [[HSStreamDeckManager alloc] init];
    deckManager.discoveryCallbackRef = [skin luaRef:streamDeckRefTable atIndex:1];
    [deckManager startHIDManager];

    return 0;
}

/// hs.streamdeck.discoveryCallback(fn)
/// Function
/// Sets/clears a callback for reacting to device discovery events
///
/// Parameters:
///  * fn - A function that will be called when a Streaming Deck is connected or disconnected. It should take the following arguments:
///   * A boolean, true if a device was connected, false if a device was disconnected
///   * An hs.streamdeck object, being the device that was connected/disconnected
///
/// Returns:
///  * None
static int streamdeck_discoveryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    deckManager.discoveryCallbackRef = [skin luaUnref:streamDeckRefTable ref:deckManager.discoveryCallbackRef];

    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        deckManager.discoveryCallbackRef = [skin luaRef:streamDeckRefTable atIndex:1];
    }

    return 0;
}

/// hs.streamdeck.numDevices()
/// Function
/// Gets the number of Stream Deck devices connected
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of Stream Deck devices attached to the system
static int streamdeck_numDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushinteger(skin.L, deckManager.devices.count);
    return 1;
}

/// hs.streamdeck.getDevice(num)
/// Function
/// Gets an hs.streamdeck object for the specified device
///
/// Parameters:
///  * num - A number that should be within the bounds of the number of connected devices
///
/// Returns:
///  * An hs.streamdeck object
static int streamdeck_getDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];

    [skin pushNSObject:deckManager.devices[lua_tointeger(skin.L, 1) - 1]];
    return 1;
}

/// hs.streamdeck:buttonCallback(fn)
/// Method
/// Sets/clears the button callback function for a deck
///
/// Parameters:
///  * fn - A function to be called when a button is pressed/released on the stream deck. It should receive three arguments:
///   * The hs.streamdeck userdata object
///   * A number containing the button that was pressed/released
///   * A boolean indicating whether the button was pressed (true) or released (false)
///
/// Returns:
///  * The hs.streamdeck device
static int streamdeck_buttonCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];
    device.buttonCallbackRef = [skin luaUnref:streamDeckRefTable ref:device.buttonCallbackRef];

    if (lua_type(skin.L, 2) == LUA_TFUNCTION) {
        device.buttonCallbackRef = [skin luaRef:streamDeckRefTable atIndex:2];
    }

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.streamdeck:setBrightness(brightness)
/// Method
/// Sets the brightness of a deck
///
/// Parameters:
///  * brightness - A whole number between 0 and 100 indicating the percentage brightness level to set
///
/// Returns:
///  * The hs.streamdeck device
static int streamdeck_setBrightness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [device setBrightness:(int)lua_tointeger(skin.L, 2)];

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.streamdeck:reset()
/// Method
/// Resets a deck
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hs.streamdeck object
static int streamdeck_reset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];
    [device reset];

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.streamdeck:serialNumber()
/// Method
/// Gets the serial number of a deck
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the serial number of the deck
static int streamdeck_serialNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [skin pushNSObject:device.serialNumber];
    return 1;
}

/// hs.streamdeck:firmwareVersion()
/// Method
/// Gets the firmware version of a deck
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the firmware version of the deck
static int streamdeck_firmwareVersion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [skin pushNSObject:[device firmwareVersion]];
    return 1;
}

/// hs.streamdeck:buttonLayout()
/// Method
/// Gets the layout of buttons the device has
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of columns
///  * The number of rows
static int streamdeck_buttonLayout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    lua_pushinteger(skin.L, device.keyColumns);
    lua_pushinteger(skin.L, device.keyRows);
    return 2;
}

/// hs.streamdeck:setButtonImage(button, image)
/// Method
/// Sets the image of a button on the deck
///
/// Parameters:
///  * button - A number (from 1 to 15) describing which button to set the image for
///  * image - An hs.image object
///
/// Returns:
///  * The hs.streamdeck object
static int streamdeck_setButtonImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TUSERDATA, "hs.image", LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [device setImage:[skin luaObjectAtIndex:3 toClass:"NSImage"] forButton:(int)lua_tointeger(skin.L, 2)];

    lua_pushvalue(skin.L, 1);
    return 1;
}

/// hs.streamdeck:setButtonColor(button, color)
/// Method
/// Sets a button on the deck to the specified color
///
/// Parameters:
///  * button - A number (from 1 to 15) describing which button to set the color on
///  * color - An hs.drawing.color object
///
/// Returns:
///  * The hs.streamdeck object
static int streamdeck_setButtonColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [device setColor:[skin luaObjectAtIndex:3 toClass:"NSColor"] forButton:(int)lua_tointeger(skin.L, 2)];

    lua_pushvalue(skin.L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSStreamDeckDevice(lua_State *L, id obj) {
    HSStreamDeckDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSStreamDeckDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSStreamDeckDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSStreamDeckDevice *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSStreamDeckDevice, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int streamdeck_object_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSStreamDeckDevice *obj = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"] ;
    NSString *title = [NSString stringWithFormat:@"%@, serial: %@", obj.deckType, obj.serialNumber];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int streamdeck_object_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSStreamDeckDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"] ;
        HSStreamDeckDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSStreamDeckDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int streamdeck_object_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSStreamDeckDevice *theDevice = get_objectFromUserdata(__bridge_transfer HSStreamDeckDevice, L, 1, USERDATA_TAG) ;
    if (theDevice) {
        theDevice.selfRefCount-- ;
        if (theDevice.selfRefCount == 0) {
            theDevice.buttonCallbackRef = [skin luaUnref:streamDeckRefTable ref:theDevice.buttonCallbackRef] ;
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
    {"serialNumber", streamdeck_serialNumber},
    {"firmwareVersion", streamdeck_firmwareVersion},
    {"buttonLayout", streamdeck_buttonLayout},
    {"buttonCallback", streamdeck_buttonCallback},
    {"setButtonImage", streamdeck_setButtonImage},
    {"setButtonColor", streamdeck_setButtonColor},
    {"setBrightness", streamdeck_setBrightness},
    {"reset", streamdeck_reset},

    {"__tostring", streamdeck_object_tostring},
    {"__eq", streamdeck_object_eq},
    {"__gc", streamdeck_object_gc},
    {NULL, NULL}
};

#pragma mark - Lua Library function definitions
static const luaL_Reg streamdecklib[] = {
    {"init", streamdeck_init},
    {"discoveryCallback", streamdeck_discoveryCallback},
    {"numDevices", streamdeck_numDevices},
    {"getDevice", streamdeck_getDevice},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", streamdeck_gc},

    {NULL, NULL}
};

#pragma mark - Lua initialiser
int luaopen_hs_streamdeck_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    streamDeckRefTable = [skin registerLibrary:USERDATA_TAG functions:streamdecklib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSStreamDeckDevice         forClass:"HSStreamDeckDevice"];
    [skin registerLuaObjectHelper:toHSStreamDeckDeviceFromLua forClass:"HSStreamDeckDevice" withTableMapping:USERDATA_TAG];

    return 1;
}

