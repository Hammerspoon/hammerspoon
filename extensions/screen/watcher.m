#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.screen.watcher ===
///
/// Watch for screen layout changes
/// This could be the addition or removal of a monitor, a screen resolution change, movement of a monitor in the Display preferences pane, etc.
///
/// Note that screen events which happen while your Mac is suspended, may not trigger the watcher in various circumstances (e.g. if you have FileVault enabled and the machine resumes out of hibernation - the screen events will be happening before the drive is unlocked and will not be reported to Hammerspoon)
///
/// This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


// Common Code

#define USERDATA_TAG    "hs.screen.watcher"
static LSRefTable refTable;

// Not so common code

@interface MJScreenWatcher : NSObject
@property lua_State* L;
@property int fn;
@property BOOL includeActive;
@end

@implementation MJScreenWatcher

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _fn            = LUA_NOREF ;
        _includeActive = NO ;
    }
    return self ;
}

- (void) _screensChanged:(id)note {
    [self performSelectorOnMainThread:@selector(screensChanged:)
                                        withObject:note
                                        waitUntilDone:YES];
}

- (void) screensChanged:(NSNotification*)note {
    if (self.fn != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L = skin.L;
        _lua_stackguard_entry(skin.L);
        int argCount = _includeActive ? 1 : 0;

        [skin pushLuaRef:refTable ref:self.fn];
        if (_includeActive) {
            if ([note.name isEqualToString:@"NSWorkspaceActiveDisplayDidChangeNotification"]) {
                lua_pushboolean(L, YES);
            } else {
                lua_pushnil(L);
            }
        }
        [skin protectedCallAndError:@"hs.screen.watcher callback" nargs:argCount nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}
@end


typedef struct _screenwatcher_t {
    bool running;
    int fn;
    void* obj;
} screenwatcher_t;

// 10/28/14 3:19:40.825 AM WindowServer[244]: CGError post_notification(const CGSNotificationType, void *const, const size_t, const bool, const CGSRealTimeDelta, const int, const CGSConnectionID *const, const pid_t): Timed out 0.250 second wait for reply from "Hammerspoon" for synchronous notification type 100 (kCGSDisplayWillReconfigure) (CID 0x458bb, PID 80899)


/// hs.screen.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new screen-watcher.
///
/// Parameters:
///  * The function to be called when a change in the screen layout occurs.  This function should take no arguments.
///
/// Returns:
///  * An `hs.screen.watcher` object
///
/// Notes:
///  * A screen layout change usually involves a change that is made from the Displays Preferences Panel or when a monitor is attached or removed. It can also be caused by a change in the Dock size or presence.
static int screen_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    screenwatcher_t* screenwatcher = lua_newuserdata(L, sizeof(screenwatcher_t));
    memset(screenwatcher, 0, sizeof(screenwatcher_t));

    lua_pushvalue(L, 1);
    screenwatcher->fn = [skin luaRef:refTable];

    MJScreenWatcher* object = [[MJScreenWatcher alloc] init];
    object.L = L;
    object.fn = screenwatcher->fn;
    object.includeActive = NO;
    screenwatcher->obj = (__bridge_retained void*)object;
    screenwatcher->running = NO;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.screen.watcher.newWithActiveScreen(fn) -> watcher
/// Constructor
/// Creates a new screen-watcher that is also called when the active screen changes.
///
/// Parameters:
///  * The function to be called when a change in the screen layout or active screen occurs.  This function can optionally take one argument, a boolean which will indicate if the change was due to a screen layout change (nil) or because the active screen changed (true).
///
/// Returns:
///  * An `hs.screen.watcher` object
///
/// Notes:
///  * A screen layout change usually involves a change that is made from the Displays Preferences Panel or when a monitor is attached or removed. It can also be caused by a change in the Dock size or presence.
///    * `nil` was chosen instead of `false` for the argument type when this type of change occurs to more closely match the previous behavior of having no argument passed to the callback function.
///  * An active screen change indicates that the focused or main screen has changed when the user has "Displays have separate spaces" checked in the Mission Control Preferences Panel (the focused display is the display which has the active window and active menubar).
///    * Detecting a change in the active display relies on watching for the `NSWorkspaceActiveDisplayDidChangeNotification` message which is not documented by Apple.  While this message has been around at least since OS X 10.9, because it is undocumented, we cannot be positive that Apple won't remove it in a future OS X update.  Because this watcher works by listening for posted messages, should Apple remove this notification, your callback function will no longer receive messages about this change -- it won't crash or change behavior in any other way.  This documentation will be updated if this status changes.
///  * Plugging in or unplugging a monitor can cause both a screen layout callback and an active screen change callback.
static int screen_watcher_new_with_active_screen(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    lua_pushcfunction(L, screen_watcher_new);
    lua_pushvalue(L, 1);
    lua_call(L, 1, 1);
    screenwatcher_t* screenwatcher = luaL_checkudata(L, -1, USERDATA_TAG);
    ((__bridge MJScreenWatcher *)screenwatcher->obj).includeActive = YES;
    return 1;
}

/// hs.screen.watcher:start() -> watcher
/// Method
/// Starts the screen watcher, making it so fn is called each time the screen arrangement changes
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.screen.watcher` object
static int screen_watcher_start(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);

    if (screenwatcher->running) return 1;
    screenwatcher->running = YES;

    [[NSNotificationCenter defaultCenter] addObserver:(__bridge id)screenwatcher->obj
                                             selector:@selector(_screensChanged:)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];
    if (((__bridge MJScreenWatcher *)screenwatcher->obj).includeActive) {
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:(__bridge id)screenwatcher->obj
                                                 selector:@selector(_screensChanged:)
                                                     name:@"NSWorkspaceActiveDisplayDidChangeNotification"
                                                   object:nil];
    }
    return 1;
}

/// hs.screen.watcher:stop() -> watcher
/// Method
/// Stops the screen watcher's fn from getting called until started again
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.screen.watcher` object
static int screen_watcher_stop(lua_State* L) {
    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);

    if (!screenwatcher->running) return 1;
    screenwatcher->running = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:(__bridge id)screenwatcher->obj
                                                    name:NSApplicationDidChangeScreenParametersNotification
                                                  object:nil];
    if (((__bridge MJScreenWatcher *)screenwatcher->obj).includeActive) {
        [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:(__bridge id)screenwatcher->obj
                                                        name:@"NSWorkspaceActiveDisplayDidChangeNotification"
                                                      object:nil];
    }
    return 1;
}

static int screen_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    screenwatcher_t* screenwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, screen_watcher_stop); lua_pushvalue(L,1); lua_call(L, 1, 1);

    screenwatcher->fn = [skin luaUnref:refTable ref:screenwatcher->fn];

    MJScreenWatcher* object = (__bridge_transfer id)screenwatcher->obj;
    object = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

// Metatable for created objects when _new invoked
static const luaL_Reg screen_metalib[] = {
    {"start",   screen_watcher_start},
    {"stop",    screen_watcher_stop},
    {"__tostring", userdata_tostring},
    {"__gc",    screen_watcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg screenLib[] = {
    {"new",     screen_watcher_new},
    {"newWithActiveScreen", screen_watcher_new_with_active_screen},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_screen_watcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:screenLib metaFunctions:meta_gcLib objectFunctions:screen_metalib];

    return 1;
}
