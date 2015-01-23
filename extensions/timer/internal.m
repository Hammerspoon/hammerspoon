#import <Cocoa/Cocoa.h>
#import <lauxlib.h>


// Common Code

#define USERDATA_TAG    "hs.timer"

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

static NSMutableIndexSet* timerHandlers;

typedef struct _timer_t {
    lua_State* L;
    CFRunLoopTimerRef t;
    int fn;
    int self;
    BOOL started;
} timer_t;

static void callback(CFRunLoopTimerRef __unused timer, void *info) {
    timer_t* t = info;
    lua_State* L = t->L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, t->fn);
    if (lua_pcall(L, 0, 0, -2) != LUA_OK) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }

}

/// hs.timer.new(interval, fn) -> timer
/// Constructor
/// Creates a new timer that can be started; interval is specified in seconds as a decimal number.
static int timer_new(lua_State* L) {
    NSTimeInterval sec = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    timer_t* timer = lua_newuserdata(L, sizeof(timer_t));
    memset(timer, 0, sizeof(timer_t));
    timer->L = L;

    lua_pushvalue(L, 2);
    timer->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    CFRunLoopTimerContext ctx = {0, timer, NULL, NULL, NULL};
//    ctx.info = timer;
    timer->t = CFRunLoopTimerCreate(NULL, 0, sec, 0, 0, callback, &ctx);

    return 1;
}

/// hs.timer:start() -> self
/// Method
/// Begins to execute hs.timer.fn every N seconds, as defined when the timer was created; calling this does not cause an initial firing of the timer immediately.
static int timer_start(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (timer->started) return 1;
    timer->started = YES;

    timer->self = store_udhandler(L, timerHandlers, 1);
    CFRunLoopTimerSetNextFireDate(timer->t, CFAbsoluteTimeGetCurrent() + CFRunLoopTimerGetInterval(timer->t));
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// hs.timer.doAfter(sec, fn)
/// Function
/// Runs the function after sec seconds.
static int timer_doAfter(lua_State* L) {
    NSTimeInterval sec = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    timer_t* timer = lua_newuserdata(L, sizeof(timer_t));
    memset(timer, 0, sizeof(timer_t));
    timer->L = L;

    lua_pushvalue(L, 2);
    timer->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    CFRunLoopTimerContext ctx = {0, timer, NULL, NULL, NULL};
//    ctx.info = timer;
    timer->t = CFRunLoopTimerCreate(NULL, 0, 0, 0, 0, callback, &ctx);
    timer->started = YES;
    timer->self = store_udhandler(L, timerHandlers, 1);

    CFRunLoopTimerSetNextFireDate(timer->t, CFAbsoluteTimeGetCurrent() + sec);
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// hs.timer:stop() -> self
/// Method
/// Stops the timer's fn from getting called until started again.
static int timer_stop(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!timer->started) return 1;
    timer->started = NO;

    remove_udhandler(L, timerHandlers, timer->self);
    CFRunLoopRemoveTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

static int timer_gc(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    luaL_unref(L, LUA_REGISTRYINDEX, timer->fn);
    CFRunLoopTimerInvalidate(timer->t);
    CFRelease(timer->t);
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [timerHandlers removeAllIndexes];
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg timer_metalib[] = {
    {"start",   timer_start},
    {"stop",    timer_stop},
    {"__gc",    timer_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg timerLib[] = {
    {"doAfter",    timer_doAfter},
    {"new",        timer_new},
    {NULL,          NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_timer_internal(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, timer_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, timerLib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
