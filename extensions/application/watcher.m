#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "HSuicore.h"

/// === hs.application.watcher ===
///
/// Watch for application launch/terminate events
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Markus Engelbrecht](https://github.com/mgee) and [Steven Degutis](https://github.com/sdegutis/).


/// hs.application.watcher.launching
/// Constant
/// An application is in the process of being launched

/// hs.application.watcher.launched
/// Constant
/// An application has been launched

/// hs.application.watcher.terminated
/// Constant
/// An application has been terminated

/// hs.application.watcher.hidden
/// Constant
/// An application has been hidden

/// hs.application.watcher.unhidden
/// Constant
/// An application has been unhidden

/// hs.application.watcher.activated
/// Constant
/// An application has been activated (i.e. given keyboard/mouse focus)

/// hs.application.watcher.deactivated
/// Constant
/// An application has been deactivated (i.e. lost keyboard/mouse focus)

// Common Code

#define USERDATA_TAG "hs.application.watcher"
static LSRefTable refTable;

// Not so common code

typedef struct _appwatcher_t {
    bool running;
    int fn;
    void* obj;
} appwatcher_t;

typedef enum _event_t {
    launching = 0,
    launched,
    terminated,
    hidden,
    unhidden,
    activated,
    deactivated
} event_t;

@interface AppWatcher : NSObject
@property appwatcher_t* object;
- (id)initWithObject:(appwatcher_t*)object;
@end

@implementation AppWatcher
- (id)initWithObject:(appwatcher_t*)object {
    if (self = [super init]) {
        self.object = object;
    }
    return self;
}

// Call the lua callback function and pass the application name and event type.
- (void)callback:(NSDictionary*)dict withEvent:(event_t)event {
    NSRunningApplication* app = [dict objectForKey:@"NSWorkspaceApplicationKey"];
    if (app == nil)
        return;
    if (!self.object->running)
        return;

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    // Depending on the event the name of the NSRunningApplication object may not be available
    // anymore. Fallback to the application name which is provided directly in the notification
    // object.
    NSString* appName = [app localizedName];
    if (appName == nil)
        appName = [dict objectForKey:@"NSApplicationName"];

    [skin pushLuaRef:refTable ref:self.object->fn];

    if (appName == nil) {
        lua_pushnil(L);
    } else {
        lua_pushstring(L, [appName UTF8String]); // Parameter 1: application name
    }

    lua_pushinteger(L, event); // Parameter 2: the event type

    HSapplication *application = [HSapplication applicationForNSRunningApplication:app withState:L];
    [skin pushNSObject:application];

    [skin protectedCallAndError:@"hs.application.watcher callback" nargs:3 nresults:0];
    _lua_stackguard_exit(L);
}

- (void)applicationWillLaunch:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:launching];
}

- (void)applicationLaunched:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:launched];
}

- (void)applicationTerminated:(NSNotification*)notification {
    [self callback:[notification userInfo]  withEvent:terminated];
}

- (void)applicationHidden:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:hidden];
}

- (void)applicationUnhidden:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:unhidden];
}

- (void)applicationActivated:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:activated];
}

- (void)applicationDeactivated:(NSNotification*)notification {
    [self callback:[notification userInfo] withEvent:deactivated];
}
@end

/// hs.application.watcher.new(fn) -> watcher
/// Constructor
/// Creates an application event watcher
///
/// Parameters:
///  * fn - A function that will be called when application events happen. It should accept three parameters:
///   * A string containing the name of the application
///   * An event type (see the constants defined above)
///   * An `hs.application` object representing the application, or nil if the application couldn't be found
///
/// Returns:
///  * An `hs.application.watcher` object
///
/// Notes:
///  * If the function is called with an event type of `hs.application.watcher.terminated` then the application name parameter will be `nil` and the `hs.application` parameter, will only be useful for getting the UNIX process ID (i.e. the PID) of the application
static int app_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    appwatcher_t* appWatcher = lua_newuserdata(L, sizeof(appwatcher_t));
    memset(appWatcher, 0, sizeof(appwatcher_t));

    lua_pushvalue(L, 1);
    appWatcher->fn = [skin luaRef:refTable];
    appWatcher->running = NO;
    appWatcher->obj = (__bridge_retained void*) [[AppWatcher alloc] initWithObject:appWatcher];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

// Register the AppWatcher as observer for application specific events.
static void register_observer(AppWatcher* observer) {
    // It is crucial to use the shared workspace notification center here.
    // Otherwise the will not receive the events we are interested in.
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:observer
               selector:@selector(applicationWillLaunch:)
                   name:NSWorkspaceWillLaunchApplicationNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationLaunched:)
                   name:NSWorkspaceDidLaunchApplicationNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationTerminated:)
                   name:NSWorkspaceDidTerminateApplicationNotification
                 object:nil];

    [center addObserver:observer
               selector:@selector(applicationHidden:)
                   name:NSWorkspaceDidHideApplicationNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationUnhidden:)
                   name:NSWorkspaceDidUnhideApplicationNotification
                 object:nil];

    [center addObserver:observer
               selector:@selector(applicationActivated:)
                   name:NSWorkspaceDidActivateApplicationNotification
                 object:nil];
    [center addObserver:observer
               selector:@selector(applicationDeactivated:)
                   name:NSWorkspaceDidDeactivateApplicationNotification
                 object:nil];
}

// Unregister the AppWatcher as observer for all events.
static void unregister_observer(AppWatcher* observer) {
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:observer name:NSWorkspaceWillLaunchApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidHideApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidUnhideApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [center removeObserver:observer name:NSWorkspaceDidDeactivateApplicationNotification object:nil];
}

/// hs.application.watcher:start()
/// Method
/// Starts the application watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.application.watcher` object
static int app_watcher_start(lua_State* L) {
    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (appWatcher->running)
        return 0;

    appWatcher->running = YES;
    register_observer((__bridge AppWatcher*)appWatcher->obj);

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.application.watcher:stop()
/// Method
/// Stops the application watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.application.watcher` object
static int app_watcher_stop(lua_State* L) {
    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!appWatcher->running)
        return 0;

    appWatcher->running = NO;
    unregister_observer((__bridge id)appWatcher->obj);

    lua_pushvalue(L, 1);
    return 1;
}

// Perform cleanup if the AppWatcher is not required anymore.
static int app_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    app_watcher_stop(L);

    appWatcher->fn = [skin luaUnref:refTable ref:appWatcher->fn];

    AppWatcher* object = (__bridge_transfer AppWatcher*)appWatcher->obj;
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
    add_event_value(L, launching, "launching");
    add_event_value(L, launched, "launched");
    add_event_value(L, terminated, "terminated");
    add_event_value(L, hidden, "hidden");
    add_event_value(L, unhidden, "unhidden");
    add_event_value(L, activated, "activated");
    add_event_value(L, deactivated, "deactivated");
}

// Metatable for created objects when _new invoked
static const luaL_Reg metaLib[] = {
    {"start",   app_watcher_start},
    {"stop",    app_watcher_stop},
    {"__tostring", userdata_tostring},
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

// Called when loading the module. All necessary tables need to be registered here.
int luaopen_hs_application_watcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:appLib metaFunctions:metaGcLib objectFunctions:metaLib];

    add_event_enum(L);

    return 1;
}
