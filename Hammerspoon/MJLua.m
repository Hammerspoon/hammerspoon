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
#import "MJDockIcon.h"
#import "HSAppleScript.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvariadic-macros"
#import "Sentry.h"
#pragma clang diagnostic pop

#import "HSLogger.h" // This should come after Sentry
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <libproc.h>
#import <dlfcn.h>

@interface MJPreferencesWindowController ()
- (void) reflectDefaults ;
@end

//  static LuaSkin* MJLuaState; // we can no longer trust that this points to the correct thread -- get it anew as needed
static HSLogger* MJLuaLogDelegate;
static int evalfn;
static int completionsForWordFn;

static lua_CFunction oldPanicFunction ;

static LSRefTable refTable;

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
}

/// hs.uploadCrashData([state]) -> bool
/// Function
/// Get or set the "Upload Crash Data" preference for Hammerspoon
///
/// Parameters:
///  * state - An optional boolean, true to upload crash reports, false to not
///
/// Returns:
///  * True if Hammerspoon is currently (or has just been) set to upload crash data or False otherwise
///
/// Notes:
///  * If at all possible, please do allow Hammerspoon to upload crash reports to us, it helps a great deal in keeping Hammerspoon stable
///  * Our Privacy Policy can be found here: [https://www.hammerspoon.org/privacy.html](https://www.hammerspoon.org/privacy.html)
static int core_uploadCrashData(lua_State* L) {
    if (lua_isboolean(L, 1)) { HSSetUploadCrashData(lua_toboolean(L, 1)); }
    lua_pushboolean(L, HSUploadCrashData()) ;
    return 1;
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
    if (lua_isboolean(L, 1)) { MJAutoLaunchSet(lua_toboolean(L, 1)); }
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
    if (lua_isboolean(L, 1)) { MJMenuIconSetVisible(lua_toboolean(L, 1)); }
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
    if (lua_isboolean(L, 1)) { MJConsoleWindowSetAlwaysOnTop(lua_toboolean(L, 1)); }
    lua_pushboolean(L, MJConsoleWindowAlwaysOnTop()) ;
    return 1;
}

/// hs.openAbout()
/// Function
/// Displays the OS X About panel for Hammerspoon; implicitly focuses Hammerspoon.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int core_openabout(lua_State* __unused L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:nil];
    return 0;
}

/// hs.openPreferences()
/// Function
/// Displays the Hammerspoon Preferences panel; implicitly focuses Hammerspoon.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int core_openpreferences(lua_State* __unused L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJPreferencesWindowController singleton] showWindow: nil];

    return 0 ;
}

/// hs.closePreferences()
/// Function
/// Closes the Hammerspoon Preferences window
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int core_closepreferences(lua_State* __unused L) {
    [[MJPreferencesWindowController singleton].window orderOut:nil];
    return 0;
}

/// hs.openConsole([bringToFront])
/// Function
/// Opens the Hammerspoon Console window and optionally focuses it.
///
/// Parameters:
///  * bringToFront - if true (default), the console will be focused as well as opened.
///
/// Returns:
///  * None
static int core_openconsole(lua_State* L) {
    if (!(lua_isboolean(L,1) && !lua_toboolean(L, 1)))
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
    return 0;
}

/// hs.closeConsole()
/// Function
/// Closes the Hammerspoon Console window
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int core_closeconsole(lua_State* L) {
    [[MJConsoleWindowController singleton].window orderOut:nil];
    return 0;
}

/// hs.open(filePath)
/// Function
/// Opens a file as if it were opened with /usr/bin/open
///
/// Parameters:
///  * filePath - A string containing the path to a file/bundle to open
///
/// Returns:
///  * A boolean, true if the file was opened successfully, otherwise false
static int core_open(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    BOOL result = [[NSWorkspace sharedWorkspace] openFile:[skin toNSObjectAtIndex:1]];

    lua_pushboolean(L, result);
    return 1;
}

/// hs.reload()
/// Function
/// Reloads your init-file in a fresh Lua environment.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSDictionary *appInfo = @{
                              @"version": [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                              @"build": [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                              @"resourcePath": @([[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]),
                              @"bundlePath": @([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]),
                              @"executablePath": @([[[NSBundle mainBundle] executablePath] fileSystemRepresentation]),
                              @"processID": @(getpid()),
                              @"bundleID": [[NSBundle mainBundle] bundleIdentifier],
                              @"buildTime": @(__DATE__ ", " __TIME__),
#ifdef DEBUG
                              @"debugBuild": @(YES),
#else
                              @"debugBuild": @(NO),
#endif
                              };

    [skin pushNSObject:appInfo];
    return 1;
}

/// hs.accessibilityState(shouldPrompt) -> isEnabled
/// Function
/// Checks the Accessibility Permissions for Hammerspoon, and optionally allows you to prompt for permissions.
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

// SOURCE: https://stackoverflow.com/a/58985069
bool isScreenRecordingEnabled(void)
{
    if (@available(macos 10.15, *)) {
        BOOL canRecordScreen = YES;
        if (@available(macOS 10.15, *)) {
            canRecordScreen = NO;
            NSRunningApplication *runningApplication = NSRunningApplication.currentApplication;
            NSNumber *ourProcessIdentifier = [NSNumber numberWithInteger:runningApplication.processIdentifier];

            CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
            NSUInteger numberOfWindows = CFArrayGetCount(windowList);
            for (int index = 0; index < numberOfWindows; index++) {
                // get information for each window
                NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, index);
                NSString *windowName = windowInfo[(id)kCGWindowName];
                NSNumber *processIdentifier = windowInfo[(id)kCGWindowOwnerPID];

                // don't check windows owned by this process
                if (! [processIdentifier isEqual:ourProcessIdentifier]) {
                    // get process information for each window
                    pid_t pid = processIdentifier.intValue;
                    NSRunningApplication *windowRunningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
                    if (! windowRunningApplication) {
                        // ignore processes we don't have access to, such as WindowServer, which manages the windows named "Menubar" and "Backstop Menubar"
                    }
                    else {
                        NSString *windowExecutableName = windowRunningApplication.executableURL.lastPathComponent;
                        if (windowName) {
                            if ([windowExecutableName isEqual:@"Dock"]) {
                                // ignore the Dock, which provides the desktop picture
                            }
                            else {
                                canRecordScreen = YES;
                                break;
                            }
                        }
                    }
                }
            }
            if (windowList) {
                CFRelease(windowList);
            }
        }
        return canRecordScreen;
    } else {
        return true;
    }
}

/// hs.screenRecordingState(shouldPrompt) -> isEnabled
/// Function
/// Checks the Screen Recording Permissions for Hammerspoon, and optionally allows you to prompt for permissions.
///
/// Parameters:
///  * shouldPrompt - an optional boolean value indicating if the dialog box asking if the System Preferences application should be opened should be presented when Screen Recording is not currently enabled for Hammerspoon.  Defaults to false.
///
/// Returns:
///  * True or False indicating whether or not Screen Recording is enabled for Hammerspoon.
///
/// Notes:
///  * If you trigger the prompt and the user denies it, you cannot bring up the prompt again - the user must manually enable it in System Preferences.
static int core_screenRecordingState(lua_State* L) {
    BOOL shouldprompt = lua_toboolean(L, 1);
    BOOL enabled = isScreenRecordingEnabled();
    if (shouldprompt) {
        CGDisplayStreamRef stream = CGDisplayStreamCreate(CGMainDisplayID(), 1, 1, kCVPixelFormatType_32BGRA, nil, ^(CGDisplayStreamFrameStatus status, uint64_t displayTime, IOSurfaceRef frameSurface, CGDisplayStreamUpdateRef updateRef) {
        });
        if (stream) {
            CFRelease(stream);
        }
    }
    lua_pushboolean(L, enabled);
    return 1;
}

/// hs.microphoneState(shouldPrompt) -> boolean
/// Function
/// Checks the Microphone Permissions for Hammerspoon, and optionally allows you to prompt for permissions.
///
/// Parameters:
///  * shouldPrompt - an optional boolean value indicating if we should request microphone access. Defaults to false.
///
/// Returns:
///  * `true` or `false` indicating whether or not Microphone access is enabled for Hammerspoon.
///
/// Notes:
///  * Will always return `true` on macOS 10.13 or earlier.
static int core_microphoneState(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    BOOL shouldprompt = lua_toboolean(L, 1);

    // Request permission to access the camera and microphone.
    if (@available(macOS 10.14, *)) {
        switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio])
        {
            case AVAuthorizationStatusAuthorized:
            {
                // The user has previously granted access to the camera.
                lua_pushboolean(L, YES) ;
                break;
            }
            case AVAuthorizationStatusNotDetermined:
            {
                if (shouldprompt) {
                    // The app hasn't yet asked the user for camera access.
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                        if (!granted) {
                            [skin logWarn:@"Hammerspoon has been declined Microphone access by the user."] ;
                        }
                    }];
                }
                lua_pushboolean(L, NO) ;
                break;
            }
            case AVAuthorizationStatusDenied:
            {
                // The user has previously denied access.
                lua_pushboolean(L, NO) ;
                break;
            }
            case AVAuthorizationStatusRestricted:
            {
                // The user can't grant access due to restrictions.
                lua_pushboolean(L, NO) ;
                break;
            }
        }
    } else {
        // Fallback on earlier versions
        lua_pushboolean(L, YES) ;
    }
    return 1;
}

/// hs.cameraState(shouldPrompt) -> boolean
/// Function
/// Checks the Camera Permissions for Hammerspoon, and optionally allows you to prompt for permissions.
///
/// Parameters:
///  * shouldPrompt - an optional boolean value indicating if we should request camear access. Defaults to false.
///
/// Returns:
///  * `true` or `false` indicating whether or not Camera access is enabled for Hammerspoon.
///
/// Notes:
///  * Will always return `true` on macOS 10.13 or earlier.
static int core_cameraState(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    BOOL shouldprompt = lua_toboolean(L, 1);

    // Request permission to access the camera and microphone.
    if (@available(macOS 10.14, *)) {
        switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
        {
            case AVAuthorizationStatusAuthorized:
            {
                // The user has previously granted access to the camera.
                lua_pushboolean(L, YES) ;
                break;
            }
            case AVAuthorizationStatusNotDetermined:
            {
                if (shouldprompt) {
                    // The app hasn't yet asked the user for camera access.
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                        if (!granted) {
                            [skin logWarn:@"Hammerspoon has been declined Microphone access by the user."] ;
                        }
                    }];
                }
                lua_pushboolean(L, NO) ;
                break;
            }
            case AVAuthorizationStatusDenied:
            {
                // The user has previously denied access.
                lua_pushboolean(L, NO) ;
                break;
            }
            case AVAuthorizationStatusRestricted:
            {
                // The user can't grant access due to restrictions.
                lua_pushboolean(L, NO) ;
                break;
            }
        }
    } else {
        // Fallback on earlier versions
        lua_pushboolean(L, YES) ;
    }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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

/// hs.checkForUpdates([silent]) -> none
/// Function
/// Check for an update now, and if one is available, prompt the user to continue the update process.
///
/// Parameters:
///  * silent - An optional boolean. If true, no UI will be displayed if an update is available. Defaults to false.
///
/// Returns:
///  * None
///
/// Notes:
///  * If you are running a non-release or locally compiled version of Hammerspoon then the results of this function are unspecified.
static int checkForUpdates(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id sharedUpdater = [NSClassFromString(@"SUUpdater") performSelector:@selector(sharedUpdater)] ;

            SEL checkMethod = @selector(checkForUpdates:);
            if (lua_type(L, 1) == LUA_TBOOLEAN && lua_toboolean(L, 1) == YES) {
                checkMethod = @selector(checkForUpdateInformation);
            }
            [sharedUpdater performSelector:checkMethod withObject:nil] ;
#pragma clang diagnostic pop
        } else {
            [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
        }
    } else {
        [skin logWarn:@"Sparkle Update framework not available for the running instance of Hammerspoon."] ;
    }
    return 0 ;
}

/// hs.updateAvailable() -> string or false, string
/// Function
/// Gets the version & build number of an available update
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the display version of the latest release, or a boolean false if no update is available
///  * A string containing the build number of the latest release, or `nil` if no update is available
///
/// Notes:
///  * This is not a live check, it is a cached result of whatever the previous update check found. By default Hammerspoon checks for updates every few hours, but you can also add your own timer to check for updates more frequently with `hs.checkForUpdates()`
static int updateAvailable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    id appDelegate = [[NSApplication sharedApplication] delegate];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

    NSString *updateAvailable = [appDelegate performSelector:@selector(updateAvailable)];
    NSString *updateAvailableDisplayVersion = [appDelegate performSelector:@selector(updateAvailableDisplayVersion)];
    if (updateAvailable == nil) {
        lua_pushboolean(L, 0);
        return 1;
    } else {
        [skin pushNSObject:updateAvailableDisplayVersion];
        [skin pushNSObject:updateAvailable];
        return 2;
    }

#pragma clang diagnostic pop
}

/// hs.canCheckForUpdates() -> boolean
/// Function
/// Returns a boolean indicating whether or not the Sparkle framework is available to check for Hammerspoon updates.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the Sparkle framework is available to check for Hammerspoon updates
///
/// Notes:
///  * The Sparkle framework is included in all regular releases of Hammerspoon but not included if you are running a non-release or locally compiled version of Hammerspoon, so this function can be used as a simple test to determine whether or not you are running a formal release Hammerspoon or not.
static int canCheckForUpdates(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    BOOL canUpdate = NO ;

    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
            canUpdate = YES ;
        }
    }
    lua_pushboolean(L, canUpdate) ;
    return 1 ;
}

/// hs.preferencesDarkMode([state]) -> bool
/// Function
/// Set or display whether or not the Preferences panel should display in dark mode.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not the Preferences panel should display in dark mode.
///
/// Returns:
///  * A boolean, true if dark mode is enabled otherwise false.
static int preferencesDarkMode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    if (lua_isboolean(L, 1)) {
        PreferencesDarkModeSetEnabled(lua_toboolean(L, 1));
        [[MJPreferencesWindowController singleton] reflectDefaults] ;
    }

    lua_pushboolean(L, PreferencesDarkModeEnabled()) ;
    return 1;
}

/// hs.allowAppleScript([state]) -> bool
/// Function
/// Set or display whether or not external Hammerspoon AppleScript commands are allowed.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not external Hammerspoon's AppleScript commands are allowed.
///
/// Returns:
///  * A boolean, `true` if Hammerspoon's AppleScript commands are (or has just been) allowed, otherwise `false`.
///
/// Notes:
///  * AppleScript access is disallowed by default.
///  * However due to the way AppleScript support works, Hammerspoon will always allow AppleScript commands that are part of the "Standard Suite", such as `name`, `quit`, `version`, etc. However, Hammerspoon will only allow commands from the "Hammerspoon Suite" if `hs.allowAppleScript()` is set to `true`.
///  * For a full list of AppleScript Commands:
///      - Open `/Applications/Utilities/Script Editor.app`
///      - Click `File > Open Dictionary...`
///      - Select Hammerspoon from the list of Applications
///      - This will now open a Dictionary containing all of the availible Hammerspoon AppleScript commands.
///  * Note that strings within the Lua code you pass from AppleScript can be delimited by `[[` and `]]` rather than normal quotes
///  * Example:
///
///    ```lua
///    tell application "Hammerspoon"
///      execute lua code "hs.alert([[Hello from AppleScript]])"
///    end tell```
static int core_appleScript(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    if (lua_isboolean(L, 1)) {
        HSAppleScriptSetEnabled(lua_toboolean(L, 1));
    }

    lua_pushboolean(L, HSAppleScriptEnabled()) ;
    return 1;
}

/// hs.openConsoleOnDockClick([state]) -> bool
/// Function
/// Set or display whether or not the Console window will open when the Hammerspoon dock icon is clicked
///
/// Parameters:
///  * state - An optional boolean, true if the console window should open, false if not
///
/// Returns:
///  * A boolean, true if the console window will open when the dock icon
///
/// Notes:
///  * This only refers to dock icon clicks while Hammerspoon is already running. The console window is not opened by launching the app
static int core_openConsoleOnDockClick(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    if (lua_isboolean(L, 1)) {
        HSOpenConsoleOnDockClickSetEnabled(lua_toboolean(L, 1));
    }

    lua_pushboolean(L, HSOpenConsoleOnDockClickEnabled()) ;
    return 1;
}

/// hs.focus()
/// Function
/// Makes Hammerspoon the foreground app.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    [skin pushNSObject:[skin getValidUTF8AtIndex:1]] ;
    return 1 ;
}

static int core_exit(lua_State* L) {
    [[NSApplication sharedApplication] terminate: nil];
    return 0;
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
    {"preferencesDarkMode", preferencesDarkMode},
    {"openConsoleOnDockClick", core_openConsoleOnDockClick},
    {"openConsole", core_openconsole},
    {"closeConsole", core_closeconsole},
    {"consoleOnTop", core_consoleontop},
    {"openAbout", core_openabout},
    {"menuIcon", core_menuicon},
    {"openPreferences", core_openpreferences},
    {"closePreferences", core_closepreferences},
    {"open", core_open},
    {"autoLaunch", core_autolaunch},
    {"automaticallyCheckForUpdates", automaticallyChecksForUpdates},
    {"checkForUpdates", checkForUpdates},
    {"updateAvailable", updateAvailable},
    {"canCheckForUpdates", canCheckForUpdates},
    {"allowAppleScript", core_appleScript},
    {"reload", core_reload},
    {"focus", core_focus},
    {"accessibilityState", core_accessibilityState},
    {"screenRecordingState", core_screenRecordingState},
    {"microphoneState", core_microphoneState},
    {"cameraState", core_cameraState},
    {"getObjectMetatable", core_getObjectMetatable},
    {"uploadCrashData", core_uploadCrashData},
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
    HSNSLOG(@"Created Lua instance");
}

// Deconfigure and destroy a Lua environment
void MJLuaDestroy(void) {
    HSNSLOG(@"Destroying Lua instance");
    MJLuaDeinit();
    MJLuaDealloc();
}

// Deconfigure and destroy a Lua environment and create its replacement
void MJLuaReplace(void) {
    MJLuaDeinit();
    MJLuaDealloc();
    [[MJConsoleWindowController singleton] initializeConsoleColorsAndFont] ;

    MJLuaAlloc();
    MJLuaInit();
}

# pragma mark - Lua environment lifecycle, low level

static int MJLuaAtPanic(lua_State *L) {
    HSNSLOG(@"LUA_AT_PANIC: %s", lua_tostring(L, -1)) ;
    if (oldPanicFunction)
        return oldPanicFunction(L) ;
    else
        return 0 ;
}

// Create a Lua environment with LuaSkin
void MJLuaAlloc(void) {
    if (!MJLuaLogDelegate) {
        MJLuaLogDelegate = [[HSLogger alloc] initWithLua:nil];
    }
    LuaSkin *skin = [LuaSkin sharedWithDelegate:MJLuaLogDelegate];
    // on a reload, this won't get created in sharedWithDelegate:, so do it manually here
    if (!LuaSkin.mainLuaState) {
        [skin createLuaState];
        skin.delegate = MJLuaLogDelegate; // FIXME: Is this needed?
        // ANS: since a new delegate object is created here, yes because LuaSkin's initWithDelegate isn't called, so the new delegate isn't assigned
        // should consider whether or not we really need to create new object but that's for another day...
        skin = [LuaSkin sharedWithState:NULL] ; // make sure skin.L points to the main state since we just created a new one
    }
    [MJLuaLogDelegate setLuaState:skin.L];
    oldPanicFunction = lua_atpanic([skin L], &MJLuaAtPanic) ;
}

// Configure a Lua environment that has already been created by LuaSkin
void MJLuaInit(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    lua_State* L = skin.L;

    refTable = [skin registerLibrary:"core" functions:corelib metaFunctions:nil];
    push_hammerAppInfo(L) ;
    lua_setfield(L, -2, "processInfo") ;

    lua_setglobal(L, "hs");

    int loadresult = luaL_loadfile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
    if (loadresult != 0) {
        HSNSLOG(@"Unable to load setup.lua from bundle. Terminating");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hammerspoon installation is corrupted"];
        [alert setInformativeText:@"Please re-install Hammerspoon"];
        [alert setAlertStyle:NSAlertStyleCritical];
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

    if (lua_pcall(L, 7, 2, 0) != LUA_OK) {
        NSString *errorMessage = [NSString stringWithFormat:@"%s", lua_tostring(L, -1)] ;
        lua_pop(L, 1); // Pop the error message off the stack
        HSNSLOG(@"Error running setup.lua:%@", errorMessage);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Hammerspoon initialization failed"];
        [alert setInformativeText:errorMessage];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert runModal];
    } else {
        if (lua_gettop(L) != 2 || lua_type(L, -1) != LUA_TFUNCTION || lua_type(L, -2) != LUA_TFUNCTION) {
            NSString *debugPart = [NSString stringWithFormat:@"setup.lua returned this: %d:%d:%d", lua_gettop(L), (lua_gettop(L) >= 1) ? lua_type(L, -1) : -10, (lua_gettop(L) >= 2) ? lua_type(L, -2) : -10];

            NSString *errorMessage = [NSString stringWithFormat:@"setup.lua failed to return the two items it is supposed to.\nThis is a severe bug. We would really appreciate your help in getting this fixed - please relaunch Hammerspoon so a crash report can be uploaded, then contact the Hammerspoon developers via GitHub."];
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Critical startup failure bug"];
            [alert setInformativeText:errorMessage];
            [alert setAlertStyle:NSAlertStyleCritical];
            [alert runModal];

            [skin logBreadcrumb:[NSString stringWithFormat:@"setup.lua returned incorrectly: %@", debugPart]];

            // Fall through this, so we crash, so we can get the crash report
        }
        evalfn = [skin luaRef:refTable];
        completionsForWordFn = [skin luaRef:refTable];
    }
}

// Accessibility State Callback:
void callAccessibilityStateCallback(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "accessibilityStateCallback");

    if (lua_type(L, -1) == LUA_TNIL) {
        // There is no callback set, so just pop the callback and carry on
        lua_pop(L, 1);
    } else {
        [skin protectedCallAndError:@"hs.callAccessibilityStateCallback" nargs:0 nresults:0];
    }

    // Pop the hs global off the stack
    lua_pop(L, 1);
    _lua_stackguard_exit(L);
}

// Text Dropped to Dock Icon Callback:
void textDroppedToDockIcon(NSString *pboardString) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "textDroppedToDockIconCallback");

    if (lua_type(L, -1) == LUA_TNIL) {
        // There is no callback set, so just pop the callback and carry on
        lua_pop(L, 1);
    } else {
        [skin pushNSObject:pboardString];
        [skin protectedCallAndError:@"hs.textDroppedToDockIconCallback" nargs:1 nresults:0];
    }

    // Pop the hs global off the stack
    lua_pop(L, 1);
    _lua_stackguard_exit(L);
}

// File Dropped to Dock Icon Callback:
void fileDroppedToDockIcon(NSString *filePath) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "fileDroppedToDockIconCallback");

    if (lua_type(L, -1) == LUA_TNIL) {
        // There is no callback set, so just pop the callback and carry on
        lua_pop(L, 1);
    } else {
        [skin pushNSObject:filePath];
        [skin protectedCallAndError:@"hs.fileDroppedToDockIconCallback" nargs:1 nresults:0];
    }

    // Pop the hs global off the stack
    lua_pop(L, 1);
    _lua_stackguard_exit(L);
}

// Dock Icon Click Callback:
void callDockIconCallback(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;

    if (L == NULL) {
        // It seems to be possible that NSApplicationDelegate:applicationShouldHandleReopen can be called before a Lua state has been created. We need to bail out immediately or we'll cause a crash.
        return;
    }

    _lua_stackguard_entry(L);

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "dockIconClickCallback");

    if (lua_type(L, -1) == LUA_TNIL) {
        // There is no callback set, so just pop the callback and carry on
        lua_pop(L, 1);
    } else {
        [skin protectedCallAndError:@"hs.dockIconClickCallback" nargs:0 nresults:0];
    }

    // Pop the hs global off the stack
    lua_pop(L, 1);
    _lua_stackguard_exit(L);
}

// Shutdown Callback
static int callShutdownCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    _lua_stackguard_entry(skin.L);

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "shutdownCallback");

    if (lua_type(L, -1) == LUA_TNIL) {
        // There is no callback set, so just pop the callback and carry on
        lua_pop(L, 1);
    } else {
        [skin protectedCallAndError:@"hs.shutdownCallback" nargs:0 nresults:0];
    }

    // Pop the hs global off the stack
    lua_pop(L, 1);
    _lua_stackguard_exit(skin.L);
    return 0;
}

// Deconfigure a Lua environment that will shortly be destroyed by LuaSkin
void MJLuaDeinit(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    callShutdownCallback(skin.L);

    [MJLuaLogDelegate setLuaState:nil];
}

// Destroy a Lua environment with LuaSiin
void MJLuaDealloc(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    [skin destroyLuaState];
}

NSString* MJLuaRunString(NSString* command) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State* L = skin.L;
    _lua_stackguard_entry(L);

    [skin pushLuaRef:refTable ref:evalfn];
    if (!lua_isfunction(L, -1)) {
        HSNSLOG(@"ERROR: MJLuaRunString doesn't seem to have an evalfn");
        if (lua_isstring(L, -1)) {
            HSNSLOG(@"evalfn appears to be a string: %s", lua_tostring(L, -1));
        }
        // Whatever evalfn was, it wasn't a function, so pop it
        lua_pop(L, 1);
        _lua_stackguard_exit(L);
        return @"";
    }
    lua_pushstring(L, [command UTF8String]);
    if ([skin protectedCallAndTraceback:1 nresults:1] == NO) {
        const char *errorMsg = lua_tostring(L, -1);
        [skin logError:[NSString stringWithUTF8String:errorMsg]];
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

    _lua_stackguard_exit(L);
    return str;
}

NSArray *MJLuaCompletionsForWord(NSString *completionWord) {
    //NSLog(@"Fetching completions for %@", completionWord);
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);

    [skin pushLuaRef:refTable ref:completionsForWordFn];
    [skin pushNSObject:completionWord];
    if ([skin protectedCallAndError:@"MJLuaCompletionsForWord" nargs:1 nresults:1] == NO) {
        _lua_stackguard_exit(skin.L);
        return @[];
    }

    NSArray *completions = [skin toNSObjectAtIndex:-1];
    lua_pop(skin.L, 1);
    _lua_stackguard_exit(skin.L);
    return completions;
}

// C-Code helper to return current active LuaState. Useful for callbacks to
// verify stored LuaState still matches active one if GC fails to clear it.
lua_State* MJGetActiveLuaState(void) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
  return skin.L ;
}
