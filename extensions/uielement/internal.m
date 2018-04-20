@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
#import "uielement.h"
#import "../window/window.h"
#import "../application/application.h"

#define get_element(L, idx) *((AXUIElementRef*)lua_touserdata(L, idx))

static const char* userdataTag = "hs.uielement";
static const char* watcherUserdataTag = "hs.uielement.watcher.userdata";
static const char* watcherTag = "hs.uielement.watcher";
static NSArray *eventNames;

static void new_uielement(lua_State* L, AXUIElementRef element) {
    LuaSkin *skin = [LuaSkin shared];
    AXUIElementRef* elementptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    if (!elementptr) {
        [skin logBreadcrumb:@"hs.uielement new_uielement: elementptr is nil"];
        return;
    }
    if (!element) [skin logBreadcrumb:@"new_uielement called with nil element!"];
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

static bool is_window(AXUIElementRef element, NSString* role) {
  if (!role) {
    role = get_prop(element, NSAccessibilityRoleAttribute, @"");
  }

  if ([role isKindOfClass:[NSString class]]) {
      // The role attribute on a window can potentially be something
      // other than kAXWindowRole (e.g. Emacs does not claim kAXWindowRole)
      // so we will do the simple test first, but then also attempt to duck-type
      // the object, to see if it has a property that any window should have
      if([role isEqualToString: (__bridge NSString*)kAXWindowRole] ||
         get_prop(element, NSAccessibilityMinimizedAttribute, nil)) {
        return YES;
      } else {
        return NO;
      }
  } else {
      // may switch to breadcrumb when we know the issue is fixed, but for now I want to be
      // able to check the logs from within Hammerspoon
      [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:is_window AXRole is not a string type:%@ (CFType %lu)", userdataTag, [role class], CFGetTypeID((__bridge CFTypeRef)role)]] ;

      pid_t thePid ;
      AXError errorState = AXUIElementGetPid(element, &thePid) ;
      if (errorState == kAXErrorSuccess) {
          NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:thePid];
          if (app) {
              [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:is_window process id %d corresponds to %@", userdataTag, thePid, [app localizedName]]] ;
          } else {
              [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:is_window process id %d does not correspond to a macOS Application", userdataTag, thePid]] ;
          }
      } else {
          [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:is_window unable to get process id for malformed AXRole owner", userdataTag]] ;
      }

      return NO;
  }
}


// Use the Role of the element to decide which type of object to create: window, app, or plain uielement.
// Retains a copy of the element, if necessary.
static void push_element(lua_State* L, AXUIElementRef element) {
    NSString* role = get_prop(element, NSAccessibilityRoleAttribute, @"");

    if ([role isKindOfClass:[NSString class]]) {
        if (is_window(element, role)) {
            new_window(L, (AXUIElementRef)CFRetain(element));
        } else if ([role isEqualToString: (__bridge NSString*)kAXApplicationRole]) {
            pid_t pid;
            AXUIElementGetPid(element, &pid);
            if (!new_application(L, pid)) {
                lua_pushnil(L);
            }
        } else {
            new_uielement(L, (AXUIElementRef)CFRetain(element));
        }
    } else {
        // may switch to breadcrumb when we know the issue is fixed, but for now I want to be
        // able to check the logs from within Hammerspoon
        [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:push_element AXRole is not a string type:%@ (CFType %lu)", userdataTag, [role class], CFGetTypeID((__bridge CFTypeRef)role)]] ;

        pid_t thePid ;
        AXError errorState = AXUIElementGetPid(element, &thePid) ;
        if (errorState == kAXErrorSuccess) {
            NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:thePid];
            if (app) {
                [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:push_element process id %d corresponds to %@", userdataTag, thePid, [app localizedName]]] ;
            } else {
                [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:push_element process id %d does not correspond to a macOS Application", userdataTag, thePid]] ;
            }
        } else {
            [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:push_element unable to get process id for malformed AXRole owner", userdataTag]] ;
        }
        new_uielement(L, (AXUIElementRef)CFRetain(element));
    }
}

/// hs.uielement:isWindow() -> bool
/// Method
/// Returns whether the UI element represents a window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the UI element is a window, otherwise false
static int uielement_iswindow(lua_State* L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    AXUIElementRef element = get_element(L, 1);
    bool isWindow = is_window(element, nil);
    lua_pushboolean(L, isWindow);
    return 1;
}

/// hs.uielement:role() -> string
/// Method
/// Returns the role of the element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the role of the UI element
static int uielement_role(lua_State* L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    AXUIElementRef element = get_element(L, 1);

    NSString* str = get_prop(element, NSAccessibilityRoleAttribute, @"");

    lua_pushstring(L, [str UTF8String]);
    return 1;
}

/// hs.uielement:selectedText() -> string or nil
/// Method
/// Returns the selected text in the element
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the selected text, or nil if none could be found
///
/// Notes:
///  * Many applications (e.g. Safari, Mail, Firefox) do not implement the necessary accessibility features for this to work in their web views
static int uielement_selectedText(lua_State* L) {
    AXValueRef selectedText = NULL;
    luaL_checktype(L, 1, LUA_TUSERDATA);
    AXUIElementRef element = get_element(L, 1);
    if (AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute, (CFTypeRef *)&selectedText) != kAXErrorSuccess) {
        lua_pushnil(L);
        return 1;
    }
    lua_pushstring(L, [(__bridge NSString *)selectedText UTF8String]);
    return 1;
}

static int uielement_eq(lua_State* L) {
    if ((lua_type(L, 1) == LUA_TUSERDATA) && (lua_type(L, 2) == LUA_TUSERDATA)) {
        AXUIElementRef lhs = get_element(L, 1);
        AXUIElementRef rhs = get_element(L, 2);
        if (lhs && rhs) {
            lua_pushboolean(L, CFEqual(lhs, rhs));
        } else {
            lua_pushboolean(L, false) ;
        }
    } else {
        lua_pushboolean(L, false) ;
    }
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
    AXObserverRef observer;
    AXUIElementRef element;
    pid_t pid;
} watcher_t;

static int uielement_newWatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    int nargs = lua_gettop(L);

    void *userData = lua_touserdata(L, 1);
    if (!userData) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"uielement_newWatcher: invalid userdata received. Actual type: %d", lua_type(L, 1)]];
        lua_pushnil(L);
        return 1;
    }

    AXUIElementRef element = *(AXUIElementRef*)userData;  // self
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
    LuaSkin *skin = [LuaSkin shared];
    _lua_stackguard_entry(skin.L);

    watcher_t* watcher = (watcher_t*) contextData;

    lua_State *L = skin.L;

    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->handler_ref);
    push_element(L, element); // Parameter 1: element
    lua_pushstring(L, CFStringGetCStringPtr(notificationName, kCFStringEncodingASCII)); // Parameter 2: event
    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->watcher_ref); // Parameter 3: watcher
    lua_rawgeti(L, LUA_REGISTRYINDEX, watcher->user_data_ref); // Parameter 4: userData
    [skin protectedCallAndError:@"hs.uielement watcher callback" nargs:4 nresults:0];
    _lua_stackguard_exit(skin.L);
}

static int watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    watcher_t* watcher = get_watcher(L, 1);
    if (watcher->running) return 0;

    // Create our observer.
    AXObserverRef observer = NULL;
    AXError err = AXObserverCreate(watcher->pid, watcher_observer_callback, &observer);
    if (err != kAXErrorSuccess) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"AXObserverCreate error: %d", (int)err]];
        return 0;
    }

    // Add specified events to the observer.
    luaL_checktype(L, 2, LUA_TTABLE);
    int numEvents = (int)lua_rawlen(L, 2);
    for (int i = 1; i <= numEvents; ++i) {
        // Get event name as CFStringRef
        lua_rawgeti(L, 2, i);
        CFStringRef eventName =
            CFStringCreateWithCString(NULL, luaL_checkstring(L, -1), kCFStringEncodingASCII);
        NSUInteger stringIndex = [eventNames indexOfObject:(__bridge NSString*)eventName];
        if (stringIndex != NSNotFound) {
            AXObserverAddNotification(observer, watcher->element, (__bridge CFStringRef)[eventNames objectAtIndex:stringIndex], watcher);
        } else {
            [skin logBreadcrumb:[NSString stringWithFormat:@"Unable to find uielement.watcher event: %@", (__bridge NSString *)eventName]];
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

    lua_pushvalue(L, 1);
    return 1;
}

static void stop_watcher(lua_State* L, watcher_t* watcher) {
    if (!watcher->running) return;

    CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                          AXObserverGetRunLoopSource(watcher->observer),
                          kCFRunLoopDefaultMode);

    luaL_unref(L, LUA_REGISTRYINDEX, watcher->watcher_ref);
    watcher->watcher_ref = LUA_NOREF;
    CFRelease(watcher->observer);

    watcher->running = NO;
}

static int watcher_stop(lua_State* L) {
    watcher_t* watcher = get_watcher(L, 1);
    stop_watcher(L, watcher);
    lua_pushvalue(L, 1);

    return 1;
}

/// hs.uielement.focusedElement() -> element or nil
/// Function
/// Gets the currently focused UI element
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.uielement` object or nil if no object could be found
static int uielement_focusedElement(lua_State* L) {
    AXUIElementRef focusedElement;
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();

    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement) != kAXErrorSuccess) {
        NSLog(@"Failed to get kAXFocusedUIElementAttribute");
        lua_pushnil(L);
        CFRelease(systemWide);
        return 1;
    }
    CFRelease(systemWide);

    push_element(L, focusedElement);
    return 1;
}

// Perform cleanup if the watcher is not required anymore.
static int watcher_gc(lua_State* L) {
    watcher_t* watcher = get_watcher(L, 1);

    stop_watcher(L, watcher);  // For extra safety, make sure we're stopped.
    luaL_unref(L, LUA_REGISTRYINDEX, watcher->handler_ref);
    luaL_unref(L, LUA_REGISTRYINDEX, watcher->user_data_ref);
    watcher->handler_ref = LUA_NOREF;
    watcher->user_data_ref = LUA_NOREF;
    CFRelease(watcher->element);

    return 0;
}

static const luaL_Reg uielementlib[] = {
    {"role", uielement_role},
    {"isWindow", uielement_iswindow},
    {"_newWatcher", uielement_newWatcher},
    {"focusedElement", uielement_focusedElement},
    {"selectedText", uielement_selectedText},
    {NULL, NULL}
};

static const luaL_Reg watcherlib[] = {
    {"_start", watcher_start},
    {"_stop", watcher_stop},
    {NULL, NULL}
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
