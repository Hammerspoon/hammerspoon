#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <lauxlib.h>

/// === hs.wifi.watcher ===
///
/// Watch for changes to the associated wifi network


// Common Code

#define USERDATA_TAG    "hs.wifi.watcher"

static int store_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [theHandler addIndex: x];
    return x;
}

static void remove_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [theHandler removeIndex: x];
}

// static void* push_udhandler(lua_State* L, int x) {
//     lua_rawgeti(L, LUA_REGISTRYINDEX, x);
//     return lua_touserdata(L, -1);
// }

// Not so common code

static NSMutableIndexSet* wifiHandlers;

@interface HSWiFiWatcher : NSObject
@property lua_State* L;
@property int fn;
@property (strong) CWInterface *interface;
@end

@implementation HSWiFiWatcher
- (id)init {
    if ([super init]) {
        // Re need to retain a reference to the WiFi interface so we receive the NSNotification
        self.interface = [CWInterface interfaceWithName:nil];
    }
    return self;
}

- (void) _ssidChanged:(id __unused)bla {
    [self performSelectorOnMainThread:@selector(ssidChanged:)
                                       withObject:nil
                                       waitUntilDone:YES];
}

- (void) ssidChanged:(id __unused)bla {
    lua_State* L = self.L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    if (lua_pcall(L, 0, 0, -2) != 0) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}
@end


typedef struct _wifiwatcher_t {
    bool running;
    int fn;
    int registryHandle;
    void* obj;
} wifiwatcher_t;


/// hs.wifi.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new ssid-watcher that can be started; fn will be called when your ssid changes
///
/// Note that fn will be called both when you join and leave a network. You can identify which
/// type of event is happening, with hs.wifi.currentNetwork(), which will return nil if you
/// have just left a network (and note further that switching from one network to another will
/// therefore trigger two calls to fn, one when leaving the current network and one when joining
/// the new one).
///
/// You would be advised to retain a variable somewhere with the "last associated network", thus
/// allowing you to determine which network has been left, if that is something you wish to react
/// to.
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
/// Function
/// Starts the ssid watcher, making it so fn is called each time the ssid changes
static int wifi_watcher_start(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (wifiwatcher->running) return 1;
    wifiwatcher->running = YES;
    wifiwatcher->registryHandle = store_udhandler(L, wifiHandlers, 1);

    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)wifiwatcher->obj
                                             selector:@selector(_ssidChanged:)
                                                 name:CWSSIDDidChangeNotification
                                               object:nil];

    return 1;
}

/// hs.wifi.watcher:stop() -> watcher
/// Function
/// Stops the ssid watcher's fn from getting called until started again.
static int wifi_watcher_stop(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (!wifiwatcher->running) return 1;
    wifiwatcher->running = NO;

    remove_udhandler(L, wifiHandlers, wifiwatcher->registryHandle);
    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)wifiwatcher->obj
                                                    name:CWSSIDDidChangeNotification
                                                  object:nil];

    return 1;
}

static int wifi_watcher_gc(lua_State* L) {
    wifiwatcher_t* wifiwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, wifi_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    luaL_unref(L, LUA_REGISTRYINDEX, wifiwatcher->fn);

    HSWiFiWatcher* object = (__bridge_transfer id)wifiwatcher->obj;
    object = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [wifiHandlers removeAllIndexes];
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
