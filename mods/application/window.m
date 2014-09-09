#import <Cocoa/Cocoa.h>
#import <lauxlib.h>
#import "window.h"
#import "application.h"

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);

#define get_window_arg(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "mjolnir.window"))

static NSSize geom_tosize(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakeSize(w, h);
}

static NSPoint geom_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}

static void geom_pushsize(lua_State* L, NSSize size) {
    lua_newtable(L);
    lua_pushnumber(L, size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, size.height); lua_setfield(L, -2, "h");
}

static void geom_pushpoint(lua_State* L, NSPoint point) {
    lua_newtable(L);
    lua_pushnumber(L, point.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, point.y); lua_setfield(L, -2, "y");
}

static int window_gc(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CFRelease(win);
    return 0;
}

static int window_eq(lua_State* L) {
    AXUIElementRef winA = get_window_arg(L, 1);
    AXUIElementRef winB = get_window_arg(L, 2);
    lua_pushboolean(L, CFEqual(winA, winB));
    return 1;
}

static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

/// mjolnir.window.focusedwindow() -> window
/// Constructor
/// Returns the focused window, or nil.
static int window_focusedwindow(lua_State* L) {
    CFTypeRef app;
    AXUIElementCopyAttributeValue(system_wide_element(), kAXFocusedApplicationAttribute, &app);
    
    if (app) {
        CFTypeRef win;
        AXError result = AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &win);
        
        CFRelease(app);
        
        if (result == kAXErrorSuccess) {
            new_window(L, win);
            return 1;
        }
    }
    
    lua_pushnil(L);
    return 1;
}

static id get_window_prop(AXUIElementRef win, NSString* propType, id defaultValue) {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(win, (CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);
    
    return defaultValue;
}

static BOOL set_window_prop(AXUIElementRef win, NSString* propType, id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        AXError result = AXUIElementSetAttributeValue(win, (CFStringRef)(propType), (CFTypeRef)(value));
        if (result == kAXErrorSuccess)
            return YES;
    }
    return NO;
}

/// mjolnir.window:title() -> string
/// Method
/// Returns the title of the window (as UTF8).
static int window_title(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    NSString* title = get_window_prop(win, NSAccessibilityTitleAttribute, @"");
    lua_pushstring(L, [title UTF8String]);
    return 1;
}

/// mjolnir.window:subrole() -> string
/// Method
/// Returns the subrole of the window, whatever that means.
static int window_subrole(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    NSString* str = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

/// mjolnir.window:role() -> string
/// Method
/// Returns the role of the window, whatever that means.
static int window_role(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    NSString* str = get_window_prop(win, NSAccessibilityRoleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

/// mjolnir.window:isstandard() -> bool
/// Method
/// True if the window's subrole indicates it's 'a standard window'.
static int window_isstandard(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    NSString* subrole = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");
    
    BOOL is_standard = [subrole isEqualToString: (NSString*)kAXStandardWindowSubrole];
    lua_pushboolean(L, is_standard);
    return 1;
}

/// mjolnir.window:topleft() -> point
/// Method
/// The top-left corner of the window in absolute coordinates.
static int window_topleft(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    CFTypeRef positionStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, &positionStorage);
    
    CGPoint topLeft;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(positionStorage, kAXValueCGPointType, (void *)&topLeft)) {
            topLeft = CGPointZero;
        }
    }
    else {
        topLeft = CGPointZero;
    }
    
    if (positionStorage)
        CFRelease(positionStorage);
    
    geom_pushpoint(L, topLeft);
    return 1;
}

/// mjolnir.window:size() -> size
/// Method
/// The size of the window.
static int window_size(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    CFTypeRef sizeStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, &sizeStorage);
    
    CGSize size;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(sizeStorage, kAXValueCGSizeType, (void *)&size)) {
            size = CGSizeZero;
        }
    }
    else {
        size = CGSizeZero;
    }
    
    if (sizeStorage)
        CFRelease(sizeStorage);
    
    geom_pushsize(L, size);
    return 1;
}

/// mjolnir.window:settopleft(point)
/// Method
/// Moves the window to the given point in absolute coordinate.
static int window_settopleft(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    NSPoint thePoint = geom_topoint(L, 2);
    
    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage)
        CFRelease(positionStorage);
    
    return 0;
}

/// mjolnir.window:setsize(size)
/// Method
/// Resizes the window.
static int window_setsize(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    NSSize theSize = geom_tosize(L, 2);
    
    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage)
        CFRelease(sizeStorage);
    
    return 0;
}

/// mjolnir.window:close() -> bool
/// Method
/// Closes the window; returns whether it succeeded.
static int window_close(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    BOOL worked = NO;
    AXUIElementRef button = NULL;
    
    if (AXUIElementCopyAttributeValue(win, kAXCloseButtonAttribute, (CFTypeRef*)&button) != noErr) goto cleanup;
    if (AXUIElementPerformAction(button, kAXPressAction) != noErr) goto cleanup;
    
    worked = YES;
    
cleanup:
    if (button) CFRelease(button);
    
    lua_pushboolean(L, worked);
    return 1;
}

/// mjolnir.window:setfullscreen(bool) -> bool
/// Method
/// Sets whether the window is full screen; returns whether it succeeded.
static int window_setfullscreen(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CFBooleanRef befullscreen = lua_toboolean(L, 2) ? kCFBooleanTrue : kCFBooleanFalse;
    BOOL succeeded = (AXUIElementSetAttributeValue(win, CFSTR("AXFullScreen"), befullscreen) == noErr);
    lua_pushboolean(L, succeeded);
    return 1;
}

/// mjolnir.window:isfullscreen() -> bool or nil
/// Method
/// Returns whether the window is full screen, or nil if asking that question fails.
static int window_isfullscreen(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    id isfullscreen = nil;
    CFBooleanRef fullscreen = kCFBooleanFalse;
    
    if (AXUIElementCopyAttributeValue(win, CFSTR("AXFullScreen"), (CFTypeRef*)&fullscreen) != noErr) goto cleanup;
    
    isfullscreen = @(CFBooleanGetValue(fullscreen));
    
cleanup:
    if (fullscreen) CFRelease(fullscreen);
    
    if (isfullscreen)
        lua_pushboolean(L, [isfullscreen boolValue]);
    else
        lua_pushnil(L);
    
    return 1;
}

/// mjolnir.window:minimize()
/// Method
/// Minimizes the window.
static int window_minimize(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    set_window_prop(win, NSAccessibilityMinimizedAttribute, @YES);
    return 0;
}

/// mjolnir.window:unminimize()
/// Method
/// Un-minimizes the window.
static int window_unminimize(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    set_window_prop(win, NSAccessibilityMinimizedAttribute, @NO);
    return 0;
}

/// mjolnir.window:isminimized() -> bool
/// Method
/// True if the window is currently minimized in the dock.
static int window_isminimized(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    BOOL minimized = [get_window_prop(win, NSAccessibilityMinimizedAttribute, @(NO)) boolValue];
    lua_pushboolean(L, minimized);
    return 1;
}

// private function
// in:  [win]
// out: [pid]
static int window_pid(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    pid_t pid = 0;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess) {
        lua_pushnumber(L, pid);
        return 1;
    }
    else {
        return 0;
    }
}

/// mjolnir.window:application() -> app
/// Method
/// Returns the app that the window belongs to; may be nil.
static int window_application(lua_State* L) {
    if (window_pid(L)) {
        pid_t pid = lua_tonumber(L, -1);
        new_application(L, pid);
    }
    else {
        lua_pushnil(L);
    }
    return 1;
}

/// mjolnir.window:becomemain() -> bool
/// Method
/// Make this window the main window of the given application; deos not implicitly focus the app.
static int window_becomemain(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    
    BOOL success = (AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue) == kAXErrorSuccess);
    lua_pushboolean(L, success);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    lua_newtable(L);
    
    CFArrayRef wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    
    for (int i = 0; i < CFArrayGetCount(wins); i++) {
        int winid = (int)CFArrayGetValueAtIndex(wins, i);
        
        lua_pushnumber(L, winid);
        lua_rawseti(L, -2, i+1);
    }
    
    CFRelease(wins);
    
    return 1;
}

/// mjolnir.window:id() -> number, sometimes nil
/// Method
/// Returns a unique number identifying this window.
static int window_id(lua_State* L) {
    lua_settop(L, 1);
    AXUIElementRef win = get_window_arg(L, 1);
    
    lua_getuservalue(L, 1);
    
    lua_getfield(L, -1, "id");
    if (lua_isnumber(L, -1))
        return 1;
    else
        lua_pop(L, 1);
    
    CGWindowID winid;
    AXError err = _AXUIElementGetWindow(win, &winid);
    if (err) {
        lua_pushnil(L);
        return 1;
    }
    
    // cache it
    lua_pushnumber(L, winid);
    lua_setfield(L, -2, "id");
    
    lua_pushnumber(L, winid);
    return 1;
}

static const luaL_Reg windowlib[] = {
    {"focusedwindow", window_focusedwindow},
    {"_orderedwinids", window__orderedwinids},
    
    {"title", window_title},
    {"subrole", window_subrole},
    {"role", window_role},
    {"isstandard", window_isstandard},
    {"topleft", window_topleft},
    {"size", window_size},
    {"settopleft", window_settopleft},
    {"setsize", window_setsize},
    {"minimize", window_minimize},
    {"unminimize", window_unminimize},
    {"isminimized", window_isminimized},
    {"pid", window_pid},
    {"application", window_application},
    {"becomemain", window_becomemain},
    {"id", window_id},
    {"close", window_close},
    {"setfullscreen", window_setfullscreen},
    {"isfullscreen", window_isfullscreen},
    
    {}
};

int luaopen_mjolnir_window_internal(lua_State* L) {
    luaL_newlib(L, windowlib);
    
    if (luaL_newmetatable(L, "mjolnir.window")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, window_gc);
        lua_setfield(L, -2, "__gc");
        
        lua_pushcfunction(L, window_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
