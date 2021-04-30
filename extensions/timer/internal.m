@import Cocoa;
@import Darwin.POSIX.sys.time;
#import <LuaSkin/LuaSkin.h>

// Common Code

static const char *USERDATA_TAG = "hs.timer";
static LSRefTable refTable;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

// Not so common code

@interface HSTimer : NSObject
@property NSTimer *t;
@property int fnRef;
@property BOOL continueOnError;
@property BOOL repeats;
@property NSTimeInterval interval;
@property LSGCCanary lsCanary;

- (void)create:(NSTimeInterval)interval repeat:(BOOL)repeat;
- (void)callback:(NSTimer *)timer;
- (BOOL)isRunning;
- (void)start;
- (void)stop;
- (double)nextTrigger;
- (void)setNextTrigger:(NSTimeInterval)interval;
- (void)trigger;
@end

@implementation HSTimer
- (void)create:(NSTimeInterval)interval repeat:(BOOL)repeat {
    self.t = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(callback:) userInfo:nil repeats:repeat];
}

- (void)callback:(NSTimer *)timer {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    if (![skin checkGCCanary:self.lsCanary]) {
        return;
    }

    _lua_stackguard_entry(skin.L);

    if (!timer.isValid) {
        [skin logBreadcrumb:@"hs.timer callback fired on an invalid hs.timer object. This is a bug"];
        _lua_stackguard_exit(skin.L);
        return;
    }

    if (timer != self.t) {
        [skin logBreadcrumb:@"hs.timer callback fired with inconsistencies about which NSTimer object it owns. This is a bug"];
    }

    [skin pushLuaRef:refTable ref:self.fnRef];
    if (![skin protectedCallAndTraceback:0 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logBreadcrumb:[NSString stringWithFormat:@"hs.timer callback error: %s", errorMsg]];
        [skin logError:[NSString stringWithFormat:@"hs.timer callback error: %s", errorMsg]];
        lua_pop(skin.L, 1); // clear error message from stack
        if (!self.continueOnError) {
            // some details about the timer to help identify which one it is:
            [skin logBreadcrumb:@"hs.timer callback failed. The timer has been stopped to prevent repeated notifications of the error."];
            [skin logBreadcrumb:[NSString stringWithFormat:@"  timer details: %s repeating, every %f seconds, next scheduled at %@", CFRunLoopTimerDoesRepeat((__bridge CFRunLoopTimerRef)timer) ? "is" : "is not", self.interval, timer.fireDate]];
            [self.t invalidate];
        }
    }
    _lua_stackguard_exit(skin.L);
}

- (BOOL)isRunning {
    return CFRunLoopContainsTimer(CFRunLoopGetCurrent(), (__bridge CFRunLoopTimerRef)self.t, kCFRunLoopDefaultMode);
}

- (void)start {
    if (!self.t.isValid) {
        // We've previously been stopped, which means the NSTimer is invalid, so recreate it
        [self create:self.interval repeat:self.repeats];
    }

    [self setNextTrigger:self.interval];
    [[NSRunLoop currentRunLoop] addTimer:self.t forMode:NSRunLoopCommonModes];
}

- (void)stop {
    if (self.t.isValid) {
        [self.t invalidate];
    }
}

- (double)nextTrigger {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime next = CFRunLoopTimerGetNextFireDate((__bridge CFRunLoopTimerRef)self.t);

    return (next - now);
}

- (void)setNextTrigger:(NSTimeInterval)interval {
    if (self.t.isValid) {
        self.t.fireDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    }
}

- (void)trigger {
    if (self.t.isValid) {
        [self.t fire];
    }
}
@end

HSTimer *createHSTimer(NSTimeInterval interval, int callbackRef, BOOL continueOnError, BOOL repeat) {
    HSTimer *timer = [[HSTimer alloc] init];
    timer.fnRef = callbackRef;
    timer.continueOnError = continueOnError;
    timer.repeats = repeat;
    timer.interval = interval;
    [timer create:interval repeat:repeat];

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    // NOTE: The stringWithString call here is vital, so we get a true copy of UUIDString - we must not simply point at it, or we'll never be able to use it to detect an inconsistency later.
    timer.lsCanary = [skin createGCCanary];

    return timer;
}

/// hs.timer.new(interval, fn [, continueOnError]) -> timer
/// Constructor
/// Creates a new `hs.timer` object for repeating interval callbacks
///
/// Parameters:
///  * interval - A number of seconds between firings of the timer
///  * fn - A function to call every time the timer fires
///  * continueOnError - An optional boolean, true if the timer should continue to be triggered after the callback function has produced an error, false if the timer should stop being triggered after the callback function has produced an error. Defaults to false.
///
/// Returns:
///  * An `hs.timer` object
///
/// Notes:
///  * The returned object does not start its timer until its `:start()` method is called
///  * If `interval` is 0, the timer will not repeat (because if it did, it would be repeating as fast as your machine can manage, which seems generally unwise)
///  * For non-zero intervals, the lowest acceptable value for the interval is 0.00001s. Values >0 and <0.00001 will be coerced to 0.00001
static int timer_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TFUNCTION, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    // Fetch the timer configuration from Lua arguments
    NSTimeInterval sec = lua_tonumber(L, 1);
    if (sec > 0 && sec < 0.00001) {
        [skin logInfo:@"Minimum non-zero hs.timer interval is 0.00001s. Forcing to 0.00001"];
        sec = 0.00001;
    }
    lua_pushvalue(L, 2);
    int callbackRef = [skin luaRef:refTable];

    BOOL continueOnError;
    if (lua_isboolean(L, 3))
        continueOnError = lua_toboolean(L, 3) ;
    else
        continueOnError = NO ;

    BOOL shouldRepeat = YES;
    if (sec == 0.0)
        shouldRepeat = NO;

    // Create the timer object
    HSTimer *timer = createHSTimer(sec, callbackRef, continueOnError, shouldRepeat);

    // Wire up the timer object to Lua
    void **userData = lua_newuserdata(L, sizeof(HSTimer*));
    *userData = (__bridge_retained void*)timer;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

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
///  * The timer will not call the callback immediately, the timer will wait until it fires
///  * If the callback function results in an error, the timer will be stopped to prevent repeated error notifications (see the `continueOnError` parameter to `hs.timer.new()` to override this)
static int timer_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSTimer* timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (![timer isRunning])
        [timer start];

    return 1;
}

/// hs.timer.doAfter(sec, fn) -> timer
/// Constructor
/// Calls a function after a delay
///
/// Parameters:
///  * sec - A number of seconds to wait before calling the function
///  * fn - A function to call
///
/// Returns:
///  * An `hs.timer` object
///
/// Notes:
///  * There is no need to call `:start()` on the returned object, the timer will be already running.
///  * The callback can be cancelled by calling the `:stop()` method on the returned object before `sec` seconds have passed.
static int timer_doAfter(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TFUNCTION, LS_TBREAK];

    // Fetch the timer configuration from Lua arguments
    NSTimeInterval sec = lua_tonumber(L, 1);
    lua_pushvalue(L, 2);
    int callbackRef = [skin luaRef:refTable];

    // Create the timer object
    HSTimer *timer = createHSTimer(sec, callbackRef, NO, NO);

    // Immediately start it
    [timer start];

    // Wire up the timer object to Lua
    void **userData = lua_newuserdata(L, sizeof(HSTimer*));
    *userData = (__bridge_retained void*)timer;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

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
///  * Use of this function is strongly discouraged, as it blocks all main-thread execution in Hammerspoon. This means no hotkeys or events will be processed in that time, no GUI updates will happen, and no Lua will execute. This is only provided as a last resort, or for extremely short sleeps. For all other purposes, you really should be splitting up your code into multiple functions and calling `hs.timer.doAfter()`
static int timer_usleep(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];
    useconds_t microsecs = (useconds_t)lua_tointeger(L, 1);
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
///  * A boolean value indicating whether or not the timer is currently running.
static int timer_running(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);

    lua_pushboolean(L, [timer isRunning]);

    return 1;
}

/// hs.timer:nextTrigger() -> number
/// Method
/// Returns the number of seconds until the timer will next trigger
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of seconds until the next firing
///
/// Notes:
///  * The return value may be a negative integer in two circumstances:
///   * Hammerspoon's runloop is backlogged and is catching up on missed timer triggers
///   * The timer object is not currently running. In this case, the return value of this method is the number of seconds since the last firing (you can check if the timer is running or not, with `hs.timer:running()`
static int timer_nextTrigger(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);

    lua_pushnumber(L, [timer nextTrigger]);

    return 1;
}

/// hs.timer:setNextTrigger(seconds) -> timer
/// Method
/// Sets the next trigger time of a timer
///
/// Parameters:
///  * seconds - A number of seconds after which to trigger the timer
///
/// Returns:
///  * The `hs.timer` object, or nil if an error occurred
///
/// Notes:
///  * If the timer is not already running, this will start it
static int timer_setNextTrigger(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);

    NSTimeInterval seconds = (NSTimeInterval)lua_tonumber(L, 2);

    if (![timer isRunning]) {
        [timer start];
    }

    [timer setNextTrigger:seconds];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.timer:fire() -> timer
/// Method
/// Immediately fires a timer
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.timer` object
///
/// Notes:
///  * This cannot be used on a timer which has already stopped running
static int timer_trigger(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);

    [timer trigger];

    lua_pushvalue(L, 1);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    [timer stop];

    return 1;
}

static int timer_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSTimer *timer = get_objectFromUserdata(__bridge_transfer HSTimer, L, 1, USERDATA_TAG);

    if (timer) {
        [timer stop];
        timer.fnRef = [skin luaUnref:refTable ref:timer.fnRef];
        timer.t = nil;

        LSGCCanary tmpLSUUID = timer.lsCanary;
        [skin destroyGCCanary:&tmpLSUUID];
        timer.lsCanary = tmpLSUUID;

        timer = nil;
    }

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSTimer *timer = get_objectFromUserdata(__bridge HSTimer, L, 1, USERDATA_TAG);
    NSString* title ;

    if (!timer.t) {
        title = @"BUG ENCOUNTERED, hs.timer tostring found timer.t nil";
    } else if ([timer isRunning]) {
        title = @"running";
    } else {
        title = @"not running";
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

/// hs.timer.secondsSinceEpoch() -> sec
/// Function
/// Gets the (fractional) number of seconds since the UNIX epoch (January 1, 1970)
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of seconds since the epoch
///
/// Notes:
///  * This has much better precision than `os.time()`, which is limited to whole seconds.
static int timer_getSecondsSinceEpoch(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    /* Unix Epoch time (time since January 1, 1970 (UTC)) */
    lua_pushnumber(L, v.tv_sec + v.tv_usec/1.0e6);
    return 1;
}

/// hs.timer.absoluteTime() -> nanoseconds
/// Function
/// Returns the absolute time in nanoseconds since the last system boot.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the time since the last system boot in nanoseconds
///
/// Notes:
///  * this value does not include time that the system has spent asleep
///  * this value is used for the timestamps in system generated events.
static int timer_absoluteTime(lua_State *L) {
    // timebase on systems I've seen has always been 1/1, but just in case that changes:
    mach_timebase_info_data_t timebase ;
    mach_timebase_info(&timebase) ;
    uint64_t absTime = mach_absolute_time() ;
    lua_pushinteger(L, (lua_Integer)((absTime * timebase.numer) / timebase.denom)) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg timer_metalib[] = {
    {"start",   timer_start},
    {"stop",    timer_stop},
    {"running", timer_running},
    {"nextTrigger", timer_nextTrigger},
    {"setNextTrigger", timer_setNextTrigger},
    {"fire", timer_trigger},
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
    {"absoluteTime", timer_absoluteTime},
    {NULL,          NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_timer_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:timerLib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:timer_metalib];

    return 1;
}
