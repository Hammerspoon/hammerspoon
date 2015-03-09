#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <lauxlib.h>
#import "application.h"

/// === hs.application.watcher ===
///
/// Watch for application launch/terminate events
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


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

// Not so common code

typedef struct _appwatcher_t {
    int self;
    bool running;
    int fn;
    void* obj;
    lua_State* L;
} appwatcher_t;

static NSMutableIndexSet* handlers;

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

    // Depending on the event the name of the NSRunningApplication object may not be available
    // anymore. Fallback to the application name which is provided directly in the notification
    // object.
    NSString* appName = [app localizedName];
    if (appName == nil)
        appName = [dict objectForKey:@"NSApplicationName"];

    lua_State* L = self.object->L;
    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.object->fn);

    if (appName == nil)
        lua_pushnil(L);
    else
        lua_pushstring(L, [appName UTF8String]); // Parameter 1: application name
    lua_pushnumber(L, event); // Parameter 2: the event type
    if ([app processIdentifier] == -1) {
        lua_pushnil(L);
    } else {
        new_application(L, [app processIdentifier]); // Paremeter 3: application object
    }

    if (lua_pcall(L, 3, 0, -5) != LUA_OK) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs");
        lua_getfield(L, -1, "showError");
        lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
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
///   * An `hs.application` object representing the application
///
/// Returns:
///  * An `hs.application.watcher` object
///
/// Notes:
///  * Notes the `hs.application` parameter to the callback may be `nil` if the application does not have a UNIX process ID (i.e. a PID)
///  * If the callback function is called with an event type of `hs.application.watcher.terminated` then the application name parameter will be `nil` and the `hs.application` parameter, will only be useful for getting the UNIX process ID (i.e. the PID) of the application (see also the preceeding note about this parameter potentially being `nil`)
static int app_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    appwatcher_t* appWatcher = lua_newuserdata(L, sizeof(appwatcher_t));
    memset(appWatcher, 0, sizeof(appwatcher_t));

    lua_pushvalue(L, 1);
    appWatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    appWatcher->running = NO;
    appWatcher->L = L;
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
///  * None
static int app_watcher_start(lua_State* L) {
    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (appWatcher->running)
        return 0;

    appWatcher->self = store_udhandler(L, handlers, 1);
    appWatcher->running = YES;
    register_observer((__bridge AppWatcher*)appWatcher->obj);
    return 0;
}

/// hs.application.watcher:stop()
/// Method
/// Stops the application watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int app_watcher_stop(lua_State* L) {
    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!appWatcher->running)
        return 0;

    appWatcher->running = NO;
    remove_udhandler(L, handlers, appWatcher->self);
    unregister_observer((__bridge id)appWatcher->obj);
    return 0;
}

// Perform cleanup if the AppWatcher is not required anymore.
static int app_watcher_gc(lua_State* L) {
    appwatcher_t* appWatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    app_watcher_stop(L);
    luaL_unref(L, LUA_REGISTRYINDEX, appWatcher->fn);

    AppWatcher* object = (__bridge_transfer AppWatcher*)appWatcher->obj;
    object = nil;
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [handlers removeAllIndexes];
    return 0;
}

// Add a single event enum value to the lua table.
static void add_event_value(lua_State* L, event_t value, const char* name) {
    lua_pushnumber(L, value);
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

// Called when loading the module. All necessary tables need to be registered here.
int luaopen_hs_application_watcher(lua_State* L) {
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
