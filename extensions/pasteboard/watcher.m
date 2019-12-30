#import <LuaSkin/LuaSkin.h>

/// === hs.pasteboard.watcher ===
///
/// Watch for Pasteboard Changes.
/// Sadly, macOS currently doesn't have any API for getting Pasteboard notifications, so this extension uses polling every half a second.

// TODO: * Ideally there should be a single Pasteboard NSTimer for the general pasteboard and each unique pasteboard name.
//       * Investigate using Grand Central Dispatch instead of an NSTimer.

static const char *USERDATA_TAG = "hs.pasteboard.watcher";
static int refTable;

const int POLLING_INTERVAL = 0.5;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

@interface HSPasteboardTimer : NSObject
@property NSTimer *t;
@property NSString *pbName;
@property int fnRef;
@property NSInteger changeCount;
- (void)create;
- (void)callback:(NSTimer *)timer;
- (BOOL)isRunning;
- (void)start;
- (void)stop;
@end

@implementation HSPasteboardTimer
- (void)create {
    self.t = [NSTimer timerWithTimeInterval:POLLING_INTERVAL target:self selector:@selector(callback:) userInfo:nil repeats:YES];
}

- (void)callback:(NSTimer *)timer {
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
        self.changeCount = currentChangeCount;
        return;
    } else {
        self.changeCount = currentChangeCount;
    }

    LuaSkin *skin = [LuaSkin shared];
    _lua_stackguard_entry(skin.L);

    if (!timer.isValid) {
        [skin logBreadcrumb:@"hs.pasteboard.watcher callback fired on an invalid hs.pasteboard.watcher object. This is a bug"];
        _lua_stackguard_exit(skin.L);
        return;
    }

    if (timer != self.t) {
        [skin logBreadcrumb:@"hs.pasteboard.watcher callback fired with inconsistencies about which NSTimer object it owns. This is a bug"];
    }
    
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

- (BOOL)isRunning {
    return CFRunLoopContainsTimer(CFRunLoopGetCurrent(), (__bridge CFRunLoopTimerRef)self.t, kCFRunLoopDefaultMode);
}

- (void)start {
    if (!self.t.isValid) {
        // We've previously been stopped, which means the NSTimer is invalid, so recreate it
        [self create];
    }
    NSPasteboard *pb;
    if (self.pbName) {
        pb = [NSPasteboard pasteboardWithName:self.pbName];
    } else {
        pb = [NSPasteboard generalPasteboard];
    }
    self.changeCount = [pb changeCount];
    [[NSRunLoop currentRunLoop] addTimer:self.t forMode:NSRunLoopCommonModes];
}

- (void)stop {
    if (self.t.isValid) {
        [self.t invalidate];
    }
}
@end

HSPasteboardTimer *createHSPasteboardTimer(int callbackRef, NSString *pbName) {
    HSPasteboardTimer *timer = [[HSPasteboardTimer alloc] init];
    timer.fnRef = callbackRef;
    timer.pbName = pbName;
    [timer create];
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
///  * Example usage:
///  ```lua
///  generalPBWatcher = hs.pasteboard.watcher.new(function(v) print(string.format("General Pasteboard Contents: %s", v)) end)
///  specialPBWatcher = hs.pasteboard.watcher.new(function(v) print(string.format("Special Pasteboard Contents: %s", v)) end, "special")
///  hs.pasteboard.writeObjects("This is on the general pasteboard.")
///  hs.pasteboard.writeObjects("This is on the special pasteboard.", "special")
///  ```
static int pasteboardwatcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString *pbName = [skin toNSObjectAtIndex:2];
    
    lua_pushvalue(L, 1);
    int callbackRef = [skin luaRef:refTable];

    // Create the timer object:
    HSPasteboardTimer *timer = createHSPasteboardTimer(callbackRef, pbName);
    
    // Start the timer:
    if (![timer isRunning]) {
        [timer start];
    }

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSPasteboardTimer* timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (![timer isRunning]) {
        [timer start];
    }

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);

    lua_pushboolean(L, [timer isRunning]);

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    [timer stop];

    return 1;
}

static int pasteboardwatcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge_transfer HSPasteboardTimer, L, 1, USERDATA_TAG);

    if (timer) {
        [timer stop];
        timer.fnRef = [skin luaUnref:refTable ref:timer.fnRef];
        timer.t = nil;
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSPasteboardTimer *timer = get_objectFromUserdata(__bridge HSPasteboardTimer, L, 1, USERDATA_TAG);
    NSString* title ;

    if (!timer.t) {
        title = @"BUG ENCOUNTERED, hs.pasteboard.watcher tostring found timer.t nil";
    } else if ([timer isRunning]) {
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
    {"new",        pasteboardwatcher_new},
    {NULL,          NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_watcher(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:pasteboardWatcher_lib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:pasteboardWatcher_metalib];
    return 1;
}
