#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "window.h"
#import "../application/application.h"
#import "../uielement/uielement.h"

static const char *USERDATA_TAG = "hs.window";
static int refTable = LUA_NOREF;
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

#pragma mark - HSwindow implementation

@implementation HSwindow

#pragma mark - Class methods
+(NSArray<NSNumber *>*)orderedWindowIDs {
    NSMutableArray *windowIDs = [[NSMutableArray alloc] init];
    CFArrayRef wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);

    if (wins) {
        windowIDs = [[NSMutableArray alloc] initWithCapacity:CFArrayGetCount(wins)];
        for (int i = 0; i < CFArrayGetCount(wins); i++) {
            int winid = (int)CFArrayGetValueAtIndex(wins, i);
            [windowIDs addObject:[NSNumber numberWithInt:winid]];
        }
        CFRelease(wins);
    } else {
        [LuaSkin logBreadcrumb:@"hs.window._orderedwinids CGWindowListCreate returned NULL"] ;
    }
    return windowIDs;
}

+(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency {
    NSImage *image = nil;
    CGWindowImageOption makeOpaque = keepTransparency ? kCGWindowImageDefault : kCGWindowImageShouldBeOpaque;
    CGRect windowRect = CGRectNull;
    CFArrayRef targetWindow = CFArrayCreate(NULL, (const void **)(&windowID), 1, NULL);
    CGImageRef windowImage = CGWindowListCreateImageFromArray(windowRect,
                                                              targetWindow,
                                                              kCGWindowImageBoundsIgnoreFraming | makeOpaque);
    CFRelease(targetWindow);
    if (windowImage) {
        image = [[NSImage alloc] initWithCGImage:windowImage size:windowRect.size];
        CFRelease(windowImage);
    }
    return image;
}

+(HSwindow *)focusedWindow {
    HSwindow *window = nil;
    CFTypeRef app;
    AXUIElementCopyAttributeValue(system_wide_element(), kAXFocusedApplicationAttribute, &app);

    if (app) {
        CFTypeRef win;
        AXError result = AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &win);

        CFRelease(app);

        if (result == kAXErrorSuccess) {
            window = [[HSwindow alloc] initWithAXUIElementRef:win];
        }
    }
    return window;

}

#pragma mark - Initialiser
-(HSwindow *)initWithAXUIElementRef:(AXUIElementRef)winRef {
    self = [super init];
    if (self) {
        _elementRef = winRef;
        _selfRefCount = 0;

        pid_t pid;
        if (AXUIElementGetPid(winRef, &pid) == kAXErrorSuccess) {
            _pid = pid;
        }

        CGWindowID winID;
        AXError err = _AXUIElementGetWindow(winRef, &winID);
        if (!err) {
            _winID = winID;
        }
    }
    return self;
}

#pragma mark - Destructor
-(void)dealloc {
    CFRelease(self.elementRef);
}

#pragma mark - Instance methods
-(id)getWindowProperty:(NSString *)property withDefaultValue:(id)defaultValue {
    CFTypeRef value;
    if (AXUIElementCopyAttributeValue(self.elementRef, (__bridge CFStringRef)property, &value) == kAXErrorSuccess) {
        return CFBridgingRelease(value);
    }
    return defaultValue;
}

-(BOOL)setWindowProperty:(NSString *)property withValue:(id)value {
    BOOL result = NO;
    if ([value isKindOfClass:NSNumber.class]) {
        result = (AXUIElementSetAttributeValue(self.elementRef, (__bridge CFStringRef)property, (__bridge CFTypeRef)value) == kAXErrorSuccess);
    }
    return result;
}

-(NSString *)title {
    return [self getWindowProperty:NSAccessibilityTitleAttribute withDefaultValue:@""];
}

-(NSString *)subRole {
    return [self getWindowProperty:NSAccessibilitySubroleAttribute withDefaultValue:@""];
}

-(NSString *)role {
    return [self getWindowProperty:NSAccessibilityRoleAttribute withDefaultValue:@""];
}

-(BOOL)isStandard {
    return [self.subRole isEqualToString:(NSString *)kAXStandardWindowSubrole];
}

// FIXME: Can getTopLeft/setTopLeft be converted to use/augment getWindowProperty/setWindowProperty?
-(NSPoint)getTopLeft {
    CGPoint topLeft = CGPointZero;
    CFTypeRef positionStorage;
    if (AXUIElementCopyAttributeValue(self.elementRef, (CFStringRef)NSAccessibilityPositionAttribute, &positionStorage) == kAXErrorSuccess) {
        if (!AXValueGetValue(positionStorage, kAXValueCGPointType, (void *)&topLeft)) {
            topLeft = CGPointZero;
        }
        CFRelease(positionStorage);
    }
    return NSMakePoint(topLeft.x, topLeft.y);
}

-(void)setTopLeft:(NSPoint)topLeft {
    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&topLeft));
    AXUIElementSetAttributeValue(self.elementRef, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage) {
        CFRelease(positionStorage);
    }
}

-(NSSize)getSize {
    CGSize size = CGSizeZero;
    CFTypeRef sizeStorage;
    if (AXUIElementCopyAttributeValue(self.elementRef, (CFStringRef)NSAccessibilitySizeAttribute, &sizeStorage) == kAXErrorSuccess) {
        if (!AXValueGetValue(sizeStorage, kAXValueCGSizeType, (void *)&size)) {
            size = CGSizeZero;
        }
        CFRelease(sizeStorage);
    }
    return NSMakeSize(size.width, size.height);
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSwindow focusedWindow]];
    return 1;
}

static id get_window_prop(AXUIElementRef win, NSString* propType, id defaultValue) {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(win, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);

    return defaultValue;
}

-(void)setSize:(NSSize)size {
    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&size));
    AXUIElementSetAttributeValue(self.elementRef, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage) {
        CFRelease(sizeStorage);
    }
}

-(BOOL)pushButton:(CFStringRef)buttonId {
    BOOL worked = NO;
    AXUIElementRef button = NULL;
    if (AXUIElementCopyAttributeValue(self.elementRef, buttonId, (CFTypeRef*)&button) == noErr) {
        if (AXUIElementPerformAction(button, kAXPressAction) == noErr) {
            worked = YES;
        }
        CFRelease(button);
    }
    return worked;
}

-(void)toggleZoom {
    [self pushButton:kAXZoomButtonAttribute];
}

-(NSRect)getZoomButtonRect {
    NSRect rect = NSZeroRect;
    AXUIElementRef button = nil;
    CFTypeRef pointRef, sizeRef;
    CGPoint point;
    CGSize size;

    if (AXUIElementCopyAttributeValue(self.elementRef, kAXZoomButtonAttribute, (CFTypeRef*)&button) == noErr) {
        if ((AXUIElementCopyAttributeValue(button, kAXPositionAttribute, &pointRef) == noErr) && (AXUIElementCopyAttributeValue(button, kAXSizeAttribute, &sizeRef) == noErr)) {
                if (AXValueGetValue(pointRef, kAXValueCGPointType, &point) && AXValueGetValue(sizeRef, kAXValueCGSizeType, &size)) {
                    rect = NSMakeRect(point.x, point.y, size.width, size.height);
                }
        }
        CFRelease(button);
    }
    return rect;
}

-(BOOL)close {
    return [self pushButton:kAXCloseButtonAttribute];
}

-(int)getTabCount {
    CFIndex count = 0;
    AXUIElementRef tabs = get_window_tabs(self.elementRef);
    if (tabs) {
        AXUIElementGetAttributeValueCount(tabs, kAXTabsAttribute, &count);
        CFRelease(tabs);
    }
    return (int)count;
}

-(BOOL)focusTab:(int)index {
    BOOL worked = NO;
    CFArrayRef children = NULL;
    AXUIElementRef tab = NULL;

    AXUIElementRef tabs = get_window_tabs(self.elementRef);
    if(tabs == NULL) goto cleanup;

    if(AXUIElementCopyAttributeValues(tabs, kAXTabsAttribute, 0, 100, &children) != noErr) goto cleanup;
    CFIndex count = CFArrayGetCount(children);

    CFIndex i = index;
    if(i >= count || i < 0) i = count - 1;
    tab = CFArrayGetValueAtIndex(children, i);

    if (AXUIElementPerformAction(tab, kAXPressAction) != noErr) goto cleanup;

    worked = YES;
cleanup:
    if (tabs) CFRelease(tabs);
    if (children) CFRelease(children);

    return worked;
}

-(void)setFullscreen:(BOOL)fullscreen {
    AXUIElementSetAttributeValue(self.elementRef, CFSTR("AXFullScreen"), fullscreen ? kCFBooleanTrue : kCFBooleanFalse);
}

-(BOOL)isFullscreen {
    BOOL fullscreen = NO;
    CFBooleanRef _fullscreen = kCFBooleanFalse;
    if (AXUIElementCopyAttributeValue(self.elementRef, CFSTR("AXFullScreen"), (CFTypeRef*)&_fullscreen) == noErr) {
        fullscreen = CFBooleanGetValue(_fullscreen);
        CFRelease(_fullscreen);
    }
    return fullscreen;
}

-(BOOL)isMinimized {
    NSNumber *minimized = [self getWindowProperty:NSAccessibilityMinimizedAttribute withDefaultValue:@(NO)];
    return minimized.boolValue;
}

-(void)setMinimized:(BOOL)minimize {
    [self setWindowProperty:NSAccessibilityMinimizedAttribute withValue:@(minimize)];
}

-(void)becomeMain {
    [self setWindowProperty:NSAccessibilityMainAttribute withValue:@(YES)];
}

-(void)raise {
    AXUIElementPerformAction(self.elementRef, kAXRaiseAction);
}

-(NSImage *)snapshot:(BOOL)keepTransparency {
    NSImage *image = nil;
    CGWindowID windowID;
    if (_AXUIElementGetWindow(self.elementRef, &windowID) == kAXErrorSuccess) {
        image = [HSwindow snapshotForID:windowID keepTransparency:keepTransparency];
    }
    return image;
}
@end

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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSRect:win.zoomButtonRect];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, [win close]);
    return 1;
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TINTEGER, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    int tabIndex = (int)lua_tointeger(L, 2);
    lua_pushboolean(L, [win focusTab:tabIndex]);
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, win.minimized);
    return 1;
}

// hs.window:pid()
static int window_pid(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    HSapplication *app = [[HSapplication alloc] initWithPid:win.pid];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [win raise];
    lua_pushvalue(L, 1);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[win snapshot:lua_toboolean(L, 2)]];
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
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSwindow *win = [skin toNSObjectAtIndex:1];
    lua_pushstring(L, [NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, win.title, lua_topointer(L, 1)].UTF8String);
    return 1 ;
}

static int userdata_eq(lua_State *L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared];
        HSwindow *win1 = [skin toNSObjectAtIndex:1];
        HSwindow *win2 = [skin toNSObjectAtIndex:2];
        isEqual = CFEqual(win1.elementRef, win2.elementRef);
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

static int userdata_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
    {"timeout", window_timeout},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},

    {NULL, NULL}
};

int luaopen_hs_window_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:moduleLib metaFunctions:module_metaLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSwindow         forClass:"HSwindow"];
    [skin registerLuaObjectHelper:toHSwindowFromLua forClass:"HSwindow"
                                         withUserdataMapping:USERDATA_TAG];
    return 1;
}
