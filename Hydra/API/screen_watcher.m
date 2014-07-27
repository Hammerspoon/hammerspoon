#import "helpers.h"

@interface HydraScreenWatcher : NSObject
@property lua_State* L;
@property int fn;
@end

@implementation HydraScreenWatcher
- (void) screensChanged:(id)bla {
    lua_State* L = self.L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    if (lua_pcall(L, 0, 0, 0))
        hydra_handle_error(L);
}
@end


typedef struct _screenwatcher_t {
    bool running;
    int fn;
    void* obj;
} screenwatcher_t;

/// screen.watcher.new(fn) -> watcher
/// Creates a new screen-watcher that can be started; fn will be called when your screen layout changes in any way, whether by adding/removing/moving monitors or like whatever.
static int screen_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    
    screenwatcher_t* screenwatcher = lua_newuserdata(L, sizeof(screenwatcher_t));
    memset(screenwatcher, 0, sizeof(screenwatcher_t));
    
    lua_pushvalue(L, 1);
    screenwatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    HydraScreenWatcher* object = [[HydraScreenWatcher alloc] init];
    object.L = L;
    object.fn = screenwatcher->fn;
    screenwatcher->obj = (__bridge_retained void*)object;
    
    luaL_getmetatable(L, "screen_watcher");
    lua_setmetatable(L, -2);
    
    return 1;
}

static int screen_watcher_start(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, "screen_watcher");
    
    if (screenwatcher->running) return 0;
    screenwatcher->running = true;
    
    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)screenwatcher->obj
                                             selector:@selector(screensChanged:)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];
    
    return 0;
}

static int screen_watcher_stop(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, "screen_watcher");
    
    if (!screenwatcher->running) return 0;
    screenwatcher->running = false;
    
    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)screenwatcher->obj];
    
    return 0;
}

static int screen_watcher_stopall(lua_State* L) {
    lua_getglobal(L, "screen");
    lua_getfield(L, -1, "watcher");
    lua_getfield(L, -1, "stop");
    hydra_remove_all_handlers(L, "screen_watcher");
    return 0;
}

static int screen_watcher_gc(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, "screen_watcher");
    
    luaL_unref(L, LUA_REGISTRYINDEX, screenwatcher->fn);
    
    HydraScreenWatcher* object = (__bridge_transfer id)screenwatcher->obj;
    object = nil;
    
    return 0;
}

static luaL_Reg screen_watcherlib[] = {
    {"new", screen_watcher_new},
    {"start", screen_watcher_start},
    {"stop", screen_watcher_stop},
    {"stopall", screen_watcher_stopall},
    {"__gc", screen_watcher_gc},
    {}
};

int luaopen_screen_watcher(lua_State* L) {
    luaL_newlib(L, screen_watcherlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "screen_watcher");
    
    return 1;
}
