#import "helpers.h"

/// === timer ===
///
/// Execute functions with various timing rules.

typedef struct _timer_t {
    lua_State* L;
    CFRunLoopTimerRef t;
    int fn;
    int self;
    BOOL started;
} timer_t;

static void callback(CFRunLoopTimerRef timer, void *info) {
    timer_t* t = info;
    lua_State* L = t->L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, t->fn);
    if (lua_pcall(L, 0, 0, 0))
        hydra_handle_error(L);
}

/// timer.doafter(sec, fn())
/// Runs the function after sec seconds.
static int timer_doafter(lua_State* L) {
    double delayInSeconds = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    });
    
    return 0;
}

/// timer.new(interval, fn) -> timer
/// Creates a new timer that can be started; interval is specified in seconds as a decimal number.
static int timer_new(lua_State* L) {
    NSTimeInterval sec = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    
    timer_t* timer = lua_newuserdata(L, sizeof(timer_t));
    memset(timer, 0, sizeof(timer_t));
    timer->L = L;
    
    lua_pushvalue(L, 2);
    timer->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    luaL_getmetatable(L, "timer");
    lua_setmetatable(L, -2);
    
    CFRunLoopTimerContext ctx = {0};
    ctx.info = timer;
    timer->t = CFRunLoopTimerCreate(NULL, 0, sec, 0, 0, callback, &ctx);
    
    return 1;
}

/// timer:start() -> self
/// Begins to execute timer.fn every timer.seconds; calling this does not cause an initial firing of the timer immediately.
static int timer_start(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, "timer");
    lua_settop(L, 1);
    
    if (timer->started) return 1;
    timer->started = YES;
    
    timer->self = hydra_store_handler(L, 1);
    CFRunLoopTimerSetNextFireDate(timer->t, CFAbsoluteTimeGetCurrent() + CFRunLoopTimerGetInterval(timer->t));
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// timer:stop() -> self
/// Stops the timer's fn from getting called until started again.
static int timer_stop(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, "timer");
    lua_settop(L, 1);
    
    if (!timer->started) return 1;
    timer->started = NO;
    
    hydra_remove_handler(L, timer->self);
    CFRunLoopRemoveTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// timer.stopall()
/// Stops all running timers; called automatically when user config reloads.
static int timer_stopall(lua_State* L) {
    lua_getglobal(L, "timer");
    lua_getfield(L, -1, "stop");
    hydra_remove_all_handlers(L, "timer");
    return 0;
}

static int timer_gc(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, "timer");
    luaL_unref(L, LUA_REGISTRYINDEX, timer->fn);
    CFRunLoopTimerInvalidate(timer->t);
    CFRelease(timer->t);
    return 0;
}

static const luaL_Reg timerlib[] = {
    // class methods
    {"doafter", timer_doafter},
    {"stopall", timer_stopall},
    {"new", timer_new},
    
    // instance methods
    {"start", timer_start},
    {"stop", timer_stop},
    
    // metamethods
    {"__gc", timer_gc},
    
    {NULL, NULL}
};

int luaopen_timer(lua_State* L) {
    luaL_newlib(L, timerlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "timer");
    
    return 1;
}
