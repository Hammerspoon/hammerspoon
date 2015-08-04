#import <Cocoa/Cocoa.h>
#import <sys/time.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// Common Code

#define USERDATA_TAG    "hs.timer"

// Not so common code

typedef struct _timer_t {
    lua_State* L;
    CFRunLoopTimerRef t;
    int fn;
    BOOL started;
} timer_t;

static void callback(CFRunLoopTimerRef __unused timer, void *info) {
    timer_t* t = info;
    lua_State* L = t->L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, t->fn);
    if (lua_pcall(L, 0, 0, -2) != LUA_OK) {
        CLS_NSLOG(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }

}

/// hs.timer.new(interval, fn) -> timer
/// Constructor
/// Creates a new `hs.timer` object for repeating interval callbacks
///
/// Parameters:
///  * interval - A number of seconds between triggers
///  * fn - A function to call every time the timer triggers
///
/// Returns:
///  * An `hs.timer` object
///
/// Notes:
///  * The returned object does not start its timer until its `:start()` method is called
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

/// hs.timer:start() -> timer
/// Method
/// Starts an `hs.timer` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.timer` object
///
/// Notes:
///  * The timer will not call the callback immediately, it waits until the first trigger of the timer
static int timer_start(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (timer->started) return 1;
    timer->started = YES;

    CFRunLoopTimerSetNextFireDate(timer->t, CFAbsoluteTimeGetCurrent() + CFRunLoopTimerGetInterval(timer->t));
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// hs.timer.doAfter(sec, fn) -> timer
/// Constructor
/// Calls a function after a delay
///
/// Parameters:
///  * sec - A number of seconds to wait before calling the function
///  * fn - The function to call
///
/// Returns:
///  * An `hs.timer` object
///
/// Notes:
///  * The callback can be cancelled by calling the `:stop()` method on the returned object before `sec` seconds have passed.
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

    CFRunLoopTimerSetNextFireDate(timer->t, CFAbsoluteTimeGetCurrent() + sec);
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

/// hs.timer.usleep(microsecs)
/// Function
/// Blocks Lua execution for the specified time
///
/// Parameters:
///  * microsecs - A number containing a time in microseconds to block for
///
/// Returns:
///  * None
///
/// Notes:
///  * Use of this function is strongly discouraged, as it blocks all main-thread execution in Hammerspoon. This means no hotkeys or events will be processed in that time. This is only provided as a last resort, or for extremely short sleeps. For all other purposes, you really should be splitting up your code into multiple functions and calling `hs.timer.doAfter()`
static int timer_usleep(lua_State* L) {
    int microsecs = lua_tointeger(L, 1);
    usleep(microsecs);

    return 0;
}

/// hs.timer:running() -> boolean
/// Method
/// Returns a boolean indicating whether or not the timer is currently running.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not the timer is currently running.
static int timer_running(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushboolean(L, CFRunLoopContainsTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes));
    return 1;
}

/// hs.timer:stop() -> timer
/// Method
/// Stops an `hs.timer` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.timer` object
static int timer_stop(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!timer->started) return 1;
    timer->started = NO;

    CFRunLoopRemoveTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes);
    return 1;
}

static int timer_gc(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    if (timer && timer->fn != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, timer->fn);
        timer->started = NO;
        timer->fn = LUA_NOREF;
        CFRunLoopTimerInvalidate(timer->t);
        CFRelease(timer->t);
    }
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    timer_t* timer = luaL_checkudata(L, 1, USERDATA_TAG);
    NSString* title ;

    if (CFRunLoopContainsTimer(CFRunLoopGetMain(), timer->t, kCFRunLoopCommonModes))
        title = @"running" ;
    else
        title = @"stopped";

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

/// hs.timer.secondsSinceEpoch() -> sec
/// Function
/// Gets the number of seconds since the epoch, including the fractional part; this has much better precision than `os.time()`, which is limited to whole seconds.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of seconds since the epoch
static int timer_getSecondsSinceEpoch(lua_State *L)
{
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    /* Unix Epoch time (time since January 1, 1970 (UTC)) */
    lua_pushnumber(L, v.tv_sec + v.tv_usec/1.0e6);
    return 1;
}


// Metatable for created objects when _new invoked
static const luaL_Reg timer_metalib[] = {
    {"start",   timer_start},
    {"stop",    timer_stop},
    {"running", timer_running},
    {"__tostring", userdata_tostring},
    {"__gc",    timer_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg timerLib[] = {
    {"doAfter",    timer_doAfter},
    {"new",        timer_new},
    {"usleep",     timer_usleep},
    {"secondsSinceEpoch",       timer_getSecondsSinceEpoch},
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
