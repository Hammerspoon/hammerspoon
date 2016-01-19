#import "MJLua.h"
#import "MJConsoleWindowController.h"
#import "MJUserNotificationManager.h"
#import "MJConfigUtils.h"
#import "MJAccessibilityUtils.h"
#import "variables.h"
#import <pthread.h>
#import "MJMenuIcon.h"
#import "MJPreferencesWindowController.h"
#import "MJConsoleWindowController.h"
#import "MJAutoLaunch.h"
#import <Crashlytics/Crashlytics.h>

static LuaSkin* MJLuaState;
static MJLuaLogger* MJLuaLogDelegate;
static int evalfn;

static lua_CFunction oldPanicFunction ;

int refTable;

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
}

@implementation MJLuaLogger

@synthesize L = _L ;

- (instancetype)initWithLua:(lua_State *)L {
    self = [super init] ;
    if (self) {
        _L = L ;
    }
    return self ;
}

- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage {
    // Send logs to the appropriate location, depending on their level
    // Note that hs.handleLogMessage also does this kind of filtering. We are special casing here for LS_LOG_BREADCRUMB to entirely bypass calling into Lua
    // (because such logs don't need to be shown to the user, just stored in our crashlog in case we crash)
    switch (level) {
        case LS_LOG_BREADCRUMB:
            CLSNSLog(@"%@", theMessage);
            break;

        default:
            lua_getglobal(_L, "hs") ; lua_getfield(_L, -1, "handleLogMessage") ; lua_remove(_L, -2) ;
            lua_pushinteger(_L, level) ;
            lua_pushstring(_L, [theMessage UTF8String]) ;
            int errState = lua_pcall(_L, 2, 0, 0) ;
            if (errState != LUA_OK) {
                NSArray *stateLabels = @[ @"OK", @"YIELD", @"ERRRUN", @"ERRSYNTAX", @"ERRMEM", @"ERRGCMM", @"ERRERR" ] ;
                CLSNSLog(@"logForLuaSkin: error, state %@: %s", [stateLabels objectAtIndex:(NSUInteger)errState],
                          luaL_tolstring(_L, -1, NULL)) ;
                lua_pop(_L, 2) ; // lua_pcall result + converted version from luaL_tolstring
            }
            break;
    }
}

@end

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
        MJLuaReplace();
    });
    return 0;
}

/// hs.processInfo
/// Constant
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
    LuaSkin *skin = [LuaSkin shared];
    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
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
#pragma clang diagnostic pop
        } else {
            [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
            lua_pushboolean(L, NO) ;
        }
    } else {
        [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
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
    LuaSkin *skin = [LuaSkin shared];
    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)] ;

            [sharedUpdater performSelector:@selector(checkForUpdates:) withObject:nil] ;
#pragma clang diagnostic pop
        } else {
            [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
        }
    } else {
        [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
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

/// hs.cleanUTF8forConsole(inString) -> outString
/// Function
/// Returns a copy of the incoming string that can be displayed in the Hammerspoon console.  Invalid UTF8 sequences are converted to the Unicode Replacement Character and NULL (0x00) is converted to the Unicode Empty Set character.
///
/// Parameters:
///  * inString - the string to be cleaned up
///
/// Returns:
///  * outString - the cleaned up version of the input string.
///
/// Notes:
///  * This function is applied automatically to all output which appears in the Hammerspoon console, but not to the output provided by the `hs` command line tool.
///  * This function does not modify the original string - to actually replace it, assign the result of this function to the original string.
///  * This function is a more specifically targeted version of the `hs.utf8.fixUTF8(...)` function.
static int core_cleanUTF8(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    [skin pushNSObject:[skin getValidUTF8AtIndex:1]] ;
    return 1 ;
}

static int core_exit(lua_State* L) {
    if (lua_toboolean(L, 2)) {
        MJLuaDestroy();
    }

    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static int core_logmessage(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    if (str == nil) {
      core_cleanUTF8(L) ;
      s = lua_tolstring(L, -1, &len);
      str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
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
    {"cleanUTF8forConsole", core_cleanUTF8},
    {"_exit", core_exit},
    {"_logmessage", core_logmessage},
    {"_notify", core_notify},
    {NULL, NULL}
};

#pragma mark - Lua environment lifecycle, high level

// Create and configure a Lua environment
void MJLuaCreate(void) {
    MJLuaAlloc();
    MJLuaInit();
}

// Deconfigure and destroy a Lua environment
void MJLuaDestroy(void) {
    MJLuaDeinit();
    MJLuaDealloc();
}

// Deconfigure and destroy a Lua environment and create its replacement
void MJLuaReplace(void) {
    MJLuaDeinit();
    MJLuaDealloc();
    MJLuaAlloc();
    MJLuaInit();
}

# pragma mark - Lua environment lifecycle, low level

static int MJLuaAtPanic(lua_State *L) {
    CLSNSLog(@"LUA_AT_PANIC: %s", lua_tostring(L, -1)) ;
    if (oldPanicFunction)
        return oldPanicFunction(L) ;
    else
        return 0 ;
}

// Create a Lua environment with LuaSkin
void MJLuaAlloc(void) {
    LuaSkin *skin = [LuaSkin shared];
    if (!skin.L) {
        [skin createLuaState];
    }
    MJLuaState = skin;
    oldPanicFunction = lua_atpanic([skin L], &MJLuaAtPanic) ;
}

// Configure a Lua environment that has already been created by LuaSkin
void MJLuaInit(void) {
    lua_State* L = MJLuaState.L;

    refTable = [MJLuaState registerLibrary:corelib metaFunctions:nil];
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

    evalfn = [MJLuaState luaRef:refTable];
    MJLuaLogDelegate = [[MJLuaLogger alloc] initWithLua:L] ;
    if (MJLuaLogDelegate) [MJLuaState setDelegate:MJLuaLogDelegate] ;
}

static int callShutdownCallback(lua_State *L) {
    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "shutdownCallback");

    if (lua_type(L, -1) == LUA_TFUNCTION) {
        [MJLuaState protectedCallAndTraceback:0 nresults:0];
    }

    return 0;
}

// Deconfigure a Lua environment that will shortly be destroyed by LuaSkin
void MJLuaDeinit(void) {
    LuaSkin *skin = MJLuaState;

    callShutdownCallback(skin.L);
    if (MJLuaLogDelegate) {
        [MJLuaState setDelegate:nil] ;
        MJLuaLogDelegate = nil ;
    }
}

// Destroy a Lua environment with LuaSiin
void MJLuaDealloc(void) {
    LuaSkin *skin = MJLuaState;
    [skin destroyLuaState];
}

NSString* MJLuaRunString(NSString* command) {
    lua_State* L = MJLuaState.L;

    [MJLuaState pushLuaRef:refTable ref:evalfn];
    if (!lua_isfunction(L, -1)) {
        CLSNSLog(@"ERROR: MJLuaRunString doesn't seem to have an evalfn");
        if (lua_isstring(L, -1)) {
            CLSNSLog(@"evalfn appears to be a string: %s", lua_tostring(L, -1));
        }
        return @"";
    }
    lua_pushstring(L, [command UTF8String]);
    if ([MJLuaState protectedCallAndTraceback:1 nresults:1] == NO) {
        const char *errorMsg = lua_tostring(L, -1);
        [MJLuaState logError:[NSString stringWithUTF8String:errorMsg]];
    }

    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    if (str == nil) {
      lua_pushcfunction(L, core_cleanUTF8) ;
      lua_pushvalue(L, -2) ;
      if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
          s = lua_tolstring(L, -1, &len);
          str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
          lua_pop(L, 1) ;
      } else {
          str = [[NSString alloc] initWithFormat:@"-- unable to clean for utf8 output: %s", lua_tostring(L, -1)] ;
          lua_pop(L, 1) ;
      }
    }
    lua_pop(L, 1);

    return str;
}

// C-Code helper to return current active LuaState. Useful for callbacks to
// verify stored LuaState still matches active one if GC fails to clear it.
lua_State* MJGetActiveLuaState() {
  return MJLuaState.L ;
}
