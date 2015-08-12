#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

/// === hs.wifi.watcher ===
///
/// Watch for changes to the associated wifi network


// Common Code

#define USERDATA_TAG    "hs.wifi.watcher"

// Not so common code

@interface HSWiFiWatcher : NSObject
@property lua_State* L;
@property int fn;
@property (strong) CWInterface *interface;
@end

@implementation HSWiFiWatcher
- (id)init {
    if (self = [super init]) {
        // Re need to retain a reference to the WiFi interface so we receive the NSNotification
        self.interface = [CWInterface interface];
    }
    return self;
}

- (void) _ssidChanged:(id __unused)bla {
    [self performSelectorOnMainThread:@selector(ssidChanged:)
                                       withObject:nil
                                       waitUntilDone:YES];
}

- (void) ssidChanged:(id __unused)bla {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    if (![skin protectedCallAndTraceback:0 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
    }
}
@end


typedef struct _wifiwatcher_t {
    bool running;
    int fn;
    void* obj;
} wifiwatcher_t;


/// hs.wifi.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new watcher for WiFi network events
///
/// Parameters:
///  * fn - A function that will be called when a WiFi network is connected or disconnected. The function should accept no parameters.
///
/// Returns:
///  * A `hs.wifi.watcher` object
///
/// Notes:
///  * The callback function will be called both when you join a network and leave it. You can identify which type of event is happening with `hs.wifi.currentNetwork()`, which will return nil if you have just disconnected from a WiFi network.
///  * This means that when you switch from one network to another, you will receive a disconnection event as you leave the first network, and a connection event as you join the second. You are advised to keep a variable somewhere that tracks the name of the last network you were connected to, so you can track changes that involve multiple events.
static int wifi_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    wifiwatcher_t* wifiwatcher = lua_newuserdata(L, sizeof(wifiwatcher_t));
    memset(wifiwatcher, 0, sizeof(wifiwatcher_t));

    lua_pushvalue(L, 1);
    wifiwatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    HSWiFiWatcher* object = [[HSWiFiWatcher alloc] init];
    object.L = L;
    object.fn = wifiwatcher->fn;
    wifiwatcher->obj = (__bridge_retained void*)object;
    wifiwatcher->running = NO;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.wifi.watcher:start() -> watcher
/// Method
/// Starts the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.wifi.watcher` object
static int wifi_watcher_start(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (wifiwatcher->running) return 1;
    wifiwatcher->running = YES;

    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)wifiwatcher->obj
                                             selector:@selector(_ssidChanged:)
                                                 name:CWSSIDDidChangeNotification
                                               object:nil];

    return 1;
}

/// hs.wifi.watcher:stop() -> watcher
/// Method
/// Stops the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.wifi.watcher` object
static int wifi_watcher_stop(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (!wifiwatcher->running) return 1;
    wifiwatcher->running = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)wifiwatcher->obj
                                                    name:CWSSIDDidChangeNotification
                                                  object:nil];

    return 1;
}

static int wifi_watcher_gc(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, wifi_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    luaL_unref(L, LUA_REGISTRYINDEX, wifiwatcher->fn);
    wifiwatcher->fn = LUA_NOREF;

    HSWiFiWatcher* object = (__bridge_transfer id)wifiwatcher->obj;
    object = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg wifi_metalib[] = {
    {"start",   wifi_watcher_start},
    {"stop",    wifi_watcher_stop},
    {"__gc",    wifi_watcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg wifiLib[] = {
    {"new",     wifi_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_wifi_watcher(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, wifi_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, wifiLib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
