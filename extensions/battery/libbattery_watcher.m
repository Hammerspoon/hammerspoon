#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

/// === hs.battery.watcher ===
///
/// Watch for battery/power state changes
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


// Common Code

#define USERDATA_TAG    "hs.battery.watcher"
static LSRefTable refTable;

// Not so common code

typedef struct _battery_watcher_t {
    CFRunLoopSourceRef t;
    int fn;
    bool started;
    LSGCCanary lsCanary;
} battery_watcher_t;

static void callback(void *info) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    battery_watcher_t* t = info;

    if (![skin checkGCCanary:t->lsCanary]) {
        return;
    }

    _lua_stackguard_entry(skin.L);

    if (t->fn != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:t->fn];
        [skin protectedCallAndError:@"hs.battery.watcher callback" nargs:0 nresults:0];
    }
    _lua_stackguard_exit(skin.L);
}

/// hs.battery.watcher.new(fn) -> watcher
/// Constructor
/// Creates a battery watcher
///
/// Parameters:
///  * A function that will be called when the battery state changes. The function should accept no arguments.
///
/// Returns:
///  * An `hs.battery.watcher` object
///
/// Notes:
///  * Because the callback function accepts no arguments, tracking of state of changing battery attributes is the responsibility of the user (see https://github.com/Hammerspoon/hammerspoon/issues/166 for discussion)
static int battery_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    battery_watcher_t* watcher = lua_newuserdata(L, sizeof(battery_watcher_t));

    lua_pushvalue(L, 1);
    watcher->fn = [skin luaRef:refTable];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    watcher->t = IOPSNotificationCreateRunLoopSource(callback, watcher);
    watcher->started = false;
    watcher->lsCanary = [skin createGCCanary];
    return 1;
}

/// hs.battery.watcher:start() -> self
/// Method
/// Starts the battery watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.battery.watcher` object
static int battery_watcher_start(lua_State* L) {
    battery_watcher_t* watcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_settop(L, 1);

    if (watcher->started) return 1;

    watcher->started = YES;

    CFRunLoopAddSource(CFRunLoopGetMain(), watcher->t, kCFRunLoopCommonModes);
    return 1;
}

/// hs.battery.watcher:stop() -> self
/// Method
/// Stops the battery watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.battery.watcher` object
static int battery_watcher_stop(lua_State* L) {
    battery_watcher_t* watcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!watcher->started) return 1;

    watcher->started = NO;
    CFRunLoopRemoveSource(CFRunLoopGetMain(), watcher->t, kCFRunLoopCommonModes);
    return 1;
}

static int battery_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    battery_watcher_t* watcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, battery_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    watcher->fn = [skin luaUnref:refTable ref:watcher->fn];
    [skin destroyGCCanary:&(watcher->lsCanary)];
    CFRunLoopSourceInvalidate(watcher->t);
    CFRelease(watcher->t);
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg battery_metalib[] = {
    {"start",   battery_watcher_start},
    {"stop",    battery_watcher_stop},
    {"__gc",    battery_watcher_gc},
    {"__tostring", userdata_tostring},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg batteryLib[] = {
    {"new",     battery_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_libbatterywatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:batteryLib metaFunctions:meta_gcLib objectFunctions:battery_metalib];

    return 1;
}
