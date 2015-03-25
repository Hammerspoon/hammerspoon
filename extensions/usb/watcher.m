#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <lauxlib.h>

/// === hs.usb.watcher ===
///
/// Watch for USB device insertion/removal events


// Common Code

#define USERDATA_TAG    "hs.usb.watcher"

static int store_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [theHandler addIndex: x];
    return x;
}

static int remove_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [theHandler removeIndex: x];
    return LUA_NOREF;
}

// Not so common code

static NSMutableIndexSet* usbHandlers;

typedef struct _usbwatcher_t {
    bool running;
    int fn;
    int registryHandle;
    void* obj;
} usbwatcher_t;


/// hs.usb.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new watcher for usb network events
///
/// Parameters:
///  * fn - A function that will be called when a usb network is connected or disconnected. The function should accept no parameters.
///
/// Returns:
///  * A `hs.usb.watcher` object
///
/// Notes:
///  * The callback function will be called both when you join a network and leave it. You can identify which type of event is happening with `hs.usb.currentNetwork()`, which will return nil if you have just disconnected from a usb network.
///  * This means that when you switch from one network to another, you will receive a disconnection event as you leave the first network, and a connection event as you join the second. You are advised to keep a variable somewhere that tracks the name of the last network you were connected to, so you can track changes that involve multiple events.
static int usb_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    usbwatcher_t* usbwatcher = lua_newuserdata(L, sizeof(usbwatcher_t));
    memset(usbwatcher, 0, sizeof(usbwatcher_t));

    lua_pushvalue(L, 1);
    usbwatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    HSusbWatcher* object = [[HSusbWatcher alloc] init];
    object.L = L;
    object.fn = usbwatcher->fn;
    usbwatcher->obj = (__bridge_retained void*)object;
    usbwatcher->running = NO;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.usb.watcher:start() -> watcher
/// Method
/// Starts the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.usb.watcher` object
static int usb_watcher_start(lua_State* L) {
    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (usbwatcher->running) return 1;
    usbwatcher->running = YES;
    usbwatcher->registryHandle = store_udhandler(L, usbHandlers, 1);

    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)usbwatcher->obj
                                             selector:@selector(_ssidChanged:)
                                                 name:CWSSIDDidChangeNotification
                                               object:nil];

    return 1;
}

/// hs.usb.watcher:stop() -> watcher
/// Method
/// Stops the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.usb.watcher` object
static int usb_watcher_stop(lua_State* L) {
    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (!usbwatcher->running) return 1;
    usbwatcher->running = NO;

    usbwatcher->registryHandle = remove_udhandler(L, usbHandlers, usbwatcher->registryHandle);
    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)usbwatcher->obj
                                                    name:CWSSIDDidChangeNotification
                                                  object:nil];

    return 1;
}

static int usb_watcher_gc(lua_State* L) {
    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, usb_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    luaL_unref(L, LUA_REGISTRYINDEX, usbwatcher->fn);
    usbwatcher->fn = LUA_NOREF;

    HSusbWatcher* object = (__bridge_transfer id)usbwatcher->obj;
    object = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [usbHandlers removeAllIndexes];
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg usb_metalib[] = {
    {"start",   usb_watcher_start},
    {"stop",    usb_watcher_stop},
    {"__gc",    usb_watcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg usbLib[] = {
    {"new",     usb_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_usb_watcher(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, usb_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, usbLib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
