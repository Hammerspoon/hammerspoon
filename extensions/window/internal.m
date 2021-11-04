#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "HSuicore.h"

static const char *USERDATA_TAG = "hs.window";
static LSRefTable refTable = LUA_NOREF;
#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Helper functions

static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

/// hs.window.list(allWindows) -> table
/// Function
/// Gets a table containing all the window data retrieved from `CGWindowListCreate`.
///
/// Parameters:
///  * allWindows - Get all the windows, even those "below" the Dock window.
///
/// Returns:
///  * `true` is succesful otherwise `false` if an error occured.
///
/// Notes:
///  * This allows you to get window information without Accessibility Permissions.
static int window_list(lua_State* L) {
    // SOURCE: https://stackoverflow.com/a/15985829/6925202
    BOOL allWindows = lua_toboolean(L, 1);

    // Fetch all on screen windows
    CFArrayRef windowListArray = CGWindowListCreate(kCGWindowListOptionOnScreenOnly|kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSArray *windows = CFBridgingRelease(CGWindowListCreateDescriptionFromArray(windowListArray));

    if (!allWindows) {
        // Find window ID of "Dock" window
        NSNumber *dockWindowNumber = nil;
        for (NSDictionary *window in windows) {
            if ([(NSString *)window[(__bridge NSString *)kCGWindowName] isEqualToString:@"Dock"]) {
                dockWindowNumber = window[(__bridge NSString *)kCGWindowNumber];
                break;
            }
        }
        if (dockWindowNumber) {
            // Fetch on screen windows again, filtering to those "below" the Dock window
            // This filters out all but the "standard" application windows

            CFRelease(windowListArray);
            windowListArray = CGWindowListCreate(kCGWindowListOptionOnScreenBelowWindow|kCGWindowListExcludeDesktopElements, [dockWindowNumber unsignedIntValue]);
            windows = CFBridgingRelease(CGWindowListCreateDescriptionFromArray(windowListArray));
        }
    }
    CFRelease(windowListArray);

    [[LuaSkin sharedWithState:NULL] pushNSObject:windows] ;
    return 1 ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSwindow focusedWindow]];
    return 1;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:win.title];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:win.subRole];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:win.role];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, win.isStandard);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSPoint:win.topLeft];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSSize:win.size];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    win.topLeft = [skin tableToPointAtIndex:2];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    win.size = [skin tableToSizeAtIndex:2];
    lua_pushvalue(L, 1);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [win toggleZoom];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSRect:win.zoomButtonRect];
    return 1;
}

/// hs.window:isMaximizable() -> bool or nil
/// Method
/// Determines if a window is maximizable
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is maximizable, False if it isn't, or nil if an error occurred
static int window_isMaximizable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];

    AXUIElementRef button = nil;
    CFBooleanRef isEnabled;

    if (AXUIElementCopyAttributeValue(win.elementRef, kAXZoomButtonAttribute, (CFTypeRef*)&button) != noErr) goto cleanup;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, [win close]);
    return 1;
}

/// hs.window:focusTab(index) -> bool
/// Method
/// Focuses the tab in the window's tab group at index, or the last tab if index is out of bounds
///
/// Parameters:
///  * index - A number, a 1-based index of a tab to focus
///
/// Returns:
///  * true if the tab was successfully pressed, or false if there was a problem
///
/// Notes:
///  * This method works with document tab groups and some app tabs, like Chrome and Safari.
static int window_focustab(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    int tabIndex = (int)lua_tointeger(L, 2);
    lua_pushboolean(L, [win focusTab:tabIndex]);
    return 1;
}

/// hs.window:tabCount() -> number or nil
/// Method
/// Gets the number of tabs in the window has
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of tabs, or nil if an error occurred
///
/// Notes:
///  * Intended for use with the focusTab method, if this returns a number, then focusTab can switch between that many tabs.
static int window_tabcount(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushinteger(L, win.tabCount);
    return 1;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    win.fullscreen = lua_toboolean(L, 2);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, win.fullscreen);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    win.minimized = YES;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    win.minimized = NO;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, win.minimized);
    return 1;
}

// hs.window:pid()
static int window_pid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushinteger(L, win.pid);
    return 1;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    HSapplication *app = [[HSapplication alloc] initWithPid:win.pid withState:L];
    [skin pushNSObject:app];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [win becomeMain];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [win raise];
    lua_pushvalue(L, 1);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSwindow orderedWindowIDs]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushinteger(L, win.winID);
    return 1;
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

    // CoreGraphics private API for window shadows
    #define kCGSDebugOptionNormal    0
    #define kCGSDebugOptionNoShadows 16384
    void CGSSetDebugOptions(int);

    CGSSetDebugOptions(shadows ? kCGSDebugOptionNormal : kCGSDebugOptionNoShadows);

    return 0;
}

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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER|LS_TSTRING, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    CGWindowID windowID = (CGWindowID)lua_tointeger(L, 1);
    [skin pushNSObject:[HSwindow snapshotForID:windowID keepTransparency:lua_toboolean(L, 2)]];
    return 1;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[win snapshot:lua_toboolean(L, 2)]];
    return 1;
}

#pragma mark - hs.uielement methods

static int window_uielement_isApplication(lua_State *L) {
    // This method is a clone of what happens in hs.uielement:isApplication(), since hs.window objects have to conform to hs.uielement methods
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSapplication *app = [skin toNSObjectAtIndex:1];
    HSuielement *uiElement = app.uiElement;
    lua_pushboolean(L, [uiElement.role isEqualToString:@"AXApplication"]);

    return 1;
}

static int window_uielement_isWindow(lua_State *L) {
    // This method is a clone of what happens in hs.uielement:isWindow(), since hs.window objects have to conform to hs.uielement methods
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSapplication *app = [skin toNSObjectAtIndex:1];
    HSuielement *uiElement = app.uiElement;
    lua_pushboolean(L, uiElement.isWindow);

    return 1;
}

static int window_uielement_role(lua_State *L) {
    // This method is a clone of what happens in hs.uielement:role(), since hs.window objects have to conform to hs.uielement methods
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSapplication *app = [skin toNSObjectAtIndex:1];
    HSuielement *uiElement = app.uiElement;
    [skin pushNSObject:uiElement.role];

    return 1;
}

static int window_uielement_selectedText(lua_State *L) {
    // This method is a clone of what happens in hs.uielement:selectedText(), since hs.window objects have to conform to hs.uielement methods
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSapplication *app = [skin toNSObjectAtIndex:1];
    HSuielement *uiElement = app.uiElement;
    [skin pushNSObject:uiElement.selectedText];

    return 1;
}

static int window_uielement_newWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TANY|LS_TOPTIONAL, LS_TBREAK];

    HSwindow *win = [skin toNSObjectAtIndex:1];
    HSuielement *uiElement = win.uiElement;
    HSuielementWatcher *watcher = [uiElement newWatcherAtIndex:2 withUserdataAtIndex:3 withLuaState:L];
    [skin pushNSObject:watcher];

    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSwindow(lua_State *L, id obj) {
    HSwindow *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSwindow *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSwindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSwindow *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSwindow, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushstring(L, [NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, win.title, lua_topointer(L, 1)].UTF8String);
    return 1 ;
}

static int userdata_eq(lua_State *L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSwindow *win1 = [skin toNSObjectAtIndex:1];
        HSwindow *win2 = [skin toNSObjectAtIndex:2];
        isEqual = CFEqual(win1.elementRef, win2.elementRef);
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

static int userdata_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = get_objectFromUserdata(__bridge_transfer HSwindow, L, 1, USERDATA_TAG);
    if (win) {
        win.selfRefCount--;
        if (win.selfRefCount == 0) {
            win = nil;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think it's valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

// Module functions
static const luaL_Reg moduleLib[] = {
    {"focusedWindow", window_focusedwindow},
    {"_orderedwinids", window__orderedwinids},
    {"setShadows", window_setShadows},
    {"snapshotForID", window_snapshotForID},
    {"timeout", window_timeout},
    {"list", window_list},

    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
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

    // hs.uielement methods
    {"isApplication", window_uielement_isApplication},
    {"isWindow", window_uielement_isWindow},
    {"role", window_uielement_role},
    {"selectedText", window_uielement_selectedText},
    {"newWatcher", window_uielement_newWatcher},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},

    {NULL, NULL}
};

int luaopen_hs_libwindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:module_metaLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSwindow         forClass:"HSwindow"];
    [skin registerLuaObjectHelper:toHSwindowFromLua forClass:"HSwindow"
                                         withUserdataMapping:USERDATA_TAG];
    return 1;
}
