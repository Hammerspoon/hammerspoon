#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs.webview"
int refTable ;

static WKProcessPool *HSWebViewProcessPool ;

#define get_objectFromUserdata(objType, L, idx) (__bridge objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

// typedef struct _webview_t {
//     void *window;
// } webview_t;

@interface HSWebViewWindow : NSWindow <NSWindowDelegate>
@property BOOL allowKeyboard ;
@end

@interface HSWebViewView: WKWebView
@end

@implementation HSWebViewWindow
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation {

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        [self setDelegate:self];
        contentRect.origin.y=[[NSScreen screens][0] frame].size.height - contentRect.origin.y - contentRect.size.height;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor = [NSColor whiteColor];
        self.opaque = YES;
        self.hasShadow = NO;
        self.ignoresMouseEvents = NO;
        self.allowKeyboard = NO ;
        self.restorable = NO;
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        self.level = NSNormalWindowLevel;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return self.allowKeyboard ;
}

// NSWindowDelegate method. We decline to close the window because we don't want external things interfering with the user's decisions to display these objects.
- (BOOL)windowShouldClose:(id __unused)sender {
    if ((self.styleMask & NSClosableWindowMask) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}
@end

@implementation HSWebViewView
- (id)initWithFrame:(NSRect)frameRect configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frameRect configuration:configuration] ;
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    return YES ;
}

@end

// NOTE: WKWebView Related Methods

/// hs.webview.new(rect, [preferencesTable]) -> webviewObject
/// Constructor
/// Create a webviewObject and optionally modify its preferences.
///
/// Parameters:
///  * rect - a rectangle specifying where the webviewObject should be displayed.
///  * preferencesTable - an optional table which can include one of more of the following keys:
///   * javaEnabled                           - java is enabled (default false)
///   * javaScriptEnabled                     - javascript is enabled (default true)
///   * javaScriptCanOpenWindowsAutomatically - can javascript open windows without user intervention (default false)
///   * minimumFontSize                       - minimum font size (default 0.0)
///   * plugInsEnabled                        - plug-ins are enabled (default false)
///   * suppressesIncrementalRendering        - suppresses content rendering until fully loaded into memory (default false)
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * To set the initial URL, use the `hs.webview:url` method before showing the webview object.
///  * Preferences can only be set when the webview object is created.  To change the preferences of an open webview, you will need to close it and recreate it with this method.
static int webview_new(lua_State *L) {

    if (lua_type(L, 2) != LUA_TNONE) {
        luaL_checktype(L, 2, LUA_TTABLE) ;
    }

//     NSRect windowRect = [[LuaSkin shared] tableToRectAtIndex:1] ;
    luaL_checktype(L, 1, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, 1, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, 1, "y"), luaL_checknumber(L, -1));
    CGFloat w = (lua_getfield(L, 1, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, 1, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 4);
    NSRect windowRect = NSMakeRect(x, y, w, h);

    HSWebViewWindow *theWindow = [[HSWebViewWindow alloc] initWithContentRect:windowRect
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:YES];

    if (theWindow) {
        void** windowPtr = lua_newuserdata(L, sizeof(HSWebViewWindow *));
        *windowPtr = (__bridge_retained void *)theWindow ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        if (!HSWebViewProcessPool) HSWebViewProcessPool = [[WKProcessPool alloc] init] ;
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init] ;
        config.processPool = HSWebViewProcessPool ;

        if (lua_type(L, 2) == LUA_TTABLE) {
            WKPreferences *myPreferences = [[WKPreferences alloc] init] ;

            if (lua_getfield(L, 2, "javaEnabled") == LUA_TBOOLEAN)
                myPreferences.javaEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "javaScriptEnabled") == LUA_TBOOLEAN)
                myPreferences.javaScriptEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "javaScriptCanOpenWindowsAutomatically") == LUA_TBOOLEAN)
                myPreferences.javaScriptCanOpenWindowsAutomatically = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "plugInsEnabled") == LUA_TBOOLEAN)
                myPreferences.plugInsEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "minimumFontSize") == LUA_TNUMBER)
                myPreferences.minimumFontSize = (BOOL)lua_toboolean(L, -1) ;

            if (lua_getfield(L, 2, "suppressesIncrementalRendering") == LUA_TBOOLEAN)
                config.suppressesIncrementalRendering = (BOOL)lua_toboolean(L, -1) ;

            lua_pop(L, 6) ;
            config.preferences = myPreferences ;
        }

        HSWebViewView *theView = [[HSWebViewView alloc] initWithFrame:((NSView *)theWindow.contentView).bounds
                                                        configuration:config];
        theWindow.contentView = theView;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs.webview:delete()
/// Method
/// Destroys the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is automatically called during garbage collection (notably, when Hammerspoon is quit or its configuration is reloaded)
static int webview_delete(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;

    [theWindow close];
    theWindow = nil;
    return 0;
}

/// hs.webview:url([URL]) -> webviewObject | url
/// Method
/// Get or set the URL to render for the webview.
///
/// Parameters:
///  * URL - an optional string representing the URL to display.
///
/// Returns:
///  * If a URL is specified, then this method returns the webview Object; otherwise it returns the current url being displayed.
static int webview_url(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
//         [[LuaSkin shared] pushNSObject:[theView URL]] ;
        size_t size = [[[theView URL] description] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
        lua_pushlstring(L, [[[theView URL] description] UTF8String], size) ;
    } else {
//         NSString *theURL = [[LuaSkin shared] toNSObjectAtIndex:2] ;
        size_t size ;
        unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
        NSString *theURL = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;

        if (theURL) {
            [theView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:theURL]]] ;
        } else {
            return luaL_error(L, "Invalid URL type.  String expected.") ;
        }

        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:title() -> title
/// Method
/// Get the title of the page displayed in the webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the title
///
/// Notes:
///  * This method can be used with `hs.webview:windowTitle` to set the window title if the window style is titled.  E.g. `hs.webview:windowTitle(hs.webview:title())`
static int webview_title(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

//         [[LuaSkin shared] pushNSObject:[theView title]] ;
    size_t size = [[theView title] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
    lua_pushlstring(L, [[theView title] UTF8String], size) ;

    return 1 ;
}

/// hs.webview:loading() -> boolean
/// Method
/// Returns a boolean value indicating whether or not the vebview is still loading content.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the content is still being loaded, or false if it has completed.
static int webview_loading(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushboolean(L, [theView isLoading]) ;

    return 1 ;
}

/// hs.webview:stopLoading() -> webviewObject
/// Method
/// Stop loading content if the webview is still loading content.  Does nothing if content has already completed loading.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_stopLoading(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [theView stopLoading] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:estimatedProgress() -> number
/// Method
/// Returns the estimated percentage of expected content that has been loaded.  Will equal 1.0 when all content has been loaded.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a numerical value between 0.0 and 1.0 indicating the percentage of expected content which has been loaded.
static int webview_estimatedProgress(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushnumber(L, [theView estimatedProgress]) ;

    return 1 ;
}

/// hs.webview:isOnlySecureContent() -> bool
/// Method
/// Returns a boolean value indicating if all content current displayed in the webview was loaded over securely encrypted connections.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if all content current displayed in the web view was loaded over securely encrypted connections; otherwise false.
static int webview_isOnlySecureContent(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushboolean(L, [theView hasOnlySecureContent]) ;

    return 1 ;
}

/// hs.webview:goForward() -> webviewObject
/// Method
/// Move to the next page in the webview's history, if possible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview Object
static int webview_goForward(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goForward:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:goBack() -> webviewObject
/// Method
/// Move to the previous page in the webview's history, if possible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview Object
static int webview_goBack(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goBack:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:reload() -> webviewObject
/// Method
/// Reload the page in the webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_reload(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [theView reloadFromOrigin:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:allowMagnificationGesture([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview will respond to the magnification gesture from a trackpad.  Default is false.
///
/// Parameters:
///  * value - an optional boolean value indicating whether or not the webview should respond to magnification gestures.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowMagnificationGesture(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [theView allowsMagnification]) ;
    } else {
        [theView setAllowsMagnification:(BOOL)lua_toboolean(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:magnification([value]) -> webviewObject | current value
/// Method
/// Get or set the webviews current magnification level. Default is 1.0.
///
/// Parameters:
///  * value - an optional number specifying the webviews magnification level.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_magnification(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushnumber(L, [theView magnification]) ;
    } else {
        luaL_checktype(L, 2, LUA_TNUMBER) ;
        NSPoint centerOn ;

// Center point doesn't seem to do anything... will investigate further later...
//         if (lua_type(L, 3) == LUA_TTABLE) {
// //             centerOn = [[LuaSkin shared] tableToPointAtIndex:3] ;
//             CGFloat x = (lua_getfield(L, 3, "x"), luaL_checknumber(L, -1));
//             CGFloat y = (lua_getfield(L, 3, "y"), luaL_checknumber(L, -1));
//             lua_pop(L, 2);
//             centerOn = NSMakePoint(x, y);
//         } else if (lua_type(L, 3) != LUA_TNONE) {
//             return luaL_error(L, "invalid type specified for magnification center: %s", lua_typename(L, lua_type(L, 3))) ;
//         }

        [theView setMagnification:lua_tonumber(L, 2) centeredAtPoint:centerOn] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

// // Useful for testing, but since we can't change them after creation, not so useful otherwise.
// static int webview_preferences(lua_State *L) {
//     HSWebViewWindow        *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
//     HSWebViewView          *theView = theWindow.contentView ;
//     WKWebViewConfiguration *theConfiguration = [theView configuration] ;
//     WKPreferences          *thePreferences = [theConfiguration preferences] ;
//
//     lua_newtable(L) ;
//         lua_pushnumber(L, [thePreferences minimumFontSize]) ;                        lua_setfield(L, -2, "minimumFontSize") ;
//         lua_pushboolean(L, [thePreferences javaEnabled]) ;                           lua_setfield(L, -2, "javaEnabled") ;
//         lua_pushboolean(L, [thePreferences javaScriptEnabled]) ;                     lua_setfield(L, -2, "javaScriptEnabled") ;
//         lua_pushboolean(L, [thePreferences plugInsEnabled]) ;                        lua_setfield(L, -2, "plugInsEnabled") ;
//         lua_pushboolean(L, [thePreferences javaScriptCanOpenWindowsAutomatically]) ; lua_setfield(L, -2, "javaScriptCanOpenWindowsAutomatically") ;
//
//     return 1 ;
// }

// NOTE: Window Related Methods

/// hs.webview:show() -> webviewObject
/// Method
/// Displays the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_show(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    [theWindow makeKeyAndOrderFront:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:hide() -> webviewObject
/// Method
/// Hides the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_hide(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    [theWindow orderOut:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:allowTextEntry([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview can accept keyboard for web form entry. Defaults to false.
///
/// Parameters:
///  * value - an optional boolean value which sets whether or not the webview will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowTextEntry(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.allowKeyboard) ;
    } else {
        theWindow.allowKeyboard = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:allowMouseClicks([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview can accept mouse clicks for web navigation. Defaults to true.
///
/// Parameters:
///  * value - an optional boolean value which sets whether or not the webview will accept mouse clicks.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowMouseClicks(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, !theWindow.ignoresMouseEvents) ;
    } else {
        theWindow.ignoresMouseEvents = !(BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:asHSWindow() -> hs.window object
/// Method
/// Returns an hs.window object for the webview so that you can use hs.window methods on it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
///
/// Notes:
///  * hs.window:minimize only works if the webview is minimizable (see `hs.webview.windowStyle`)
///  * hs.window:setSize only works if the webview is resizable (see `hs.webview.windowStyle`)
///  * hs.window:close only works if the webview is closable (see `hs.webview.windowStyle`)
///  * hs.window:maximize will reposition the webview to the upper left corner of your screen, but will only resize the webview if the webview is resizable (see `hs.webview.windowStyle`)
static int webview_hswindow(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    CGWindowID windowID = (CGWindowID)[theWindow windowNumber];
    lua_getglobal(L, "require"); lua_pushstring(L, "hs.window"); lua_call(L, 1, 1);
    lua_getfield(L, -1, "windowForID") ;
    lua_pushinteger(L, windowID) ;
    lua_call(L, 1, 1) ;
    return 1 ;
}

typedef struct _drawing_t {
    void *window;
} drawing_t;

/// hs.webview:asHSDrawing() -> hs.drawing object
/// Method
/// Returns an hs.drawing object for the webview so that you can use hs.drawing methods on it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
///
/// Notes:
///  * Methods in hs.drawing which are specific to a single drawing type will not work with this object.
static int webview_hsdrawing(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    lua_getglobal(L, "require"); lua_pushstring(L, "hs.drawing"); lua_call(L, 1, 1);

    drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
    memset(drawingObject, 0, sizeof(drawing_t));
    drawingObject->window = (__bridge_retained void*)theWindow;
    luaL_getmetatable(L, "hs.drawing");
    lua_setmetatable(L, -2);

    return 1 ;
}

/// hs.webView:windowTitle(title) -> webviewObject
/// Method
/// Sets the title for the webview window.
///
/// Parameters:
///  * title - the title to set for the webview window
///
/// Returns:
///  * The webview Object
///
/// Notes:
///  * If you wish this to match the web page title, you can use `hs.webview:windowTitle(hs.webview:title())` after making sure `hs.webview:loading == false`.
///  * Any title set with this method will be hidden unless the window style includes the "titled" style (see `hs.webview.windowStyle` and `hs.webview.windowMasks`)
static int webview_windowTitle(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;

//     NSString        *theTitle = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    size_t size ;
    unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
    NSString *theTitle = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;

    [theWindow setTitle:theTitle] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview.windowMasks[]
/// Constant
/// A table containing valid masks for the webview window.
///
/// Table Keys:
///  * borderless         - The window has no border decorations (default)
///  * titled             - The window title bar is displayed
///  * closable           - The window has a close button
///  * miniaturizable     - The window has a minimize button
///  * resizable          - The window is resizable
///  * texturedBackground - The window has a texturized background
///
/// Notes:
///  * The Maximize button is also provided when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.
static int webview_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
      lua_pushinteger(L, NSBorderlessWindowMask) ;         lua_setfield(L, -2, "borderless") ;
      lua_pushinteger(L, NSTitledWindowMask) ;             lua_setfield(L, -2, "titled") ;
      lua_pushinteger(L, NSClosableWindowMask) ;           lua_setfield(L, -2, "closable") ;
      lua_pushinteger(L, NSMiniaturizableWindowMask) ;     lua_setfield(L, -2, "miniaturizable") ;
      lua_pushinteger(L, NSResizableWindowMask) ;          lua_setfield(L, -2, "resizable") ;
      lua_pushinteger(L, NSTexturedBackgroundWindowMask) ; lua_setfield(L, -2, "texturedBackground") ;
    return 1 ;
}

static int webview_windowStyle(lua_State *L) {
// Note:  This method is wrapped in init.lua
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)theWindow.styleMask) ;
    } else {
        [theWindow setStyleMask:(NSUInteger)luaL_checkinteger(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    NSString *title = [theView title] ;
    if (!title) {
        title = @"" ;
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// static int userdata_eq(lua_State* L) {
// }

static int userdata_gc(lua_State* L) {
    HSWebViewWindow *theWindow = (__bridge_transfer HSWebViewWindow*)*((void**)luaL_checkudata(L, 1, USERDATA_TAG)) ;
    [theWindow close];
    theWindow = nil;
    return 0;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"delete",                    webview_delete},
    {"goBack",                    webview_goBack},
    {"goForward",                 webview_goForward},
    {"url",                       webview_url},
    {"title",                     webview_title},
    {"reload",                    webview_reload},
    {"magnification",             webview_magnification},
    {"allowMagnificationGesture", webview_allowMagnificationGesture},
    {"isOnlySecureContent",       webview_isOnlySecureContent},
    {"estimatedProgress",         webview_estimatedProgress},
    {"loading",                   webview_loading},
    {"stopLoading",               webview_stopLoading},
//     {"preferences",               webview_preferences},

    {"show",                      webview_show},
    {"hide",                      webview_hide},
    {"allowMouseClicks",          webview_allowMouseClicks},
    {"allowTextEntry",            webview_allowTextEntry},
    {"asHSWindow",                webview_hswindow} ,
    {"asHSDrawing",               webview_hsdrawing},
    {"windowTitle",               webview_windowTitle},
    {"_windowStyle",              webview_windowStyle},

    {"__tostring",                userdata_tostring},
//     {"__eq",                      userdata_eq},
    {"__gc",                      userdata_gc},
    {NULL,                        NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", webview_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_webview_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    webview_windowMasksTable(L) ;
    lua_setfield(L, -2, "windowMasks") ;

    return 1;
}
