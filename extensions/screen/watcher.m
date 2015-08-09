#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

/// === hs.screen.watcher ===
///
/// Watch for screen layout changes
/// This could be the addition or removal of a monitor, a screen resolution change, movement of a monitor in the Display preferences pane, etc.
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


// Common Code

#define USERDATA_TAG    "hs.screen.watcher"

// Not so common code

@interface MJScreenWatcher : NSObject
@property lua_State* L;
@property int fn;
@end

@implementation MJScreenWatcher
- (void) _screensChanged:(id __unused)bla {
    [self performSelectorOnMainThread:@selector(screensChanged:)
                                        withObject:nil
                                        waitUntilDone:YES];
}

- (void) screensChanged:(id __unused)bla {
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


typedef struct _screenwatcher_t {
    bool running;
    int fn;
    void* obj;
} screenwatcher_t;

// 10/28/14 3:19:40.825 AM WindowServer[244]: CGError post_notification(const CGSNotificationType, void *const, const size_t, const bool, const CGSRealTimeDelta, const int, const CGSConnectionID *const, const pid_t): Timed out 0.250 second wait for reply from "Hammerspoon" for synchronous notification type 100 (kCGSDisplayWillReconfigure) (CID 0x458bb, PID 80899)


/// hs.screen.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new screen-watcher that can be started; fn will be called when your screen layout changes in any way, whether by adding, removing, or moving a display device.
static int screen_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    screenwatcher_t* screenwatcher = lua_newuserdata(L, sizeof(screenwatcher_t));
    memset(screenwatcher, 0, sizeof(screenwatcher_t));

    lua_pushvalue(L, 1);
    screenwatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    MJScreenWatcher* object = [[MJScreenWatcher alloc] init];
    object.L = L;
    object.fn = screenwatcher->fn;
    screenwatcher->obj = (__bridge_retained void*)object;
    screenwatcher->running = NO;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.screen.watcher:start() -> watcher
/// Function
/// Starts the screen watcher, making it so fn is called each time the screen arrangement changes.
static int screen_watcher_start(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (screenwatcher->running) return 1;
    screenwatcher->running = YES;

    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)screenwatcher->obj
                                             selector:@selector(_screensChanged:)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];

    return 1;
}

/// hs.screen.watcher:stop() -> watcher
/// Function
/// Stops the screen watcher's fn from getting called until started again.
static int screen_watcher_stop(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (!screenwatcher->running) return 1;
    screenwatcher->running = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)screenwatcher->obj
                                                    name:NSApplicationDidChangeScreenParametersNotification
                                                  object:nil];

    return 1;
}

static int screen_watcher_gc(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, screen_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    luaL_unref(L, LUA_REGISTRYINDEX, screenwatcher->fn);
    screenwatcher->fn = LUA_NOREF;

    MJScreenWatcher* object = (__bridge_transfer id)screenwatcher->obj;
    object = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg screen_metalib[] = {
    {"start",   screen_watcher_start},
    {"stop",    screen_watcher_stop},
    {"__gc",    screen_watcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg screenLib[] = {
    {"new",     screen_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_screen_watcher(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, screen_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, screenLib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
