#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import "uielement.h"
#import "../window/window.h"
#import "../application/application.h"

#define get_element(L, idx) *((AXUIElementRef*)lua_touserdata(L, idx))

static const char* userdataTag = "hs.uielement";
static const char* watcherUserdataTag = "hs.uielement.watcher.userdata";
static const char* watcherTag = "hs.uielement.watcher";
NSArray *eventNames;

static void new_uielement(lua_State* L, AXUIElementRef element) {
    AXUIElementRef* elementptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    if (!elementptr) NSLog(@"elementptr is nil!");
    if (!element) NSLog(@"new_uielement called with nil element!");
    *elementptr = element;

    luaL_getmetatable(L, userdataTag);
    lua_setmetatable(L, -2);

    lua_newtable(L);
    lua_setuservalue(L, -2);
}

static id get_prop(AXUIElementRef win, NSString* propType, id defaultValue) {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(win, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);

    return defaultValue;
}

// Use the Role of the element to decide which type of object to create: window, app, or plain uielement.
// Retains a copy of the element, if necessary.
static void push_element(lua_State* L, AXUIElementRef element) {
    NSString* role = get_prop(element, NSAccessibilityRoleAttribute, @"");
    if        ([role isEqualToString: (NSString*)kAXWindowRole]) {
        new_window(L, (AXUIElementRef)CFRetain(element));
    } else if ([role isEqualToString: (NSString*)kAXApplicationRole]) {
        pid_t pid;
        AXUIElementGetPid(element, &pid);
        new_application(L, pid);
    } else {
        new_uielement(L, (AXUIElementRef)CFRetain(element));
    }
}

/// hs.uielement:role() -> string
/// Method
/// Returns the role of the element.
static int uielement_role(lua_State* L) {
    AXUIElementRef element = get_element(L, 1);

    NSString* str = get_prop(element, NSAccessibilityRoleAttribute, @"");

    lua_pushstring(L, [str UTF8String]);
    return 1;
}

static int uielement_eq(lua_State* L) {
    AXUIElementRef lhs = get_element(L, 1);
    AXUIElementRef rhs = get_element(L, 2);
    lua_pushboolean(L, CFEqual(lhs, rhs));
    return 1;
}

// Clean up a bare uielement if it isn't needed anymore.
static int uielement_gc(lua_State* L) {
    luaL_checkudata(L, 1, userdataTag);
    AXUIElementRef element = get_element(L, 1);
    CFRelease(element);
    return 0;
}

typedef struct _watcher_t {
    bool running;
    int handler_ref;
    int user_data_ref;
    int watcher_ref;
    lua_State* L;
    AXObserverRef observer;
    AXUIElementRef element;
    pid_t pid;
} watcher_t;

static int uielement_newWatcher(lua_State* L) {
    int nargs = lua_gettop(L);

    AXUIElementRef element = get_element(L, 1);  // self
    luaL_checktype(L, 2, LUA_TFUNCTION);

    watcher_t* watcher = lua_newuserdata(L, sizeof(watcher_t));
    memset(watcher, 0, sizeof(watcher_t));

    lua_pushvalue(L, 2);  // handler
    watcher->handler_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    if (nargs >= 3)
        lua_pushvalue(L, 3);  // userData
    else
        lua_pushnil(L);
    watcher->user_data_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    watcher->watcher_ref = LUA_REFNIL;
    watcher->running = NO;
    watcher->L = L;
    watcher->element = (AXUIElementRef)CFRetain(element);
    AXUIElementGetPid(element, &watcher->pid);

    luaL_getmetatable(L, watcherUserdataTag);
    lua_setmetatable(L, -2);

    // Wrap the whole thing in a table
    lua_newtable(L);
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "_watcher");
    push_element(L, element);
    lua_setfield(L, -2, "_element");

    luaL_getmetatable(L, watcherTag);
    lua_setmetatable(L, -2);

    return 1;
}

static watcher_t* get_watcher(lua_State* L, int elem) {
    lua_getfield(L, elem, "_watcher");
    watcher_t* watcher = (watcher_t*)luaL_checkudata(L, -1, watcherUserdataTag);
    lua_pop(L, 1);
    return watcher;
}

static void watcher_observer_callback(AXObserverRef observer __unused, AXUIElementRef element,
                                      CFStringRef notificationName, void* contextData) {
    watcher_t* watcher = (watcher_t*) contextData;

    lua_State* L = watcher->L;
    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_remove(L, -2);

    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->handler_ref);
    push_element(L, element); // Parameter 1: element
    lua_pushstring(L, CFStringGetCStringPtr(notificationName, kCFStringEncodingASCII)); // Parameter 2: event
    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->watcher_ref); // Parameter 3: watcher
    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->user_data_ref); // Parameter 4: userData

    if (lua_pcall(L, 4, 0, -6) != LUA_OK) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs");
        lua_getfield(L, -1, "showError");
        lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}

static int watcher_start(lua_State* L) {
    watcher_t* watcher = get_watcher(L, 1);
    if (watcher->running) return 0;

    // Create our observer.
    AXObserverRef observer = NULL;
    AXError err = AXObserverCreate(watcher->pid, watcher_observer_callback, &observer);
    if (err != kAXErrorSuccess) {
        NSLog(@"AXObserverCreate error: %d", (int)err);
        return 0;
    }

    // Add specified events to the observer.
    luaL_checktype(L, 2, LUA_TTABLE);
    int numEvents = lua_rawlen(L, 2);
    for (int i = 1; i <= numEvents; ++i) {
        // Get event name as CFStringRef
        lua_rawgeti(L, 2, i);
        CFStringRef eventName =
            CFStringCreateWithCString(NULL, luaL_checkstring(L, -1), kCFStringEncodingASCII);
        NSUInteger stringIndex = [eventNames indexOfObject:(__bridge NSString*)eventName];
        if (stringIndex != NSNotFound) {
            AXObserverAddNotification(observer, watcher->element, (__bridge CFStringRef)[eventNames objectAtIndex:stringIndex], watcher);
        } else {
            NSLog(@"Unable to find uielement.watcher event: %@", (__bridge NSString*)eventName);
        }

        CFRelease(eventName);
        lua_pop(L, 1);

    }

    lua_pushvalue(L, 1);  // Store a reference to the lua object inside watcher.
    watcher->watcher_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    watcher->observer = observer;
    watcher->running = YES;

    // Begin observing events.
    CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                       AXObserverGetRunLoopSource(observer),
                       kCFRunLoopDefaultMode);

    return 0;
}

static void stop_watcher(lua_State* L, watcher_t* watcher) {
    if (!watcher->running) return;

    CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                          AXObserverGetRunLoopSource(watcher->observer),
                          kCFRunLoopDefaultMode);

    luaL_unref(L, LUA_REGISTRYINDEX, watcher->watcher_ref);
    CFRelease(watcher->observer);

    watcher->running = NO;
}

static int watcher_stop(lua_State* L) {
    watcher_t* watcher = get_watcher(L, 1);
    stop_watcher(L, watcher);
    return 0;
}

// Perform cleanup if the watcher is not required anymore.
static int watcher_gc(lua_State* L) {
    watcher_t* watcher = get_watcher(L, 1);

    stop_watcher(L, watcher);  // For extra safety, make sure we're stopped.
    luaL_unref(L, LUA_REGISTRYINDEX, watcher->handler_ref);
    luaL_unref(L, LUA_REGISTRYINDEX, watcher->user_data_ref);
    CFRelease(watcher->element);

    return 0;
}

static const luaL_Reg uielementlib[] = {
    {"role", uielement_role},
    {"_newWatcher", uielement_newWatcher},
    {}
};

static const luaL_Reg watcherlib[] = {
    {"_start", watcher_start},
    {"_stop", watcher_stop},
    {}
};

int luaopen_hs_uielement_internal(lua_State* L) {
    eventNames = @[ @"AXMainWindowChanged", @"AXFocusedWindowChanged", @"AXFocusedUIElementChanged", @"AXApplicationActivated", @"AXApplicationDeactivated", @"AXApplicationHidden", @"AXApplicationShown", @"AXWindowCreated", @"AXWindowMoved", @"AXWindowResized", @"AXWindowMiniaturized", @"AXWindowDeminiaturized", @"AXUIElementDestroyed", @"AXTitleChanged" ];

    luaL_newlib(L, watcherlib);

    if (luaL_newmetatable(L, watcherTag)) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, watcher_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);

    luaL_newlib(L, uielementlib);
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "watcher");

    if (luaL_newmetatable(L, userdataTag)) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, uielement_gc);
        lua_setfield(L, -2, "__gc");
        lua_pushcfunction(L, uielement_eq);
        lua_setfield(L, -2, "__eq");
        // __gc and __eq provided by subclasses.
    }
    luaL_newmetatable(L, watcherUserdataTag);
    lua_pop(L, 2);

    return 1;  // uielementlib
}
