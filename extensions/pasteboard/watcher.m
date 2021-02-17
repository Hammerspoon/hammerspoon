#import <LuaSkin/LuaSkin.h>

/// === hs.pasteboard.watcher ===
///
/// Watch for Pasteboard Changes.
/// macOS doesn't offer any API for getting Pasteboard notifications, so this extension uses polling to check for Pasteboard changes at a chosen interval (defaults to 0.25).

static const char *USERDATA_TAG = "hs.pasteboard.watcher";
static LSRefTable refTable;

// How often we should poll the Pasteboard for changes:
static double pollingInterval = 0.25;

// We only use a single NSTimer for all Pasteboard Watchers:
static int sharedPasteboardTimerCount = 0;
NSTimer *sharedPasteboardTimer;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

@interface HSPasteboardTimer : NSObject
@property NSTimer *t;
@property NSString *pbName;
@property int fnRef;
@property NSInteger changeCount;
@property BOOL isRunning;
- (void)start;
- (void)stop;
@end

@implementation HSPasteboardTimer

- (void)sharedPasteboardTimerCallback:(NSTimer *)timer {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"sharedPasteboardNotification"
        object:nil];
}

- (void)sharedPasteboardChanged:(NSNotification*)notification {
    // Get the correct Pasteboard:
    NSPasteboard *pb;
    if (self.pbName) {
        pb = [NSPasteboard pasteboardWithName:self.pbName];
    } else {
        pb = [NSPasteboard generalPasteboard];
    }

    // Check if the Pasteboard Change Count has changed:
    NSInteger currentChangeCount = [pb changeCount];
    if(currentChangeCount == self.changeCount) {
        return;
    }

    // Update change count:
    self.changeCount = currentChangeCount;

    // Trigger Lua Callback Function:
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);

    [skin pushLuaRef:refTable ref:self.fnRef];

    NSString *result = [pb stringForType:NSPasteboardTypeString];
    if (result) {
        [skin pushNSObject:result];
    } else {
        lua_pushnil(skin.L);
    }

    if (![skin protectedCallAndTraceback:1 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logBreadcrumb:[NSString stringWithFormat:@"hs.pasteboard.watcher callback error: %s", errorMsg]];
        [skin logError:[NSString stringWithFormat:@"hs.pasteboard.watcher callback error: %s", errorMsg]];
        lua_pop(skin.L, 1); // clear error message from stack
    }

    _lua_stackguard_exit(skin.L);
}

- (void)start {
    // Abort if the watcher is already running:
    if (self.isRunning) {
        return;
    }

    // If the Shared Pasteboard Timer doesn't exist, create it:
    if (!sharedPasteboardTimer.isValid) {
        sharedPasteboardTimer = [NSTimer timerWithTimeInterval:pollingInterval target:self selector:@selector(sharedPasteboardTimerCallback:) userInfo:nil repeats:YES];
    }

    // Update Initial Change Count:
    NSPasteboard *pb;
    if (self.pbName) {
        pb = [NSPasteboard pasteboardWithName:self.pbName];
    } else {
        pb = [NSPasteboard generalPasteboard];
    }
    self.changeCount = [pb changeCount];

    // Start the Shared Pasteboard NSTimer if it's not already running:
    if (!CFRunLoopContainsTimer(CFRunLoopGetCurrent(), (__bridge CFRunLoopTimerRef)sharedPasteboardTimer, kCFRunLoopDefaultMode)) {
        [[NSRunLoop currentRunLoop] addTimer:sharedPasteboardTimer forMode:NSRunLoopCommonModes];
    }

    // Increment the General Pasteboard Timer Counter:
    sharedPasteboardTimerCount++;

    // Add observer:
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sharedPasteboardChanged:)
                                                 name:@"sharedPasteboardNotification" object:nil];

    // The watcher is now running:
    self.isRunning = YES;
}

- (void)stop {
    // Remove observer:
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"sharedPasteboardNotification"
                                                  object:nil];

    // Decrement the Shared Pasteboard Timer Counter:
    sharedPasteboardTimerCount--;

    // If no more watchers are left, destroy the NSTimer:
    if (sharedPasteboardTimerCount == 0) {
        [sharedPasteboardTimer invalidate];
        sharedPasteboardTimer = nil;
    }

    // Watcher is no longer running:
    self.isRunning = NO;
}
@end

HSPasteboardTimer *createHSPasteboardTimer(int callbackRef, NSString *pbName) {
    HSPasteboardTimer *timer = [[HSPasteboardTimer alloc] init];
    timer.fnRef = callbackRef;
    timer.pbName = pbName;
    return timer;
}

/// hs.pasteboard.watcher.new(callbackFn[, name]) -> pasteboardWatcher
/// Constructor
/// Creates and starts a new `hs.pasteboard.watcher` object for watching for Pasteboard changes.
///
/// Parameters:
///  * callbackFn - A function that will be called when the Pasteboard contents has changed. It should accept one parameter:
///   * A string containing the pasteboard contents or `nil` if the contents is not a valid string.
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard.
///
/// Returns:
///  * An `hs.pasteboard.watcher` object
///
/// Notes:
///  * Internally this extension uses a single `NSTimer` to check for changes to the pasteboard count every half a second.
///  * Example usage:
///  ```lua
///  generalPBWatcher = hs.pasteboard.watcher.new(function(v) print(string.format("General Pasteboard Contents: %s", v)) end)
///  specialPBWatcher = hs.pasteboard.watcher.new(function(v) print(string.format("Special Pasteboard Contents: %s", v)) end, "special")
///  hs.pasteboard.writeObjects("This is on the general pasteboard.")
///  hs.pasteboard.writeObjects("This is on the special pasteboard.", "special")
///  ```
static int pasteboardwatcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString *pbName = [skin toNSObjectAtIndex:2];

    lua_pushvalue(L, 1);
    int callbackRef = [skin luaRef:refTable];

    // Create the timer object:
    HSPasteboardTimer *timer = createHSPasteboardTimer(callbackRef, pbName);

    // Start the timer:
    [timer start];

    // Wire up the timer object to Lua:
    void **userData = lua_newuserdata(L, sizeof(HSPasteboardTimer*));
    *userData = (__bridge_retained void*)timer;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.pasteboard.watcher:start() -> timer
/// Method
/// Starts an `hs.pasteboard.watcher` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.pasteboard.watcher` object
static int pasteboardwatcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSPasteboardTimer* timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    // Start the timer:
    [timer start];

    return 1;
}

/// hs.pasteboard.watcher:running() -> boolean
/// Method
/// Returns a boolean indicating whether or not the Pasteboard Watcher is currently running.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean value indicating whether or not the timer is currently running.
static int pasteboardwatcher_running(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);

    lua_pushboolean(L, timer.isRunning);

    return 1;
}

/// hs.pasteboard.watcher:stop() -> timer
/// Method
/// Stops an `hs.pasteboard.watcher` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.pasteboard.watcher` object
static int pasteboardwatcher_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    // Stop the timer:
    [timer stop];

    return 1;
}

/// hs.pasteboard.watcher.interval([value]) -> number
/// Function
/// Gets or sets the polling interval (i.e. the frequency the pasteboard watcher checks the pasteboard).
///
/// Parameters:
///  * value - an optional number to set the polling interval to.
///
/// Returns:
///  * The polling interval as a number.
///
/// Notes:
///  * This only affects new watchers, not existing/running ones.
///  * The default value is 0.25.
static int pasteboardwatcher_interval(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 1) {
        pollingInterval = lua_tonumber(L, 1);
    }
    lua_pushnumber(L, pollingInterval);
    return 1 ;
}

static int pasteboardwatcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge_transfer HSPasteboardTimer, L, 1, USERDATA_TAG);

    if (timer) {
        [timer stop];
        timer.fnRef = [skin luaUnref:refTable ref:timer.fnRef];
        timer.t = nil;
        timer.pbName = nil;
        timer = nil;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    if (sharedPasteboardTimer) {
        [sharedPasteboardTimer invalidate] ;
        sharedPasteboardTimer = nil ;
    }
    return 0;
}

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    NSString* title ;

    if (timer.isRunning) {
        title = @"running";
    } else {
        title = @"not running";
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg pasteboardWatcher_metalib[] = {
    {"start",       pasteboardwatcher_start},
    {"stop",        pasteboardwatcher_stop},
    {"running",     pasteboardwatcher_running},
    {"__tostring",  userdata_tostring},
    {"__gc",        pasteboardwatcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg pasteboardWatcher_lib[] = {
    {"new",         pasteboardwatcher_new},
    {"interval",    pasteboardwatcher_interval},
    {NULL,          NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_watcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:pasteboardWatcher_lib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:pasteboardWatcher_metalib];
    return 1;
}
