#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs.webview"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (__bridge objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

// typedef struct _webview_t {
//     void *window;
// } webview_t;

@interface HSWebViewWindow : NSWindow <NSWindowDelegate>
@property BOOL allowKeyboard ;
@end

@interface HSWebViewView: WebView
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
        self.level = NSScreenSaverWindowLevel;
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
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect frameName:nil groupName:nil];
    if (self) {
        self.shouldCloseWithWindow = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    return YES ;
}

@end

/// hs.webview.new(rect, [initialURL]) -> webviewObject
/// Method
/// Create a webviewObject and optionally set it's initial URL
///
/// Parameters:
///  * rect - a rectangle specifying where the webviewObject should be displayed.
///  * initialURL - an optional URL to initially render in the webviewObject
///
/// Returns:
///  * The webview object
static int webview_new(lua_State *L) {
    NSString *theURL ;
    if (lua_type(L, 2) == LUA_TSTRING) {
//         theURL = [[LuaSkin shared] toNSObjectAtIndex:2] ;
        size_t size ;
        unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
        theURL = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
    } else if (lua_type(L, 2) != LUA_TNONE) {
        return luaL_error(L, "Invalid URL type.  String or none expected.") ;
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

        HSWebViewView *theView = [[HSWebViewView alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        theWindow.contentView = theView;
        if (theURL) {
            [theView.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:theURL]]] ;
        }
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

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

/// hs.webview:url(URL) -> webviewObject
/// Method
/// Set the URL to render for the webview.
///
/// Parameters:
///  * URL - a string representing the URL to render.
///
/// Returns:
///  * The webview Object
static int webview_url(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
//     NSString        *theURL = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    size_t size ;
    unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
    NSString *theURL = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;

    if (theURL) {
        [theView.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:theURL]]] ;
    } else {
        return luaL_error(L, "Invalid URL type.  String expected.") ;
    }

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

/// hs.webview:allowTextEntry([flag]) -> webviewObject | flag
/// Method
/// Get or set whether or not the webview can accept keyboard for web form entry. Defaults to false.
///
/// Parameters:
///  * flag - an optional boolean value which sets whether or not the webview will accept keyboard input.
///
/// Returns:
///  * If flag is present, then this method returns he webview Object; otherwise, the current value is returned.
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

/// hs.webview:allowMouseClicks([flag]) -> webviewObject | flag
/// Method
/// Get or set whether or not the webview can accept mouse clicks for web navigation. Defaults to true.
///
/// Parameters:
///  * flag - an optional boolean value which sets whether or not the webview will accept mouse clicks.
///
/// Returns:
///  * If flag is present, then this method returns he webview Object; otherwise, the current value is returned.
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
///  * hs.window:minimize only works if the webview is minimizable (see `hs.webview.Style`)
///  * hs.window:setSize only works if the webview is resizable (see `hs.webview.Style`)
///  * hs.window:close only works if the webview is closable (see `hs.webview.Style`)
///  * hs.window:maximize will reposition the webview to the upper left corner of your screen, but will only resize the webview if the webview is resizable (see `hs.webview.Style`)
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

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
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
    {"show",             webview_show},
    {"hide",             webview_hide},
    {"delete",           webview_delete},
    {"allowMouseClicks", webview_allowMouseClicks},
    {"allowTextEntry",   webview_allowTextEntry},
    {"_windowStyle",     webview_windowStyle},
    {"url",              webview_url},
    {"asHSWindow",       webview_hswindow} ,
    {"asHSDrawing",      webview_hsdrawing},
    {"__tostring",       userdata_tostring},
//     {"__eq",       userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,         NULL}
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
