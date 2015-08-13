#import "MJLua.h"
#import "MJConsoleWindowController.h"
#import "MJUserNotificationManager.h"
#import "MJConfigUtils.h"
#import "MJAccessibilityUtils.h"
#import "variables.h"
#import <pthread.h>
#import "../extensions/hammerspoon.h"
#import "MJMenuIcon.h"
#import "MJPreferencesWindowController.h"
#import "MJConsoleWindowController.h"
#import "MJAutoLaunch.h"

static LuaSkin* MJLuaState;
static int evalfn;

/// === hs ===
///
/// Core Hammerspoon functionality

pthread_t mainthreadid;

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
}

/// hs.autoLaunch([state]) -> bool
/// Function
/// Set or display the "Launch on Login" status for Hammerspoon.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not Hammerspoon should be launched automatically when you log into your computer.
///
/// Returns:
///  * True if Hammerspoon is currently (or has just been) set to launch on login or False if Hammerspoon is not.
static int core_autolaunch(lua_State* L) {
    if (lua_isboolean(L, -1)) { MJAutoLaunchSet(lua_toboolean(L, -1)); }
    lua_pushboolean(L, MJAutoLaunchGet()) ;
    return 1;
}

/// hs.menuIcon([state]) -> bool
/// Function
/// Set or display whether or not the Hammerspoon menu icon is visible.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not the Hammerspoon menu icon should be visible.
///
/// Returns:
///  * True if the icon is currently set (or has just been) to be visible or False if it is not.
static int core_menuicon(lua_State* L) {
    if (lua_isboolean(L, -1)) { MJMenuIconSetVisible(lua_toboolean(L, -1)); }
    lua_pushboolean(L, MJMenuIconVisible()) ;
    return 1;
}


// hs.dockIcon -- for historical reasons, this is actually handled by the hs.dockicon module, but a wrapper
// in the lua portion of this (setup.lua) provides an interface to this module which follows the syntax
// conventions used here.


/// hs.consoleOnTop([state]) -> bool
/// Function
/// Set or display whether or not the Hammerspoon console is always on top when visible.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not the Hammerspoon console is always on top when visible.
///
/// Returns:
///  * True if the console is currently set (or has just been) to be always on top when visible or False if it is not.
static int core_consoleontop(lua_State* L) {
    if (lua_isboolean(L, -1)) { MJConsoleWindowSetAlwaysOnTop(lua_toboolean(L, -1)); }
    lua_pushboolean(L, MJConsoleWindowAlwaysOnTop()) ;
    return 1;
}

/// hs.openAbout()
/// Function
/// Displays the OS X About panel for Hammerspoon; implicitly focuses Hammerspoon.
static int core_openabout(lua_State* __unused L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:nil];
    return 0;
}

/// hs.openPreferences()
/// Function
/// Displays the Hammerspoon Preferences panel; implicitly focuses Hammerspoon.
static int core_openpreferences(lua_State* __unused L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJPreferencesWindowController singleton] showWindow: nil];

    return 0 ;
}

/// hs.openConsole([bringToFront])
/// Function
/// Opens the Hammerspoon Console window and optionally focuses it.
///
/// Parameters:
///  * bringToFront - if true (default), the console will be focused as well as opened.
static int core_openconsole(lua_State* L) {
    if (!(lua_isboolean(L,1) && !lua_toboolean(L, 1)))
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
    return 0;
}

/// hs.reload()
/// Function
/// Reloads your init-file in a fresh Lua environment.
static int core_reload(lua_State* L) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LuaSkin shared] resetLuaState];
        MJLuaSetup();
    });
    return 0;
}

/// hs.processInfo
/// Variable
/// A table containing read-only information about the Hammerspoon application instance currently running.
static int push_hammerAppInfo(lua_State* L) {
    lua_newtable(L) ;
        lua_pushstring(L, [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] UTF8String]) ;
        lua_setfield(L, -2, "version") ;
        lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "resourcePath");
        lua_pushstring(L, [[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "bundlePath");
        lua_pushstring(L, [[[NSBundle mainBundle] executablePath] fileSystemRepresentation]);
        lua_setfield(L, -2, "executablePath");
        lua_pushinteger(L, getpid()) ;
        lua_setfield(L, -2, "processID") ;
// Take this out of hs.settings?
        lua_pushstring(L, [[[NSBundle mainBundle] bundleIdentifier] UTF8String]) ;
        lua_setfield(L, -2, "bundleID") ;

    return 1;
}

/// hs.accessibilityState(shouldPrompt) -> isEnabled
/// Function
///
/// Parameters:
///  * shouldPrompt - an optional boolean value indicating if the dialog box asking if the System Preferences application should be opened should be presented when Accessibility is not currently enabled for Hammerspoon.  Defaults to false.
///
/// Returns:
///  * True or False indicating whether or not Accessibility is enabled for Hammerspoon.
///
/// Notes:
///  * Since this check is done automatically when Hammerspoon loads, it is probably of limited use except for skipping things that are known to fail when Accessibility is not enabled.  Evettaps which try to capture keyUp and keyDown events, for example, will fail until Accessibility is enabled and the Hammerspoon application is relaunched.
static int core_accessibilityState(lua_State* L) {
//     extern BOOL MJAccessibilityIsEnabled(void);
//     extern void MJAccessibilityOpenPanel(void);

    BOOL shouldprompt = lua_toboolean(L, 1);
    BOOL enabled = MJAccessibilityIsEnabled();
    if (shouldprompt) { MJAccessibilityOpenPanel(); }
    lua_pushboolean(L, enabled);
    return 1;
}

/// hs.automaticallyCheckForUpdates([setting]) -> bool
/// Function
/// Gets and optionally sets the Hammerspoon option to automatically check for updates.
///
/// Parameters:
///  * setting - an optional boolean variable indicating if Hammerspoon should (true) or should not (false) check for updates.
///
/// Returns:
///  * The current (or newly set) value indicating whether or not automatic update checks should occur for Hammerspoon.
///
/// Notes:
///  * If you are running a non-release or locally compiled version of Hammerspoon then the results of this function are unspecified.
static int automaticallyChecksForUpdates(lua_State *L) {
    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
            id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)] ;
            if (lua_isboolean(L, 1)) {

            // This convoluted #$@#% is required (a) because we want to weakly link to the SparkleFramework for dev builds, and
            // (b) because performSelector: withObject: only works when withObject: is an argument of type id or nil

            // the following is equivalent to: [sharedUpdater setAutomaticallyChecksForUpdates:lua_toboolean(L, 1)] ;

                BOOL myBoolValue = lua_toboolean(L, 1) ;
                NSMethodSignature * mySignature = [NSClassFromString(@"SUUpdater") instanceMethodSignatureForSelector:@selector(setAutomaticallyChecksForUpdates:)];
                NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
                [myInvocation setTarget:sharedUpdater];
            // even though signature specifies this, we need to specify it in the invocation, since the signature is re-usable
            // for any method which accepts the same signature list for the target.
                [myInvocation setSelector:@selector(setAutomaticallyChecksForUpdates:)];
                [myInvocation setArgument:&myBoolValue atIndex:2];
                [myInvocation invoke];

            }
            lua_pushboolean(L, (BOOL)[sharedUpdater performSelector:@selector(automaticallyChecksForUpdates)]) ;
        } else {
            printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
            lua_pushboolean(L, NO) ;
        }
    } else {
        printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs.checkForUpdates() -> none
/// Function
/// Check for an update now, and if one is available, prompt the user to continue the update process.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * If you are running a non-release or locally compiled version of Hammerspoon then the results of this function are unspecified.
static int checkForUpdates(lua_State *L) {
    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
            id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)] ;

            [sharedUpdater performSelector:@selector(checkForUpdates:) withObject:nil] ;
        } else {
            printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
        }
    } else {
        printToConsole(L, "-- Sparkle Update framework not available for the running instance of Hammerspoon.") ;
    }
    return 0 ;
}

/// hs.focus()
/// Function
/// Makes Hammerspoon the foreground app.
static int core_focus(lua_State* L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    return 0;
}

/// hs.getObjectMetatable(name) -> table or nil
/// Function
/// Fetches the Lua metatable for objects produced by an extension
///
/// Parameters:
///  * name - A string containing the name of a module to fetch object metadata for (e.g. `"hs.screen"`)
///
/// Returns:
///  * The extension's object metatable, or nil if an error occurred
static int core_getObjectMetatable(lua_State *L) {
    luaL_getmetatable(L, lua_tostring(L,1));
    return 1;
}

static int core_exit(lua_State* L) {
    if (lua_toboolean(L, 2))
        lua_close(L);

    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static int core_logmessage(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    if (str == nil) {
      str = @"";
    }
    loghandler(str);
    return 0;
}

static int core_notify(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    [[MJUserNotificationManager sharedManager] sendNotification:str handler:^{
        [[MJConsoleWindowController singleton] showWindow: nil];
    }];
    return 0;
}

static luaL_Reg corelib[] = {
    {"openConsole", core_openconsole},
    {"consoleOnTop", core_consoleontop},
    {"openAbout", core_openabout},
    {"menuIcon", core_menuicon},
    {"openPreferences", core_openpreferences},
    {"autoLaunch", core_autolaunch},
    {"automaticallyCheckForUpdates", automaticallyChecksForUpdates},
    {"checkForUpdates", checkForUpdates},
    {"reload", core_reload},
    {"focus", core_focus},
    {"accessibilityState", core_accessibilityState},
    {"getObjectMetatable", core_getObjectMetatable},
    {"_exit", core_exit},
    {"_logmessage", core_logmessage},
    {"_notify", core_notify},
    {NULL, NULL}
};

void MJLuaSetup(void) {
    mainthreadid = pthread_self();
    MJLuaState = [LuaSkin shared];
    lua_State* L = MJLuaState.L;

    [MJLuaState registerLibrary:corelib metaFunctions:nil];
    push_hammerAppInfo(L) ;
    lua_setfield(L, -2, "processInfo") ;

    lua_setglobal(L, "hs");

    int loadresult = luaL_loadfile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
    if (loadresult != 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hammerspoon installation is corrupted"];
        [alert setInformativeText:@"Please re-install Hammerspoon"];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert runModal];
        [[NSApplication sharedApplication] terminate: nil];
    }

    lua_pushstring(L, [[[NSBundle mainBundle] pathForResource:@"extensions" ofType:nil] fileSystemRepresentation]);
    lua_pushstring(L, [MJConfigFile UTF8String]);
    lua_pushstring(L, [MJConfigFileFullPath() UTF8String]);
    lua_pushstring(L, [MJConfigDir() UTF8String]);
    lua_pushstring(L, [[[NSBundle mainBundle] pathForResource:@"docs" ofType:@"json"] fileSystemRepresentation]);
    lua_pushboolean(L, [[NSFileManager defaultManager] fileExistsAtPath: MJConfigFileFullPath()]);
    lua_pushboolean(L, [[NSUserDefaults standardUserDefaults] boolForKey:HSAutoLoadExtensions]);

    lua_pcall(L, 7, 1, 0);

    evalfn = luaL_ref(L, LUA_REGISTRYINDEX);
}

void MJLuaTeardown(void) {
    [MJLuaState destroyLuaState];
}

NSString* MJLuaRunString(NSString* command) {
    lua_State* L = MJLuaState.L;

    lua_rawgeti(L, LUA_REGISTRYINDEX, evalfn);
    if (!lua_isfunction(L, -1)) {
        CLS_NSLOG(@"ERROR: MJLuaRunString doesn't seem to have an evalfn");
        if (lua_isstring(L, -1)) {
            CLS_NSLOG(@"evalfn appears to be a string: %s", lua_tostring(L, -1));
        }
        return @"";
    }
    lua_pushstring(L, [command UTF8String]);
    if ([MJLuaState protectedCallAndTraceback:1 nresults:1] == NO) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
    }

    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    lua_pop(L, 1);

    return str;
}

// C-Code helper to return current active LuaState. Useful for callbacks to
// verify stored LuaState still matches active one if GC fails to clear it.
lua_State* MJGetActiveLuaState() {
  return MJLuaState.L ;
}
