#import "helpers.h"
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

/// === battery.watcher ===
/// Functions for watching battery state changes.

typedef struct _battery_watcher_t {
    lua_State* L;
    CFRunLoopSourceRef t;
    int fn;
    int self;
    bool started;
} battery_watcher_t;

static void callback(void *info) {
    battery_watcher_t* t = info;
    lua_State* L = t->L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, t->fn);
    if (lua_pcall(L, 0, 0, 0))
        hydra_handle_error(L);
    
}

/// battery.watcher.new(fn) -> battery.watcher
/// Creates a battery watcher that can be started. When started, fn will be called each time a battery attribute changes.
static int battery_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    
    battery_watcher_t* watcher = lua_newuserdata(L, sizeof(battery_watcher_t));
    watcher->L = L;
    
    lua_pushvalue(L, 1);
    watcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    luaL_getmetatable(L, "battery_watcher");
    lua_setmetatable(L, -2);
    
    watcher->t = IOPSNotificationCreateRunLoopSource(callback, watcher);
    watcher->started = false;
    return 1;
}

/// battery.watcher:start() -> self
/// Starts the battery watcher, making it so fn is called each time a battery attribute changes.
static int battery_watcher_start(lua_State* L) {
    battery_watcher_t* watcher = luaL_checkudata(L, 1, "battery_watcher");
    
    lua_settop(L, 1);
    
    if (watcher->started) return 1;
    
    watcher->started = YES;
    
    watcher->self = hydra_store_handler(L, 1);
    CFRunLoopAddSource(CFRunLoopGetMain(), watcher->t, kCFRunLoopCommonModes);
    return 1;
}

/// battery.watcher:stop() -> self
/// Stops the battery watcher's fn from getting called until started again.
static int battery_watcher_stop(lua_State* L) {
    battery_watcher_t* watcher = luaL_checkudata(L, 1, "battery_watcher");
    lua_settop(L, 1);
    
    if (!watcher->started) return 1;
    watcher->started = NO;
    
    hydra_remove_handler(L, watcher->self);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), watcher->t, kCFRunLoopCommonModes);
    return 1;
}

/// battery.watcher.stopall()
/// Stops all running battery watchers; called automatically when user config reloads.
static int battery_watcher_stopall(lua_State* L) {
    lua_getglobal(L, "battery");
    lua_getfield(L, -1, "watcher");
    lua_getfield(L, -1, "stop");
    hydra_remove_all_handlers(L, "battery_watcher");
    return 0;
}

static int battery_watcher_gc(lua_State* L) {
    battery_watcher_t* watcher = luaL_checkudata(L, 1, "battery_watcher");
    
    luaL_unref(L, LUA_REGISTRYINDEX, watcher->fn);
    CFRunLoopSourceInvalidate(watcher->t);
    CFRelease(watcher->t);
    return 0;
}

static luaL_Reg battery_watcherlib[] = {
    {"new", battery_watcher_new},
    {"stop", battery_watcher_stop},
    {"stopall", battery_watcher_stopall},
    {"start", battery_watcher_start},
    {"__gc", battery_watcher_gc}
};

int luaopen_battery_watcher(lua_State* L) {
    luaL_newlib(L, battery_watcherlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "battery_watcher");
    
    return 1;
}
