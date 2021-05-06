#import <Foundation/Foundation.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.caffeinate.watcher ===
///
/// Watch for display and system sleep/wake/power events
/// and for fast user switching session events.
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


/// hs.caffeinate.watcher.systemDidWake
/// Constant
/// The system woke from sleep

/// hs.caffeinate.watcher.systemWillSleep
/// Constant
/// The system is preparing to sleep

/// hs.caffeinate.watcher.systemWillPowerOff
/// Constant
/// The user requested a logout or shutdown

/// hs.caffeinate.watcher.screensDidSleep
/// Constant
/// The displays have gone to sleep

/// hs.caffeinate.watcher.screensDidWake
/// Constant
/// The displays have woken from sleep

/// hs.caffeinate.watcher.sessionDidResignActive
/// Constant
/// The session is no longer active, due to fast user switching

/// hs.caffeinate.watcher.sessionDidBecomeActive
/// Constant
/// The session became active, due to fast user switching

/// hs.caffeinate.watcher.screensaverDidStart
/// Constant
/// The screensaver started

/// hs.caffeinate.watcher.screensaverWillStop
/// Constant
/// The screensaver is about to stop

/// hs.caffeinate.watcher.screensaverDidStop
/// Constant
/// The screensaver stopped

/// hs.caffeinate.watcher.screensDidLock
/// Constant
/// The screen was locked

/// hs.caffeinate.watcher.screensDidUnlock
/// Constant
/// The screen was unlocked

// Common Code

#define USERDATA_TAG "hs.caffeinate.watcher"
static LSRefTable refTable;

// Not so common code

typedef struct _caffeinatewatcher_t {
    bool running;
    int fn;
    void* obj;
    LSGCCanary lsCanary;
} caffeinatewatcher_t;

typedef enum _event_t {
    didWake = 0,
    willSleep,
    willPowerOff,
    screensDidSleep,
    screensDidWake,
    sessionDidResignActive,
    sessionDidBecomeActive,
    screensaverDidStart,
    screensaverWillStop,
    screensaverDidStop,
    screensDidLock,
    screensDidUnlock,
} event_t;

@interface CaffeinateWatcher : NSObject
@property caffeinatewatcher_t* object;
- (id)initWithObject:(caffeinatewatcher_t*)object;
@end

@implementation CaffeinateWatcher
- (id)initWithObject:(caffeinatewatcher_t*)object {
    if (self = [super init]) {
        self.object = object;
    }
    return self;
}

// Call the lua callback function and pass the event type.
- (void)callback:(NSDictionary* __unused)dict withEvent:(event_t)event {
    if (self.object->fn != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin checkGCCanary:self.object->lsCanary];
        lua_State *L = skin.L;
        _lua_stackguard_entry(L);

        [skin pushLuaRef:refTable ref:self.object->fn];
        lua_pushinteger(L, event); // Parameter 1: the event type

        [skin protectedCallAndError:@"hs.caffeinate.watcher callback" nargs:1 nresults:0];
        _lua_stackguard_exit(L);
    }
}

- (void)caffeinateDidWake:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:didWake];
}

- (void)caffeinateWillSleep:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:willSleep];
}

- (void)caffeinateWillPowerOff:(NSNotification*)notification {
    [self callback:[notification userInfo]  withEvent:willPowerOff];
}

- (void)caffeinateScreensDidSleep:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidSleep];
}

- (void)caffeinateScreensDidWake:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidWake];
}

- (void)caffeinateSessionDidResignActive:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:sessionDidResignActive];
}

- (void)caffeinateSessionDidBecomeActive:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:sessionDidBecomeActive];
}

- (void)caffeinateScreensaverDidStart:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensaverDidStart];
}

- (void)caffeinateScreensaverWillStop:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensaverWillStop];
}

- (void)caffeinateScreensaverDidStop:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensaverDidStop];
}

- (void)caffeinateScreensDidLock:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidLock];
}

- (void)caffeinateScreensDidUnlock:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidUnlock];
}

@end

/// hs.caffeinate.watcher.new(fn) -> watcher
/// Constructor
/// Creates a watcher object for system and display sleep/wake/power events
///
/// Parameters:
///  * fn - A function that will be called when system/display events happen. It should accept one parameter:
///   * An event type (see the constants defined above)
///
/// Returns:
///  * An `hs.caffeinate.watcher` object
static int caffeinate_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    caffeinatewatcher_t* caffeinateWatcher = lua_newuserdata(L, sizeof(caffeinatewatcher_t));
    memset(caffeinateWatcher, 0, sizeof(caffeinatewatcher_t));

    lua_pushvalue(L, 1);
    caffeinateWatcher->fn = [skin luaRef:refTable];
    caffeinateWatcher->running = NO;
    caffeinateWatcher->obj = (__bridge_retained void*) [[CaffeinateWatcher alloc] initWithObject:caffeinateWatcher];
    caffeinateWatcher->lsCanary = [skin createGCCanary];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

// Register the CaffeinateWatcher as observer for sleep/wake events.
static void register_observer(CaffeinateWatcher* observer) {
    // It is crucial to use the shared workspace notification center here.
    // Otherwise the will not receive the events we are interested in.
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    NSDistributedNotificationCenter* distcenter =
	[NSDistributedNotificationCenter defaultCenter];
    [center addObserver:observer
               selector:@selector(caffeinateDidWake:)
                   name:NSWorkspaceDidWakeNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(caffeinateWillSleep:)
                   name:NSWorkspaceWillSleepNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(caffeinateWillPowerOff:)
                   name:NSWorkspaceWillPowerOffNotification
                 object:nil];

    [center addObserver:observer
               selector:@selector(caffeinateScreensDidSleep:)
                   name:NSWorkspaceScreensDidSleepNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(caffeinateScreensDidWake:)
                   name:NSWorkspaceScreensDidWakeNotification
                 object:nil];

    [center addObserver:observer
               selector:@selector(caffeinateSessionDidResignActive:)
                   name:NSWorkspaceSessionDidResignActiveNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(caffeinateSessionDidBecomeActive:)
                   name:NSWorkspaceSessionDidBecomeActiveNotification
                 object:nil];

    [distcenter addObserver:observer
		   selector:@selector(caffeinateScreensaverDidStart:)
		       name:@"com.apple.screensaver.didstart"
		     object:nil];
    [distcenter addObserver:observer
		   selector:@selector(caffeinateScreensaverWillStop:)
		       name:@"com.apple.screensaver.willstop"
		     object:nil];
    [distcenter addObserver:observer
		   selector:@selector(caffeinateScreensaverDidStop:)
		       name:@"com.apple.screensaver.didstop"
		     object:nil];
    [distcenter addObserver:observer
		   selector:@selector(caffeinateScreensDidLock:)
		       name:@"com.apple.screenIsLocked"
		     object:nil];
    [distcenter addObserver:observer
		   selector:@selector(caffeinateScreensDidUnlock:)
		       name:@"com.apple.screenIsUnlocked"
		     object:nil];
}

// Unregister the CaffeinateWatcher as observer for all events.
static void unregister_observer(CaffeinateWatcher* observer) {
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    NSDistributedNotificationCenter* distcenter =
	[NSDistributedNotificationCenter defaultCenter];
    [center removeObserver:observer name:NSWorkspaceDidWakeNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceWillSleepNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceWillPowerOffNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceScreensDidSleepNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceScreensDidWakeNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceSessionDidResignActiveNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    [distcenter removeObserver:observer name:@"com.apple.screensaver.didstart" object:nil];
    [distcenter removeObserver:observer name:@"com.apple.screensaver.willstop" object:nil];
    [distcenter removeObserver:observer name:@"com.apple.screensaver.didstop" object:nil];
    [distcenter removeObserver:observer name:@"com.apple.screenIsLocked" object:nil];
    [distcenter removeObserver:observer name:@"com.apple.screenIsUnlocked" object:nil];
}

/// hs.caffeinate.watcher:start()
/// Method
/// Starts the sleep/wake watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.caffeinate.watcher` object
static int caffeinate_watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    caffeinatewatcher_t* caffeinateWatcher = lua_touserdata(L, 1);
    lua_settop(L, 1);

    if (caffeinateWatcher->running)
        return 1;

    caffeinateWatcher->running = YES;
    register_observer((__bridge CaffeinateWatcher*)caffeinateWatcher->obj);
    return 1;
}

/// hs.caffeinate.watcher:stop()
/// Method
/// Stops the sleep/wake watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.caffeinate.watcher` object
static int caffeinate_watcher_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    caffeinatewatcher_t* caffeinateWatcher = lua_touserdata(L, 1);
    lua_settop(L, 1);

    if (!caffeinateWatcher->running)
        return 1;

    caffeinateWatcher->running = NO;
    unregister_observer((__bridge id)caffeinateWatcher->obj);
    return 1;
}

// Perform cleanup if the CaffeinateWatcher is not required anymore.
static int caffeinate_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    caffeinatewatcher_t* caffeinateWatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    caffeinate_watcher_stop(L);

    caffeinateWatcher->fn = [skin luaUnref:refTable ref:caffeinateWatcher->fn];
    [skin destroyGCCanary:&(caffeinateWatcher->lsCanary)];

    CaffeinateWatcher* object = (__bridge_transfer CaffeinateWatcher*)caffeinateWatcher->obj;
    object = nil;
    return 0;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Add a single event enum value to the lua table.
static void add_event_value(lua_State* L, event_t value, const char* name) {
    lua_pushinteger(L, value);
    lua_setfield(L, -2, name);
}

// Add the event_t enum to the lua table.
static void add_event_enum(lua_State* L) {
    add_event_value(L, didWake, "systemDidWake");
    add_event_value(L, willSleep, "systemWillSleep");
    add_event_value(L, willPowerOff, "systemWillPowerOff");
    add_event_value(L, screensDidSleep, "screensDidSleep");
    add_event_value(L, screensDidWake, "screensDidWake");
    add_event_value(L, sessionDidResignActive, "sessionDidResignActive");
    add_event_value(L, sessionDidBecomeActive, "sessionDidBecomeActive");
    add_event_value(L, screensaverDidStart, "screensaverDidStart");
    add_event_value(L, screensaverWillStop, "screensaverWillStop");
    add_event_value(L, screensaverDidStop, "screensaverDidStop");
    add_event_value(L, screensDidLock, "screensDidLock");
    add_event_value(L, screensDidUnlock, "screensDidUnlock");
}

// Metatable for created objects when _new invoked
static const luaL_Reg metaLib[] = {
    {"start",   caffeinate_watcher_start},
    {"stop",    caffeinate_watcher_stop},
    {"__gc",    caffeinate_watcher_gc},
    {"__tostring", userdata_tostring},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg caffeinateLib[] = {
    {"new",     caffeinate_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg metaGcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

// Called when loading the module. All necessary tables need to be registered here.
int luaopen_hs_caffeinate_watcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:caffeinateLib metaFunctions:metaGcLib objectFunctions:metaLib];

    add_event_enum(skin.L);

    return 1;
}
