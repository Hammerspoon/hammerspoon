#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "window.h"
#import "../application/application.h"
#import "../uielement/uielement.h"

#define get_window_arg(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "hs.window"))

// CoreGraphics private API for window shadows
#define kCGSDebugOptionNormal    0
#define kCGSDebugOptionNoShadows 16384
void CGSSetDebugOptions(int);

NSAnimation *currentAnimation;

@interface TransformAnimation : NSAnimation <NSAnimationDelegate>

@property NSPoint newTopLeft;
@property NSPoint oldTopLeft;
@property NSSize newSize;
@property NSSize oldSize;

@property AXUIElementRef window;

@end

@implementation TransformAnimation

- (void)setCurrentProgress:(NSAnimationProgress)progress {
	[super setCurrentProgress:progress];
	float value = self.currentValue;

	NSPoint thePoint = (NSPoint) {
		_oldTopLeft.x + value * (_newTopLeft.x - _oldTopLeft.x),
		_oldTopLeft.y + value * (_newTopLeft.y - _oldTopLeft.y)
	};

	NSSize theSize = (NSSize) {
		_oldSize.width + value * (_newSize.width - _oldSize.width),
		_oldSize.height + value * (_newSize.height - _oldSize.height)
	};

	CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
	CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));

	AXUIElementSetAttributeValue(_window, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
	AXUIElementSetAttributeValue(_window, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);

	if (sizeStorage) CFRelease(sizeStorage);
	if (positionStorage) CFRelease(positionStorage);
}

- (void)animationDidEnd:(NSAnimation * __unused)animation {
    currentAnimation = nil;
}

- (void)animationDidStop:(NSAnimation * __unused)animation {
    currentAnimation = nil;
}
@end

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

static float get_float(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TNUMBER);
    float result = lua_tonumber(L, idx);
    lua_pop(L, 1);
    return result;
}

static NSPoint get_window_topleft(AXUIElementRef win) {
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

    if (positionStorage) CFRelease(positionStorage);

    return (NSPoint)topLeft;
}

static NSSize get_window_size(AXUIElementRef win) {
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

    if (sizeStorage) CFRelease(sizeStorage);

    return (NSSize)size;
}

static int window_transform(lua_State* L) {
    if (currentAnimation) {
        //currentAnimation.currentProgress = 1.0;
        [currentAnimation stopAnimation];
    }

    AXUIElementRef win = get_window_arg(L, 1);

    NSPoint thePoint = geom_topoint(L, 2);
    NSSize theSize = geom_tosize(L, 3);

    float duration = get_float(L, 4);

    NSPoint oldTopLeft = get_window_topleft(win);
    NSSize oldSize = get_window_size(win);

    TransformAnimation *anim = [[TransformAnimation alloc] initWithDuration:duration animationCurve:NSAnimationEaseInOut];
    currentAnimation = anim;
    anim.delegate = anim;
    anim.animationBlockingMode = NSAnimationNonblocking;

    [anim setOldTopLeft:oldTopLeft];
    [anim setNewTopLeft:thePoint];
    [anim setOldSize:oldSize];
    [anim setNewSize:theSize];
    [anim setWindow:win];

    /* [anim setAnimationBlockingMode:NSAnimationNonblocking]; */

    [anim setFrameRate: 60.0];
    [anim startAnimation];

    return 0;
}

static int window_gc(lua_State* L) {
    if (currentAnimation) {
        //currentAnimation.currentProgress = 1.0;
        [currentAnimation stopAnimation];
    }
    AXUIElementRef win = get_window_arg(L, 1);
    CFRelease(win);
    return 0;
}

static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

/// hs.window.focusedWindow() -> window
/// Constructor
/// Returns the window that has keyboard/mouse focus
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.window` object representing the currently focused window
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
    if (AXUIElementCopyAttributeValue(win, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);

    return defaultValue;
}

static BOOL set_window_prop(AXUIElementRef win, NSString* propType, id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        AXError result = AXUIElementSetAttributeValue(win, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
        if (result == kAXErrorSuccess)
            return YES;
    }
    return NO;
}

/// hs.window:title() -> string
/// Method
/// Gets the title of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the title of the window
static int window_title(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    NSString* title = get_window_prop(win, NSAccessibilityTitleAttribute, @"");
    lua_pushstring(L, [title UTF8String]);
    return 1;
}

/// hs.window:subrole() -> string
/// Method
/// Gets the subrole of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the subrole of the window
///
/// Notes:
///  * This typically helps to determine if a window is a special kind of window - such as a modal window, or a floating window
static int window_subrole(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    NSString* str = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");

    lua_pushstring(L, [str UTF8String]);
    return 1;
}

/// hs.window:role() -> string
/// Method
/// Gets the role of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the role of the window
static int window_role(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    NSString* str = get_window_prop(win, NSAccessibilityRoleAttribute, @"");

    lua_pushstring(L, [str UTF8String]);
    return 1;
}

/// hs.window:isStandard() -> bool
/// Method
/// Determines if the window is a standard window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is standard, otherwise false
///
/// Notes:
///  * "Standard window" means that this is not an unusual popup window, a modal dialog, a floating window, etc.
static int window_isstandard(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    NSString* subrole = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");

    BOOL is_standard = [subrole isEqualToString: (NSString*)kAXStandardWindowSubrole];
    lua_pushboolean(L, is_standard);
    return 1;
}

/// hs.window:topLeft() -> point
/// Method
/// Gets the absolute co-ordinates of the top left of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A point-table containing the absolute co-ordinates of the top left corner of the window
static int window__topleft(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CGPoint topLeft = get_window_topleft(win);
    geom_pushpoint(L, topLeft);
    return 1;
}

/// hs.window:size() -> size
/// Method
/// Gets the size of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A size-table containing the width and height of the window
static int window__size(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CGSize size = get_window_size(win);
    geom_pushsize(L, size);
    return 1;
}

/// hs.window:setTopLeft(point) -> window
/// Method
/// Moves the window to a given point
///
/// Parameters:
///  * point - A point-table containing the absolute co-ordinates the window should be moved to
///
/// Returns:
///  * The `hs.window` object
static int window__settopleft(lua_State* L) {
    if (currentAnimation) {
        //currentAnimation.currentProgress = 1.0;
        [currentAnimation stopAnimation];
    }
    AXUIElementRef win = get_window_arg(L, 1);
    NSPoint thePoint = geom_topoint(L, 2);

    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage)
        CFRelease(positionStorage);

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window:setSize(size) -> window
/// Method
/// Resizes the window
///
/// Parameters:
///  * size - A size-table containing the width and height the window should be resized to
///
/// Returns:
///  * The `hs.window` object
static int window__setsize(lua_State* L) {
    if (currentAnimation) {
        //currentAnimation.currentProgress = 1.0;
        [currentAnimation stopAnimation];
    }
    AXUIElementRef win = get_window_arg(L, 1);
    NSSize theSize = geom_tosize(L, 2);

    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage)
        CFRelease(sizeStorage);

    lua_pushvalue(L, 1);
    return 1;
}

static int window_pressbutton(lua_State* L, CFStringRef buttonId) {
    AXUIElementRef win = get_window_arg(L, 1);
    AXUIElementRef button = NULL;
    BOOL worked = NO;

    if (AXUIElementCopyAttributeValue(win, buttonId, (CFTypeRef*)&button) != noErr) goto cleanup;
    if (AXUIElementPerformAction(button, kAXPressAction) != noErr) goto cleanup;

    worked = YES;

cleanup:
    if (button) CFRelease(button);

    lua_pushboolean(L, worked);

    return 1;
}

/// hs.window:toggleZoom() -> window
/// Method
/// Toggles the zoom state of the window (this is effectively equivalent to clicking the green maximize/fullscreen button at the top left of a window)
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window` object
static int window_togglezoom(lua_State* L) {
    if (currentAnimation) {
        //currentAnimation.currentProgress = 1.0;
        [currentAnimation stopAnimation];
    }
    window_pressbutton(L, kAXZoomButtonAttribute);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window:zoomButtonRect() -> rect-table or nil
/// Method
/// Gets a rect-table for the location of the zoom button (the green button typically found at the top left of a window)
///
/// Parameters:
///  * None
///
/// Returns:
///  * A rect-table containing the bounding frame of the zoom button, or nil if an error occured
///
/// Notes:
///  * The co-ordinates in the rect-table (i.e. the `x` and `y` values) are in absolute co-ordinates, not relative to the window the button is part of, or the screen the window is on
///  * Although not perfect as such, this method can provide a useful way to find a region of the titlebar suitable for simulating mouse click events on, with `hs.eventtap`
static int window_getZoomButtonRect(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    AXUIElementRef button = nil;
    CFTypeRef pointRef;
    CFTypeRef sizeRef;
    CGPoint point;
    CGSize size;

    if (AXUIElementCopyAttributeValue(win, kAXZoomButtonAttribute, (CFTypeRef*)&button) != noErr) goto cleanup;
    if (AXUIElementCopyAttributeValue(button, kAXPositionAttribute, &pointRef) != noErr) goto cleanup;
    if (AXUIElementCopyAttributeValue(button, kAXSizeAttribute, &sizeRef) != noErr) goto cleanup;

    if (!AXValueGetValue(pointRef, kAXValueCGPointType, &point)) goto cleanup;
    if (!AXValueGetValue(sizeRef, kAXValueCGSizeType, &size)) goto cleanup;

    lua_newtable(L);

    lua_pushnumber(L, point.x);
    lua_setfield(L, -2, "x");

    lua_pushnumber(L, point.y);
    lua_setfield(L, -2, "y");

    lua_pushnumber(L, size.width);
    lua_setfield(L, -2, "w");

    lua_pushnumber(L, size.height);
    lua_setfield(L, -2, "h");

    return 1;
cleanup:
    lua_pushnil(L);
    return 1;
}

/// hs.window:close() -> bool
/// Method
/// Closes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the operation succeeded, false if not
static int window_close(lua_State* L) {
    return window_pressbutton(L, kAXCloseButtonAttribute);
}

/// hs.window:setFullScreen(fullscreen) -> window
/// Method
/// Sets the fullscreen state of the window
///
/// Parameters:
///  * fullscreen - A boolean, true if the window should be set fullscreen, false if not
///
/// Returns:
///  * The `hs.window` object
static int window_setfullscreen(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CFBooleanRef befullscreen = lua_toboolean(L, 2) ? kCFBooleanTrue : kCFBooleanFalse;
    AXUIElementSetAttributeValue(win, CFSTR("AXFullScreen"), befullscreen);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window:isFullScreen() -> bool or nil
/// Method
/// Gets the fullscreen state of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is fullscreen, false if not. Nil if an error occurred
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

/// hs.window:minimize() -> window
/// Method
/// Minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window` object
static int window_minimize(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    set_window_prop(win, NSAccessibilityMinimizedAttribute, @YES);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window:unminimize() -> window
/// Method
/// Un-minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window` object
static int window_unminimize(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    set_window_prop(win, NSAccessibilityMinimizedAttribute, @NO);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window:isMinimized() -> bool
/// Method
/// Gets the minimized state of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is minimized, otherwise false
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
    get_window_arg(L, 1);  // type checking
    lua_getuservalue(L, 1);
    lua_getfield(L, -1, "pid");
    if (lua_isinteger(L, -1))
        return 1;
    else
        return 0;
}

/// hs.window:application() -> app or nil
/// Method
/// Gets the `hs.application` object the window belongs to
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.application` object representing the application that owns the window, or nil if an error occurred
static int window_application(lua_State* L) {
    if (window_pid(L)) {
        pid_t pid = lua_tointeger(L, -1);
        if (!new_application(L, pid)) {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.window:becomeMain() -> window
/// Method
/// Makes the window the main window of its application
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window` object
///
/// Notes:
///  * Make a window become the main window does not transfer focus to the application. See `hs.window.focus()`
static int window_becomemain(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);

    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue);
    lua_pushvalue(L, 1);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    lua_newtable(L);

    CFArrayRef wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);

    for (int i = 0; i < CFArrayGetCount(wins); i++) {
        int winid = (int)CFArrayGetValueAtIndex(wins, i);

        lua_pushinteger(L, winid);
        lua_rawseti(L, -2, i+1);
    }

    CFRelease(wins);

    return 1;
}

/// hs.window:id() -> number or nil
/// Method
/// Gets the unique identifier of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the unique identifier of the window, or nil if an error occurred
static int window_id(lua_State* L) {
    get_window_arg(L, 1);  // type checking
    lua_getuservalue(L, 1);
    lua_getfield(L, -1, "id");
    if (lua_isinteger(L, -1))
        return 1;
    else
        return 0;
}

/// hs.window.setShadows(shadows)
/// Function
/// Enables/Disables window shadows
///
/// Parameters:
///  * shadows - A boolean, true to show window shadows, false to hide window shadows
///
/// Returns:
///  * None
///
/// Notes:
///  * This function uses a private, undocumented OS X API call, so it is not guaranteed to work in any future OS X release
static int window_setShadows(lua_State* L) {
    luaL_checktype(L, 1, LUA_TBOOLEAN);
    BOOL shadows = lua_toboolean(L, 1);

    CGSSetDebugOptions(shadows ? kCGSDebugOptionNormal : kCGSDebugOptionNoShadows);

    return 0;
}

static const luaL_Reg windowlib[] = {
    {"focusedWindow", window_focusedwindow},
    {"_orderedwinids", window__orderedwinids},
    {"setShadows", window_setShadows},

    {"title", window_title},
    {"subrole", window_subrole},
    {"role", window_role},
    {"isStandard", window_isstandard},
    {"_topLeft", window__topleft},
    {"_size", window__size},
    {"_setTopLeft", window__settopleft},
    {"_setSize", window__setsize},
    {"transform", window_transform},
    {"minimize", window_minimize},
    {"unminimize", window_unminimize},
    {"isMinimized", window_isminimized},
    {"pid", window_pid},
    {"application", window_application},
    {"becomeMain", window_becomemain},
    {"id", window_id},
    {"toggleZoom", window_togglezoom},
    {"zoomButtonRect", window_getZoomButtonRect},
    {"close", window_close},
    {"setFullScreen", window_setfullscreen},
    {"isFullScreen", window_isfullscreen},

    {}
};

int luaopen_hs_window_internal(lua_State* L) {
    currentAnimation = nil;
    luaL_newlib(L, windowlib);

    // Inherit hs.uielement
    luaL_getmetatable(L, "hs.uielement");
    lua_setmetatable(L, -2);

    if (luaL_newmetatable(L, "hs.window")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        // Use hs.uilement's equality
        luaL_getmetatable(L, "hs.uielement");
        lua_getfield(L, -1, "__eq");
        lua_remove(L, -2);
        lua_setfield(L, -2, "__eq");

        lua_pushcfunction(L, window_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);

    return 1;
}
