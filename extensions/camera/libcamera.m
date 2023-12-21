@import Cocoa;
@import LuaSkin;
@import Hammertime;

#pragma mark - Module declarations
#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
static LSRefTable refTable;
static const char *USERDATA_TAG = "hs.camera";

//#pragma mark - Swift object userdata declaration
// FIXME: This should move out somewhere more generic, it will be needed for other extensions
typedef struct _HSuserData_t {
    int callbackRef;
    LSGCCanary lsCanary;
} HSuserData_t;

//#pragma mark - Devices watcher declarations
typedef struct _deviceWatcher_t {
    int callback;
    LSGCCanary lsCanary;
} deviceWatcher_t;
static deviceWatcher_t *deviceWatcher = nil;

static CameraManager *cameraManager = nil;

#pragma mark - Lua API
/// hs.camera.allCameras() -> table
/// Function
/// Get all the cameras known to the system
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing all of the known cameras
static int allCameras(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    [skin pushNSObject:[cameraManager getCameras].allValues];
    return 1;
}

// This calls the devices watcher callback Lua function when a device is added/removed
void deviceWatcherDoCallback(Camera *device, NSString *event) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    if (!deviceWatcher) {
        [skin logWarn:@"hs.camera devices watcher callback fired, but deviceWatcher is nil. This is a bug"];
        return;
    }

    if (![skin checkGCCanary:deviceWatcher->lsCanary]) {
        return;
    }
    _lua_stackguard_entry(skin.L);

    if (deviceWatcher->callback == LUA_NOREF) {
        [skin logWarn:@"hs.camera devices watcher callback fired, but there is no callback. This is a bug"];
        return;
    }

    [skin pushLuaRef:refTable ref:deviceWatcher->callback];
    [skin pushNSObject:device];
    [skin pushNSObject:event];
    [skin protectedCallAndError:@"hs.camera devices callback" nargs:2 nresults:0];

    _lua_stackguard_exit(skin.L);
}

/// hs.camera.startWatcher()
/// Function
/// Starts the camera devices watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int startWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    if (!deviceWatcher || deviceWatcher->callback == LUA_NOREF) {
        [skin logError:@"You must call hs.camera.setWatcherCallback() before hs.camera.startWatcher()"];
        return 0;
    }

    if (cameraManager.isWatcherRunning) {
        return 0;
    }

    // For some reason, the device added/removed notifications don't fire unless we ask macOS to enumerate the devices first
    NSDictionary *cameras __unused = [cameraManager getCameras];

    cameraManager.observerCallback = ^(Camera *camera, NSString *event) {
        deviceWatcherDoCallback(camera, event);
    };
    [cameraManager startWatcher];

    return 0;
}

/// hs.camera.stopWatcher()
/// Function
/// Stops the camera devices watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int stopWatcher(lua_State *L) {
    // This is an ugly hack so we can call this from elsewhere without checkArgs exploding
    if (L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        [skin checkArgs:LS_TBREAK];
    }

    if (!deviceWatcher) {
        return 0;
    }

    [cameraManager stopWatcher];

    return 0;
}

/// hs.camera.isWatcherRunning() -> Boolean
/// Function
/// Checks if the camera devices watcher is running
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the watcher is running, otherwise False
static int isWatcherRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushboolean(L, deviceWatcher && cameraManager.isWatcherRunning);

    return 1;
}

/// hs.camera.setWatcherCallback(fn)
/// Function
/// Sets/clears the callback function for the camera devices watcher
///
/// Parameters:
///  * fn - A callback function, or nil to remove a previously set callback. The callback should accept a two arguments (see Notes below)
///
/// Returns:
///  * None
///
/// Notes:
///  * The callback will be called when a camera is added or removed from the system
///  * To watch for changes within a single camera device, see `hs.camera:newWatcher()`
///  * The callback function arguments are:
///   * An hs.camera device object for the affected device
///   * A string, either "Added" or "Removed" depending on whether the device was added or removed from the system
///  * For "Removed" events, most methods on the hs.camera device object will not function correctly anymore and the device object passed to the callback is likely to be useless. It is recommended you re-check `hs.camera.allCameras()` and keep records of the cameras you care about
///  * Passing nil will cause the watcher to stop if it is running
static int setWatcherCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    if (!deviceWatcher) {
        deviceWatcher = malloc(sizeof(deviceWatcher_t));
        memset(deviceWatcher, 0, sizeof(deviceWatcher_t));
        deviceWatcher->callback = LUA_NOREF;
        deviceWatcher->lsCanary = [skin createGCCanary];
    }

    deviceWatcher->callback = [skin luaUnref:refTable ref:deviceWatcher->callback];

    switch (lua_type(L, 1)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 1);
            deviceWatcher->callback = [skin luaRef:refTable];
            break;
        case LUA_TNIL:
            stopWatcher(NULL);
            break;
        default:
            break;
    }

    return 0;
}

/// hs.camera:uid() -> String
/// Method
/// Get the unique ID of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the UID of the camera
///
/// Notes:
///  * The UID is not guaranteed to be stable across reboots
static int camera_uid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.uniqueID];
    return 1;
}

/// hs.camera:connectionID() -> String
/// Deprecated
/// Get the raw connection ID of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number that will always be zero
static int camera_cID(lua_State *L) {
    // FIXME: Add some kind of log message that a deprecated method is being used
    lua_pushinteger(L, 0);
    return 1;
}

/// hs.camera:name() -> String
/// Method
/// Get the name of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the camera
static int camera_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.name];
    return 1;
}

/// hs.camera:manufacturer() -> String
/// Method
/// Get the manufacturer of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the manufacturer of the camera
static int camera_manufacturer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.manufacturer];
    return 1;
}

/// hs.camera:model() -> String
/// Method
/// Get the model name of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the model name of the camera
static int camera_model(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.modelID];
    return 1;
}

/// hs.camera:transport() -> String
/// Method
/// Get the transport type (ie how it is connected) of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the transport type of the camera
static int camera_transport(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.transportType];
    return 1;
}

/// hs.camera:isInUse() -> Boolean
/// Method
/// Get the usage status of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the camera is in use, otherwise False
static int camera_isInUse(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, camera.isInUse);
    return 1;
}

/// hs.camera:setPropertyWatcherCallback(fn) -> hs.camera object
/// Method
/// Sets or clears a callback for when an hs.camera object starts or stops being used by another application
///
/// Parameters:
///  * fn - A function to be called when usage the camera change, or nil to clear a previously set callback. The function should accept the following parameters:
///   * The hs.camera object that changed
///   * (DEPRECATED) A string describing the property that changed. Possible values are:
///    * gone - The device's "in use" status changed (ie another app started using the camera, or stopped using it)
///   * (DEPRECATED) A string containing the scope of the event, this will likely always be "glob"
///   * (DEPRECATED) A number containing the element of the event, this will likely always be "0"
///
/// Returns:
///  * The `hs.camera` object
static int camera_propertyWatcherCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    HSuserData_t *userData = camera.userData;

    userData->callbackRef = [skin luaUnref:refTable ref:userData->callbackRef];

    switch (lua_type(L, 2)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 2);
            userData->callbackRef = [skin luaRef:refTable];
            break;
        case LUA_TNIL:
            [camera stopIsInUseWatcher];
            break;
        default:
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:startPropertyWatcher()
/// Method
/// Starts the property watcher on a camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.camera` object
static int camera_startPropertyWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    Camera *camera = [skin toNSObjectAtIndex:1];
    HSuserData_t *userData = camera.userData;

    if (userData->callbackRef == LUA_NOREF) {
        [skin logError:@"You must call hs.camera:setPropertyWatcherCallback() before hs.camera:startPropertyWatcher()"];
        lua_pushnil(L);
        return 1;
    }

    camera.observerCallback = ^(Camera *device) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        HSuserData_t *userData = device.userData;

        if (!userData || ![skin checkGCCanary:userData->lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        if (userData->callbackRef == LUA_NOREF) {
            [skin logError:@"hs.camera property watcher fired, but no Lua callback is currently set"];
        } else {
            [skin pushLuaRef:refTable ref:userData->callbackRef];
            [skin pushNSObject:device];
            lua_pushstring(L, "gone");
            lua_pushstring(L, "glob");
            lua_pushinteger(L, 0);
            [skin protectedCallAndError:@"hs.camera:propertyWatcherCallback" nargs:4 nresults:0];
        }
        _lua_stackguard_exit(skin.L);
    };
    [camera startIsInUseWatcher];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:stopPropertyWatcher()
/// Method
/// Stops the property watcher on a camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.camera` object
static int camera_stopPropertyWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    Camera *camera = [skin toNSObjectAtIndex:1];

    [camera stopIsInUseWatcher];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:isPropertyWatcherRunning() -> bool
/// Method
/// Checks if the property watcher on a camera object is running
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the property watcher is running, otherwise False
static int camera_isPropertyWatcherRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    Camera *camera = [skin toNSObjectAtIndex:1];

    lua_pushboolean(L, camera.isInUseWatcherRunning);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
static int pushCamera(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    Camera *value = obj;

    // Check if Camera needs an HSuserdata_t
    if (!value.userData) {
        HSuserData_t *userData = malloc(sizeof(HSuserData_t));
        memset(userData, 0, sizeof(HSuserData_t));
        userData->callbackRef = LUA_NOREF;
        userData->lsCanary = [skin createGCCanary];
        value.userData = userData;
    }
    void** valuePtr = lua_newuserdata(L, sizeof(Camera *));
    *valuePtr = (__bridge_retained void*)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toCameraFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    Camera *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge Camera, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Core Lua metamethods
static int camera_tostring(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    Camera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%@:%@)", USERDATA_TAG, camera.uniqueID, camera.name]];
    return 1;
}

static int camera_eq(lua_State *L) {
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        Camera *obj1 = [skin luaObjectAtIndex:1 toClass:"Camera"] ;
        Camera *obj2 = [skin luaObjectAtIndex:2 toClass:"Camera"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int camera_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    Camera *camera = get_objectFromUserdata(__bridge_transfer Camera, L, 1, USERDATA_TAG);

    if (camera) {
        if (camera.isInUseWatcherRunning) {
            [camera stopIsInUseWatcher];
        }
    }

    if (camera.userData) {
        HSuserData_t *userData = camera.userData;
        userData->callbackRef = [skin luaUnref:refTable ref:userData->callbackRef];
        [skin destroyGCCanary:&(userData->lsCanary)];
        free(camera.userData);
        camera.userData = nil;
    }

    camera = nil;

    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

static int module_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (deviceWatcher) {
        stopWatcher(NULL);
        deviceWatcher->callback = [skin luaUnref:refTable ref:deviceWatcher->callback];
        [skin destroyGCCanary:&(deviceWatcher->lsCanary)];
        free(deviceWatcher);
        deviceWatcher = nil;
    }

    [cameraManager drainCache];
    cameraManager = nil;

    return 0;
}

#pragma mark - HSCamera userdata methods
static const luaL_Reg cameraDeviceLib[] = {
    {"uid", camera_uid},
    {"connectionID", camera_cID},
    {"name", camera_name},
    {"manufacturer", camera_manufacturer},
    {"model", camera_model},
    {"transport", camera_transport},
    {"isInUse", camera_isInUse},
    {"setPropertyWatcherCallback", camera_propertyWatcherCallback},
    {"startPropertyWatcher", camera_startPropertyWatcher},
    {"stopPropertyWatcher", camera_stopPropertyWatcher},
    {"isPropertyWatcherRunning", camera_isPropertyWatcherRunning},

    {"__tostring", camera_tostring},
    {"__eq",       camera_eq},
    {"__gc",       camera_gc},
    {NULL, NULL}
};

#pragma mark - module functions
static const luaL_Reg cameraLib[] = {
    {"allCameras", allCameras},
    {"setWatcherCallback", setWatcherCallback},
    {"startWatcher", startWatcher},
    {"stopWatcher", stopWatcher},
    {"isWatcherRunning", isWatcherRunning},

    {NULL, NULL}
};
static const luaL_Reg cameraLibMeta[] = {
    {"__gc", module_gc},
    {NULL, NULL}
};

#pragma mark - Lua initialisation
int luaopen_hs_libcamera(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    cameraManager = [[CameraManager alloc] init];
    refTable = [skin registerLibrary:USERDATA_TAG functions:cameraLib metaFunctions:cameraLibMeta];

    [skin registerObject:USERDATA_TAG objectFunctions:cameraDeviceLib];
    [skin registerPushNSHelper:pushCamera forClass:"Hammertime.Camera"];
    [skin registerLuaObjectHelper:toCameraFromLua forClass:"Hammertime.Camera" withUserdataMapping:USERDATA_TAG];

    return 1;
}
