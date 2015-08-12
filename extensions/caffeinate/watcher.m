#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

/// === hs.caffeinate.watcher ===
///
/// Watch for display and system sleep/wake/power events
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

// Common Code

#define USERDATA_TAG "hs.caffeinate.watcher"

// Not so common code

typedef struct _caffeinatewatcher_t {
    bool running;
    int fn;
    void* obj;
} caffeinatewatcher_t;

typedef enum _event_t {
    didWake = 0,
    willSleep,
    willPowerOff,
    screensDidSleep,
    screensDidWake,
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

// Call the lua callback function and pass the application name and event type.
- (void)callback:(NSDictionary* __unused)dict withEvent:(event_t)event {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    lua_rawgeti(L, LUA_REGISTRYINDEX, self.object->fn);
    lua_pushinteger(L, event); // Parameter 1: the event type

    if (![skin protectedCallAndTraceback:1 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
    }
}

- (void)applicationDidWake:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:didWake];
}

- (void)applicationWillSleep:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:willSleep];
}

- (void)applicationWillPowerOff:(NSNotification*)notification {
    [self callback:[notification userInfo]  withEvent:willPowerOff];
}

- (void)applicationScreensDidSleep:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidSleep];
}

- (void)applicationScreensDidWake:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:screensDidWake];
}
@end

/// hs.caffeinate.watcher.new(fn) -> watcher
/// Constructor
/// Creates a watcher object for system and display sleep/wake/power events
///
/// Parameters:
///  * fn - A function that will be called when system/display events happen. It should accept one parameters:
///   * An event type (see the constants defined above)
///
/// Returns:
///  * An `hs.caffeinate.watcher` object
static int app_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    caffeinatewatcher_t* caffeinateWatcher = lua_newuserdata(L, sizeof(caffeinatewatcher_t));
    memset(caffeinateWatcher, 0, sizeof(caffeinatewatcher_t));

    lua_pushvalue(L, 1);
    caffeinateWatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    caffeinateWatcher->running = NO;
    caffeinateWatcher->obj = (__bridge_retained void*) [[CaffeinateWatcher alloc] initWithObject:caffeinateWatcher];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

// Register the CaffeinateWatcher as observer for application specific events.
static void register_observer(CaffeinateWatcher* observer) {
    // It is crucial to use the shared workspace notification center here.
    // Otherwise the will not receive the events we are interested in.
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:observer
               selector:@selector(applicationDidWake:)
                   name:NSWorkspaceDidWakeNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationWillSleep:)
                   name:NSWorkspaceWillSleepNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationWillPowerOff:)
                   name:NSWorkspaceWillPowerOffNotification
                 object:nil];

    [center addObserver:observer
               selector:@selector(applicationScreensDidSleep:)
                   name:NSWorkspaceScreensDidSleepNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationScreensDidWake:)
                   name:NSWorkspaceScreensDidWakeNotification
                 object:nil];
}

// Unregister the CaffeinateWatcher as observer for all events.
static void unregister_observer(CaffeinateWatcher* observer) {
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:observer name:NSWorkspaceDidWakeNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceWillSleepNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceWillPowerOffNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceScreensDidSleepNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceScreensDidWakeNotification object:nil];
}

/// hs.caffeinate.watcher:start()
/// Method
/// Starts the application watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int app_watcher_start(lua_State* L) {
    caffeinatewatcher_t* caffeinateWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (caffeinateWatcher->running)
        return 0;

    caffeinateWatcher->running = YES;
    register_observer((__bridge CaffeinateWatcher*)caffeinateWatcher->obj);
    return 0;
}

/// hs.caffeinate.watcher:stop()
/// Method
/// Stops the application watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int app_watcher_stop(lua_State* L) {
    caffeinatewatcher_t* caffeinateWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!caffeinateWatcher->running)
        return 0;

    caffeinateWatcher->running = NO;
    unregister_observer((__bridge id)caffeinateWatcher->obj);
    return 0;
}

// Perform cleanup if the CaffeinateWatcher is not required anymore.
static int app_watcher_gc(lua_State* L) {
    caffeinatewatcher_t* caffeinateWatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    app_watcher_stop(L);
    luaL_unref(L, LUA_REGISTRYINDEX, caffeinateWatcher->fn);
    caffeinateWatcher->fn = LUA_NOREF;

    CaffeinateWatcher* object = (__bridge_transfer CaffeinateWatcher*)caffeinateWatcher->obj;
    object = nil;
    return 0;
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
}

// Called when loading the module. All necessary tables need to be registered here.
int luaopen_hs_caffeinate_watcher(lua_State* L) {
    // Metatable for created objects when _new invoked
    static const luaL_Reg metaLib[] = {
        {"start",   app_watcher_start},
        {"stop",    app_watcher_stop},
        {"__gc",    app_watcher_gc},
        {NULL,      NULL}
    };

    // Functions for returned object when module loads
    static const luaL_Reg appLib[] = {
        {"new",     app_watcher_new},
        {NULL,      NULL}
    };

    // Metatable for returned object when module loads
    static const luaL_Reg metaGcLib[] = {
        {"__gc",    meta_gc},
        {NULL,      NULL}
    };

    // Metatable for created objects
    luaL_newlib(L, metaLib);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

    // Create table for luaopen
    luaL_newlib(L, appLib);
    add_event_enum(L);

    luaL_newlib(L, metaGcLib);
    lua_setmetatable(L, -2);
    return 1;
}
