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

    return NSMakePoint(topLeft.x, topLeft.y);
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

    return NSMakeSize(size.width, size.height);
}

static int window_gc(lua_State* L) {
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

/// hs.window.timeout(value) -> boolean
/// Function
/// Sets the timeout value used in the accessibility API.
///
/// Parameters:
///  * value - The number of seconds for the new timeout value.
///
/// Returns:
///  * `true` is succesful otherwise `false` if an error occured.
static int window_timeout(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs: LS_TNUMBER, LS_TBREAK] ;
    NSNumber *value = [skin toNSObjectAtIndex:1] ;
    float fvalue = [value floatValue];
    AXError result = AXUIElementSetMessagingTimeout(system_wide_element(), fvalue);
    if (result == kAXErrorIllegalArgument) {
        [LuaSkin logError:@"hs.window.timeout() - One or more of the arguments is an illegal value (timeout values must be positive)."];
        lua_pushboolean(L, false);
        return 1;
    }
    if (result == kAXErrorInvalidUIElement) {
        [LuaSkin logError:@"hs.window.timeout() - The AXUIElementRef is invalid."];
        lua_pushboolean(L, false);
        return 1;
    }
    lua_pushboolean(L, true);
    return 1;
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


static AXUIElementRef get_window_tabs(AXUIElementRef win) {
    AXUIElementRef tabs = NULL;

    CFArrayRef children = NULL;
    if(AXUIElementCopyAttributeValues(win, kAXChildrenAttribute, 0, 100, &children) != noErr) goto cleanup;
    CFIndex count = CFArrayGetCount(children);

    CFTypeRef typeRef;
    for (CFIndex i = 0; i < count; ++i) {
        AXUIElementRef child = CFArrayGetValueAtIndex(children, i);
        if(AXUIElementCopyAttributeValue(child, kAXRoleAttribute, &typeRef) != noErr) goto cleanup;
        CFStringRef role = (CFStringRef)typeRef;
        BOOL correctRole = kCFCompareEqualTo == CFStringCompare(role, kAXTabGroupRole, 0);
        CFRelease(role);
        if (correctRole) {
            tabs = child;
            CFRetain(tabs);
            break;
        }
    }

    cleanup:
    if(children) CFRelease(children);

    return tabs;
}

// tabIndex is a 0-based index of the tab to select
static BOOL window_presstab(AXUIElementRef win, CFIndex tabIndex) {
    BOOL worked = NO;
    CFArrayRef children = NULL;
    AXUIElementRef tab = NULL;

    AXUIElementRef tabs = get_window_tabs(win);
    if(tabs == NULL) goto cleanup;

    if(AXUIElementCopyAttributeValues(tabs, kAXTabsAttribute, 0, 100, &children) != noErr) goto cleanup;
    CFIndex count = CFArrayGetCount(children);

    CFIndex i = tabIndex;
    if(i >= count || i < 0) i = count - 1;
    tab = CFArrayGetValueAtIndex(children, i);

    if (AXUIElementPerformAction(tab, kAXPressAction) != noErr) goto cleanup;

    worked = YES;
cleanup:
    if (tabs) CFRelease(tabs);
    if (children) CFRelease(children);

    return worked;
}

static CFIndex window_counttabs(AXUIElementRef win) {
  CFIndex count = -1;

  AXUIElementRef tabs = get_window_tabs(win);
  if(tabs == NULL) goto cleanup;

  if(AXUIElementGetAttributeValueCount(tabs, kAXTabsAttribute, &count) != noErr) {
    count = -1; // it's probably still -1, but just to be safe
    goto cleanup;
  }

cleanup:
  if (tabs) CFRelease(tabs);

  return count;
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.window", LS_TBREAK];

    AXUIElementRef win = get_window_arg(L, 1);
    [skin pushNSPoint:get_window_topleft(win)];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.window", LS_TBREAK];

    AXUIElementRef win = get_window_arg(L, 1);
    [skin pushNSSize:get_window_size(win)];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.window", LS_TTABLE, LS_TBREAK];

    AXUIElementRef win = get_window_arg(L, 1);
    NSPoint thePoint = [skin tableToPointAtIndex:2];

    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage)
        CFRelease(positionStorage);

    lua_pushvalue(L, 1);
    return 1;
}

//TODO window__setframe, but it's Yosemite only :/
//https://developer.apple.com/library/prerelease/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/occ/intfp/NSAccessibility/accessibilityFrame

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.window", LS_TTABLE, LS_TBREAK];

    AXUIElementRef win = get_window_arg(L, 1);
    NSSize theSize = [skin tableToSizeAtIndex:2];

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
static int window__togglezoom(lua_State* L) {
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

/// hs.window:isMaximizable() -> bool or nil
/// Method
/// Determines if a window is maximizable
///
/// Paramters:
///  * None
///
/// Returns:
///  * True if the window is maximizable, False if it isn't, or nil if an error occurred
static int window_isMaximizable(lua_State *L) {
    AXUIElementRef win = get_window_arg(L, 1);
    AXUIElementRef button = nil;
    CFBooleanRef isEnabled;

    if (AXUIElementCopyAttributeValue(win, kAXZoomButtonAttribute, (CFTypeRef*)&button) != noErr) goto cleanup;
    if (AXUIElementCopyAttributeValue(button, kAXEnabledAttribute, (CFTypeRef*)&isEnabled) != noErr) goto cleanup;

    lua_pushboolean(L, isEnabled == kCFBooleanTrue ? true : false);
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
static int window__close(lua_State* L) {
    return window_pressbutton(L, kAXCloseButtonAttribute);
}

/// hs.window:focusTab(index) -> bool
/// Method
/// Focuses the tab in the window's tab group at index, or the last tab if
/// index is out of bounds. Returns true if a tab was pressed.
/// Works with document tab groups and some app tabs, like Chrome and Safari.
///
/// Parameters:
///  * index - A number, a 1-based index of a tab to focus
///
/// Returns:
///  * true if the tab was successfully pressed, or false if there was a problem
static int window_focustab(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CFIndex tabIndex = luaL_checkinteger(L, 2);

    BOOL worked = window_presstab(win, tabIndex - 1);
    lua_pushboolean(L, worked);
    return 1;
}

/// hs.window:tabCount() -> number or nil
/// Method
/// Gets the number of tabs in the window has, or nil if the window doesn't have tabs.
/// Intended for use with the focusTab method, if this returns a number, then focusTab
/// can switch between that many tabs.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of tabs, or nil if an error occurred
static int window_tabcount(lua_State* L) {
  AXUIElementRef win = get_window_arg(L, 1);

  CFIndex count = window_counttabs(win);

  if(count == -1) {
    return 0;
  } else {
    lua_pushinteger(L, count);
    return 1;
  }
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
static int window__setfullscreen(lua_State* L) {
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
///
/// Notes:
///  * This method will always animate per your system settings and is not affected by `hs.window.animationDuration`
static int window__minimize(lua_State* L) {
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
static int window__unminimize(lua_State* L) {
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
        pid_t pid = (pid_t)lua_tointeger(L, -1);
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

/// hs.window:raise() -> window
/// Method
/// Brings a window to the front of the screen without focussing it
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window` object
static int window_raise(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    AXUIElementPerformAction (win, kAXRaiseAction);

    lua_pushvalue(L, 1);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    lua_newtable(L);

    CFArrayRef wins = NULL ;
    wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    if (wins) {
        for (int i = 0; i < CFArrayGetCount(wins); i++) {
            int winid = (int)CFArrayGetValueAtIndex(wins, i);

            lua_pushinteger(L, winid);
            lua_rawseti(L, -2, i+1);
        }

        CFRelease(wins);
    } else {
        [LuaSkin logBreadcrumb:@"hs.window._orderedwinids CGWindowListCreate returned NULL"] ;
    }
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

// used by hs.window.snapshotForID and hs.window:snapshot

static int snapshot_common_code(lua_State* L, CGWindowID windowID, CGWindowImageOption makeOpaque) {
        LuaSkin *skin = [LuaSkin shared];
//         CGRect windowRect = { get_window_topleft(win), get_window_size(win) };
        CGRect windowRect = CGRectNull ;

        CFArrayRef targetWindow = CFArrayCreate(NULL, (const void **)(&windowID), 1, NULL);
        CGImageRef windowImage = CGWindowListCreateImageFromArray(
              windowRect,
              targetWindow,
              kCGWindowImageBoundsIgnoreFraming | makeOpaque);
        CFRelease(targetWindow);

        if (!windowImage) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"hs.window::snapshot: ERROR: CGWindowListCreateImageFromArray failed for windowID: %ld", (long) windowID]];
            return 0;
        }

        NSImage *newImage = [[NSImage alloc] initWithCGImage:windowImage size:windowRect.size] ;

        CGImageRelease(windowImage) ;

        [[LuaSkin shared] pushNSObject:newImage] ;
        return 1 ;
}

// I could have overloaded snapshot, but if we ever do split the module functions and the window object methods, it would be... problematic to document since syntax and function/method designations would differ and our current documentation processor can't handle that.

/// hs.window.snapshotForID(ID [, keepTransparency]) -> hs.image-object
/// Function
/// Returns a snapshot of the window specified by the ID as an `hs.image` object
///
/// Parameters:
///  * ID - Window ID of the window to take a snapshot of.
///  * keepTransparency - optional boolean value indicating if the windows alpha value (transparency) should be maintained in the resulting image or if it should be fully opaque (default).
///
/// Returns:
///  * `hs.image` object of the window snapshot or nil if unable to create a snapshot
///
/// Notes:
///  * See also method `hs.window:snapshot()`
///  * Because the window ID cannot always be dynamically determined, this function will allow you to provide the ID of a window that was cached earlier.
static int window_snapshotForID(lua_State* L) {
    CGWindowID windowID = (CGWindowID)luaL_checkinteger(L, 1);

    CGWindowImageOption makeOpaque = kCGWindowImageShouldBeOpaque ;
    if (lua_toboolean(L, 2)) makeOpaque = kCGWindowImageDefault ;

    return snapshot_common_code(L, windowID, makeOpaque) ;
}

/// hs.window:snapshot([keepTransparency]) -> hs.image-object
/// Method
/// Returns a snapshot of the window as an `hs.image` object
///
/// Parameters:
///  * keepTransparency - optional boolean value indicating if the windows alpha value (transparency) should be maintained in the resulting image or if it should be fully opaque (default).
///
/// Returns:
///  * `hs.image` object of the window snapshot or nil if unable to create a snapshot
///
/// Notes:
///  * See also function `hs.window.snapshotForID()`
static int window_snapshot(lua_State* L) {
    AXUIElementRef win = get_window_arg(L, 1);
    CGWindowID windowID;
    AXError err = _AXUIElementGetWindow(win, &windowID);

    if (!err) {
        CGWindowImageOption makeOpaque = kCGWindowImageShouldBeOpaque ;
        if (lua_toboolean(L, 2)) makeOpaque = kCGWindowImageDefault ;

        return snapshot_common_code(L, windowID, makeOpaque) ;
    } else {
        [[LuaSkin shared] logWarn:@"hs.window:snapshot() Unable to retrieve CGWindowID for specified window."] ;
        return 0 ;
    }
}

// Trying to make this as close to paste and apply as possible, so not all aspects may apply
// to each module... you may still need to tweak for your specific module.

static int userdata_tostring(lua_State* L) {

// For older modules that don't use this macro, Change this:
#ifndef USERDATA_TAG
#define USERDATA_TAG "hs.window"
#endif

// can't assume, since some older modules and userdata share __index
    void *self = lua_touserdata(L, 1) ;
    if (self) {
// Change these to get the desired title, if available, for your module:
        AXUIElementRef win ;
        win = get_window_arg(L, 1) ;
        NSString* title = get_window_prop(win, NSAccessibilityTitleAttribute, @"");
// Use this instead, if you always want the title portion empty for your module
//        NSString* title = @"" ;

// Common code begins here:

       lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    } else {
// For modules which share the same __index for the module table and the userdata objects, this replicates
// current default, which treats the module as a table when checking for __tostring.  You could also put a fancier
// string here for your module and set userdata_tostring as the module's __tostring as well...
//
// See lauxlib.c -- luaL_tolstring would invoke __tostring and loop, so let's
// use its output for tables (the "default:" case in luaL_tolstring's switch)
        lua_pushfstring(L, "%s: %p", luaL_typename(L, 1), lua_topointer(L, 1));
    }
    return 1 ;
}

static const luaL_Reg windowlib[] = {
    {"focusedWindow", window_focusedwindow},
    {"_orderedwinids", window__orderedwinids},
    {"setShadows", window_setShadows},
    {"snapshotForID", window_snapshotForID},

    {"title", window_title},
    {"subrole", window_subrole},
    {"role", window_role},
    {"isStandard", window_isstandard},
    {"_topLeft", window__topleft},
    {"_size", window__size},
    {"_setTopLeft", window__settopleft},
    {"_setSize", window__setsize},
    {"_minimize", window__minimize},
    {"_unminimize", window__unminimize},
    {"isMinimized", window_isminimized},
    {"isMaximizable", window_isMaximizable},
    {"pid", window_pid},
    {"application", window_application},
    {"focusTab", window_focustab},
    {"tabCount", window_tabcount},
    {"becomeMain", window_becomemain},
    {"raise", window_raise},
    {"id", window_id},
    {"_toggleZoom", window__togglezoom},
    {"zoomButtonRect", window_getZoomButtonRect},
    {"_close", window__close},
    {"_setFullScreen", window__setfullscreen},
    {"isFullScreen", window_isfullscreen},
    {"snapshot", window_snapshot},
    {"timeout", window_timeout},

    {NULL, NULL}
};

int luaopen_hs_window_internal(lua_State* L) {
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

        lua_pushcfunction(L, userdata_tostring) ;
        lua_setfield(L, -2, "__tostring") ;

        lua_pushcfunction(L, window_gc);
        lua_setfield(L, -2, "__gc");

        lua_pushstring(L, "hs.window");
        lua_setfield(L, -2, "__type");
    }
    lua_pop(L, 1);

    return 1;
}
