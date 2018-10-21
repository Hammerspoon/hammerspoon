#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "application.h"
#import "../window/window.h"

#define get_app(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "hs.application"))
#define nsobject_for_app(L, idx) [NSRunningApplication runningApplicationWithProcessIdentifier: pid_for_app(L, idx)]

static pid_t pid_for_app(lua_State* L, int idx) {
    get_app(L, idx); // type-checking
    lua_getuservalue(L, idx);
    lua_getfield(L, -1, "pid");
    pid_t p = (pid_t)lua_tointeger(L, -1);
    lua_pop(L, 2);
    return p;
}

static int application_gc(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);
    CFRelease(app);
    return 0;
}

/// hs.application.frontmostApplication() -> hs.application object
/// Function
/// Returns the application object for the frontmost (active) application.  This is the application which currently receives input events.
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.application object
static int application_frontmostapplication(lua_State* L) {
    NSRunningApplication* runningApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (runningApp) {
        if (!new_application(L, [runningApp processIdentifier])) {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
return 1;
}

/// hs.application.runningApplications() -> list of hs.application objects
/// Function
/// Returns all running apps.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing zero or more hs.application objects currently running on the system
static int application_runningapplications(lua_State* L) {
    lua_newtable(L);
    int i = 1;

    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if (new_application(L, [runningApp processIdentifier])) {
            lua_rawseti(L, -2, i++);
        }
    }

    return 1;
}

/// hs.application.applicationForPID(pid) -> hs.application object or nil
/// Function
/// Returns the running app for the given pid, if it exists.
///
/// Parameters:
///  * pid - a UNIX process id (i.e. a number)
///
/// Returns:
///  * An hs.application object if one can be found, otherwise nil
static int application_applicationforpid(lua_State* L) {
    pid_t pid = (pid_t)luaL_checkinteger(L, 1);

    NSRunningApplication* runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];

    if (runningApp) {
        if (!new_application(L, [runningApp processIdentifier])) {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.application.applicationsForBundleID(bundleID) -> list of hs.application objects
/// Function
/// Returns any running apps that have the given bundleID.
///
/// Parameters:
///  * bundleID - An OSX application bundle indentifier
///
/// Returns:
///  * A table of zero or more hs.application objects that match the given identifier
static int application_applicationsForBundleID(lua_State* L) {
    const char* bundleid = luaL_checkstring(L, 1);
    NSString* bundleIdentifier = [NSString stringWithUTF8String:bundleid];

    lua_newtable(L);
    int i = 1;

    NSArray* runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    for (NSRunningApplication* runningApp in runningApps) {
        if (new_application(L, [runningApp processIdentifier])) {
            lua_rawseti(L, -2, i++);
        }
    }

    return 1;
}

/// hs.application.nameForBundleID(bundleID) -> string or nil
/// Function
/// Gets the name of an application from its bundle identifier
///
/// Parameters:
///  * bundleID - A string containing an application bundle identifier (e.g. "com.apple.Safari")
///
/// Returns:
///  * A string containing the application name, or nil if the bundle identifier could not be located
static int application_nameForBundleID(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *appPath = [ws absolutePathForAppBundleWithIdentifier:[NSString stringWithUTF8String:lua_tostring(L, 1)]];
    NSBundle *app = [NSBundle bundleWithPath:appPath];

    NSString *appName = [app objectForInfoDictionaryKey:(id)kCFBundleNameKey];

    lua_pushstring(L, [appName UTF8String]);
    return 1;
}

/// hs.application.pathForBundleID(bundleID) -> string or nil
/// Function
/// Gets the filesystem path of an application from its bundle identifier
///
/// Parameters:
///  * bundleID - A string containing an application bundle identifier (e.g. "com.apple.Safari")
///
/// Returns:
///  * A string containing the app bundle's filesystem path, or nil if the bundle identifier could not be located
static int application_pathForBundleID(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[skin toNSObjectAtIndex:1]];

    [skin pushNSObject:appPath];
    return 1;
}

/// hs.application.infoForBundleID(bundleID) -> table or nil
/// Function
/// Gets the metadata of an application from its bundle identifier
///
/// Parameters:
///  * bundleID - A string containing an application bundle identifier (e.g. "com.apple.Safari")
///
/// Returns:
///  * A table containing information about the application, or nil if the bundle identifier could not be located
static int application_infoForBundleID(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *appPath = [ws absolutePathForAppBundleWithIdentifier:[skin toNSObjectAtIndex:1]];
    NSBundle *app = [NSBundle bundleWithPath:appPath];

    if (app) {
        [skin pushNSObject:app.infoDictionary];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.application.infoForBundlePath(bundlePath) -> table or nil
/// Function
/// Gets the metadata of an application from its path on disk
///
/// Parameters:
///  * bundlePath - A string containing the path to an application bundle (e.g. "/Applications/Safari.app")
///
/// Returns:
///  * A table containing information about the application, or nil if the bundle could not be located
static int application_infoForBundlePath(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSBundle *app = [NSBundle bundleWithPath:[skin toNSObjectAtIndex:1]];

    if (app) {
        [skin pushNSObject:app.infoDictionary];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.application:allWindows() -> list of hs.window objects
/// Method
/// Returns all open windows owned by the given app.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of zero or more hs.window objects owned by the application
///
/// Notes:
///  * This function can only return windows in the current Mission Control Space; if you need to address windows across
///    different Spaces you can use the `hs.window.filter` module
///    - if `Displays have separate Spaces` is *on* (in System Preferences>Mission Control) the current Space is defined
///      as the union of all currently visible Spaces
///    - minimized windows and hidden windows (i.e. belonging to hidden apps, e.g. via cmd-h) are always considered
///      to be in the current Space

static int application_allWindows(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);

    lua_newtable(L);

    if (!app) return 1;

    CFArrayRef windows;
    AXError result = AXUIElementCopyAttributeValues(app, kAXWindowsAttribute, 0, 100, &windows);
    if (result == kAXErrorSuccess) {
        for (NSInteger i = 0; i < CFArrayGetCount(windows); i++) {
            AXUIElementRef win = CFArrayGetValueAtIndex(windows, i);
            CFRetain(win);

            new_window(L, win);
            lua_rawseti(L, -2, (int)(i + 1));
        }
        CFRelease(windows);
    }

    return 1;
}

/// hs.application:mainWindow() -> hs.window object or nil
/// Method
/// Returns the main window of the given app, or nil.
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.window object representing the main window of the application, or nil if it has no windows
static int application_mainWindow(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);

    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute, &window) == kAXErrorSuccess) {
        new_window(L, window);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.application:focusedWindow() -> hs.window object or nil
/// Method
/// Returns the currently focused window of the application, or nil
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.window object representing the window of the application that currently has focus, or nil if there are none
static int application_focusedWindow(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);

    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, &window) == kAXErrorSuccess) {
        new_window(L, window);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

// a few private methods for app:activate(), defined in Lua

static int application__activate(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    BOOL allWindows = lua_toboolean(L, 2);
    BOOL success = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps | (allWindows ? NSApplicationActivateAllWindows : 0)];
    lua_pushboolean(L, success);
    return 1;
}

static int application__focusedwindow(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);
    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &window) == kAXErrorSuccess) {
        new_window(L, window);
    }
    else {
        lua_pushnil(L);
    }
    return 1;
}

static int application_isunresponsive(lua_State* L) {
    // lol apple
    typedef int CGSConnectionID;
    CG_EXTERN CGSConnectionID CGSMainConnectionID(void);
    bool CGSEventIsAppUnresponsive(CGSConnectionID cid, const ProcessSerialNumber *psn);
    // srsly come on now

    pid_t pid = pid_for_app(L, 1);
    ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    GetProcessForPID(pid, &psn);
#pragma clang diagnostic pop

    CGSConnectionID conn = CGSMainConnectionID();
    bool is = CGSEventIsAppUnresponsive(conn, &psn);

    lua_pushboolean(L, is);
    return 1;
}

static int application__bringtofront(lua_State* L) {
    pid_t pid = pid_for_app(L, 1);
    BOOL allWindows = lua_toboolean(L, 2);
    ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    GetProcessForPID(pid, &psn);
    BOOL success = (SetFrontProcessWithOptions(&psn, allWindows ? 0 : kSetFrontProcessFrontWindowOnly) == noErr);
#pragma clang diagnostic pop
    lua_pushboolean(L, success);
    return 1;
}

/// hs.application:title() -> string
/// Method
/// Returns the localized name of the app (in UTF8).
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the application
static int application_title(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

/// hs.application:bundleID() -> string
/// Method
/// Returns the bundle identifier of the app.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the bundle identifier of the application
static int application_bundleID(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    lua_pushstring(L, [[app bundleIdentifier] UTF8String]);
    return 1;
}

/// hs.application:path() -> string
/// Method
/// Returns the filesystem path of the app.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the filesystem path of the application or nil if the path could not be determined (e.g. if the application has terminated).
static int application_path(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    NSURL *appURL = [app bundleURL] ;
    if (appURL) {
        NSString *appPath = [NSBundle bundleWithURL:appURL].bundlePath;
        [[LuaSkin shared] pushNSObject:appPath];
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.application:isRunning() -> boolean
/// Method
/// Checks if the application is still running
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the application is running, false if not
///
/// Notes:
///  * If an application is terminated and re-launched, this method will still return false, as `hs.application` objects are tied to a specific instance of an application (i.e. its PID)
static int application_isRunning(lua_State *L) {
    NSRunningApplication *app = nsobject_for_app(L, 1);
    lua_pushboolean(L, (app != nil));
    return 1;
}

/// hs.application:unhide() -> boolean
/// Method
/// Unhides the app (and all its windows) if it's hidden.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the application was successfully unhidden
static int application_unhide(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);
    BOOL success = (AXUIElementSetAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, kCFBooleanFalse) == kAXErrorSuccess);
    lua_pushboolean(L, success);
    return 1;
}

/// hs.application:hide() -> boolean
/// Method
/// Hides the app (and all its windows).
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the application was successfully hidden
static int application_hide(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);
    BOOL success = (AXUIElementSetAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, kCFBooleanTrue) == kAXErrorSuccess);
    lua_pushboolean(L, success);
    return 1;
}

/// hs.application:kill()
/// Method
/// Tries to terminate the app gracefully.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int application_kill(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);

    [app terminate];
    return 0;
}

/// hs.application:kill9()
/// Method
/// Tries to terminate the app forcefully.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int application_kill9(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);

    [app forceTerminate];
    return 0;
}

/// hs.application:isHidden() -> boolean
/// Method
/// Returns whether the app is currently hidden.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the application is hidden or not
static int application_ishidden(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);

    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }

    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

/// hs.application:isFrontmost() -> boolean
/// Method
/// Returns whether the app is the frontmost (i.e. is the currently active application)
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the application is the frontmost application, otherwise false
static int application_isfrontmost(lua_State* L) {
    AXUIElementRef app = get_app(L, 1);

    CFTypeRef _isFrontmost;
    NSNumber* isFrontmost = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFrontmostAttribute, (CFTypeRef *)&_isFrontmost) == kAXErrorSuccess) {
        isFrontmost = CFBridgingRelease(_isFrontmost);
    }
    lua_pushboolean(L, [isFrontmost boolValue]);
    return 1;
}

/// hs.application:pid() -> number
/// Method
/// Returns the app's process identifier.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The UNIX process identifier of the application (i.e. a number)
static int application_pid(lua_State* L) {
    lua_pushinteger(L, pid_for_app(L, 1));
    return 1;
}

/// hs.application:kind() -> number
/// Method
/// Identify the application's GUI state
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number that is either 1 if the app is in the dock, 0 if it is not, or -1 if the application is prohibited from having GUI elements
static int application_kind(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    NSApplicationActivationPolicy pol = [app activationPolicy];

    int kind = 1;
    switch (pol) {
        case NSApplicationActivationPolicyAccessory:  kind =  0; break;
        case NSApplicationActivationPolicyProhibited: kind = -1; break;
        default: break;
    }

    lua_pushinteger(L, kind);
    return 1;
}

// Internal helper function to get an AXUIElementRef for a menu item in an app, by searching all menus
AXUIElementRef _findmenuitembyname(lua_State* L, AXUIElementRef app, NSString *name, BOOL nameIsRegex) {
    LuaSkin *skin = [LuaSkin shared];
    AXUIElementRef foundItem = nil;
    AXUIElementRef menuBar;
    AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar);
    if (error) {
        return nil;
    }

    CFIndex count = -1;
    error = AXUIElementGetAttributeValueCount(menuBar, kAXChildrenAttribute, &count);
    if (error) {
        CFRelease(menuBar);
        return nil;
    }

    CFArrayRef cf_children;
    error = AXUIElementCopyAttributeValues(menuBar, kAXChildrenAttribute, 0, count, &cf_children);
    if (error) {
        CFRelease(menuBar);
        return nil;
    }

    NSMutableArray *toCheck = [[NSMutableArray alloc] init];
    [toCheck addObjectsFromArray:(__bridge_transfer NSArray *)cf_children];

    int i = 5000; // This acts as a guard against this loop mysteriously running away
    while (i > 0) {
        i--;
        if ([toCheck count] == 0) {
            break;
        }

        // Get the first item in our queue and pop it out of the queue
        id firstObject = [toCheck firstObject];
        AXUIElementRef element = (__bridge AXUIElementRef)firstObject;
        [toCheck removeObjectIdenticalTo:firstObject];

        CFTypeRef cf_title;
        AXError error;

        AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &cf_title);
        NSString *title = (__bridge_transfer NSString *)cf_title;

        // Check if this is a submenu, if so add its children to the toCheck array
        CFIndex childcount = -1;
        error = AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute, &childcount);
        if (error) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"Got an error (%d) checking child count, skipping", (int)error]];
            continue;
        }
        if (childcount > 0) {
            // This is a submenu. Collect its children into toCheck and continue iterating
            CFArrayRef cf_menuchildren;
            error = AXUIElementCopyAttributeValues(element, kAXChildrenAttribute, 0, childcount, &cf_menuchildren);
            if (error) {
                [skin logBreadcrumb:[NSString stringWithFormat:@"Got an error (%d) fetching menu children, skipping", (int)error]];
                continue;
            }
            [toCheck addObjectsFromArray:(__bridge NSArray *)cf_menuchildren];
        } else if (childcount == 0) {
            // This doesn't seem to be a submenu, so see if it's a match
            if (!nameIsRegex && [name isEqualToString:title]) {
                // It's a match. Store a reference to it and break out of the loop
                foundItem = element;
                break;
            } else {
                NSPredicate *matchTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", name];
                if ([matchTest evaluateWithObject:title]) {
                    NSLog(@"win");
                    foundItem = element;
                    break;
                }
            }
        }
    }
    CFRelease(menuBar);

    if (i == 0) {
        [skin logWarn:@"_findmenuitembyname() overflowed 5000 iteration guard. This is either a Hammerspoon bug, or your menus are too deep"];
        return nil;
    }

    return foundItem;
}
//
// Internal helper function to get an AXUIElementRef for a menu item in an app, by following the menu path provided
AXUIElementRef _findmenuitembypath(lua_State* L __unused, AXUIElementRef app, NSArray *_path) {
    LuaSkin *skin = [LuaSkin shared];
    AXUIElementRef foundItem = nil;
    AXUIElementRef menuBar;
    AXUIElementRef searchItem;
    NSString *nextMenuItem;
    NSMutableArray *path = [[NSMutableArray alloc] initWithCapacity:[_path count]];
    [path addObjectsFromArray:_path];

    AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar);
    if (error) {
        return nil;
    }

    // searchItem will be the generic variable we search in our loop
    searchItem = menuBar;

    CFArrayRef cf_children = NULL;
    // Loop over cf_children for first element in path, then descend down path
    int i = 5000; // Guard ourself against infinite loops
    while (!foundItem && i > 0) {
        i--;

        CFIndex count = -1;
        error = AXUIElementGetAttributeValueCount(searchItem, kAXChildrenAttribute, &count);
        if (error) {
            [skin logBreadcrumb:@"Failed to get child count"];
            break;
        }

        error = AXUIElementCopyAttributeValues(searchItem, kAXChildrenAttribute, 0, count, &cf_children);
        if (error) {
            [skin logBreadcrumb:@"Failed to get children"];
            break;
        }

        // Check if the first child is an AXMenu, if so, we don't care about it and want its child
        if (count > 0) {
            CFTypeRef cf_role;
            AXUIElementRef aSearchItem = (AXUIElementRef)CFArrayGetValueAtIndex(cf_children, 0);
            error = AXUIElementCopyAttributeValue(aSearchItem, kAXRoleAttribute, &cf_role);
            if (error) {
                [skin logBreadcrumb:@"Failed to get role"];
                break;
            }
            BOOL isMenuRole = CFStringCompare((CFStringRef)cf_role, kAXMenuRole, 0);
            CFRelease(cf_role);

            if(isMenuRole == kCFCompareEqualTo) {
                // It's an AXMenu
                CFIndex axMenuCount = -1;
                error = AXUIElementGetAttributeValueCount(aSearchItem, kAXChildrenAttribute, &axMenuCount);
                if (error) {
                    [skin logBreadcrumb:@"Failed to get AXMenu child count"];
                    CFRelease(cf_children);
                    break;
                }
                CFArrayRef axMenuChildren;
                error = AXUIElementCopyAttributeValues(aSearchItem, kAXChildrenAttribute, 0, axMenuCount, &axMenuChildren);
                if (error) {
                    CFRelease(cf_children);
                    [skin logBreadcrumb:@"Failed to get AXMenu children"];
                    break;
                }
                // Replace the existing children array with the new one we have retrieved
                CFRelease(cf_children);
                cf_children = axMenuChildren;
            }
        }

        // Get the NSString containing the name of the next submenu/menuitem we're looking for
        nextMenuItem = [path objectAtIndex:0];
        [path removeObjectAtIndex:0];

        // Search the available AXMenu children for the submenu/menuitem name we're looking for
        BOOL found = false;

        for (CFIndex j = 0; j < CFArrayGetCount(cf_children); j++) {
            CFTypeRef cf_title;
            AXUIElementRef testMenuItem = (AXUIElementRef)CFArrayGetValueAtIndex(cf_children, j);
            AXError error = AXUIElementCopyAttributeValue(testMenuItem, kAXTitleAttribute, &cf_title);
            if (error) {
                [skin logBreadcrumb:@"Unable to get menu item title"];
                continue;
            }
            if ([nextMenuItem isEqualToString:(__bridge NSString *)cf_title]) {
                found = true;
                searchItem = testMenuItem;
            }
            CFRelease(cf_title);
            if (found) {
                break;
            }
        }

        if (!found) {
            [skin logBreadcrumb:@"Unable to resolve complete search path"];
            break;
        }

        if ([path count] == 0) {
            // We're at the bottom of the path, so the object we just found is the one we're looking for, we can break out of the loop
            foundItem = searchItem;
            break;
        }
    }

    CFRelease(menuBar);

    return foundItem;
}

/// hs.application:findMenuItem(menuItem[, isRegex]) -> table or nil
/// Method
/// Searches the application for a menu item
///
/// Parameters:
///  * menuItem - This can either be a string containing the text of a menu item (e.g. `"Messages"`) or a table representing the hierarchical path of a menu item (e.g. `{"File", "Share", "Messages"}`). In the string case, all of the application's menus will be searched until a match is found (with no specified behaviour if multiple menu items exist with the same name). In the table case, the whole menu structure will not be searched, because a precise path has been specified.
///  * isRegex - An optional boolean, defaulting to false, which is only used if `menuItem` is a string. If set to true, `menuItem` will be treated as a regular expression rather than a strict string to match against
///
/// Returns:
///  * Returns nil if the menu item cannot be found. If it does exist, returns a table with two keys:
///   * enabled - whether the menu item can be selected/ticked. This will always be false if the application is not currently focussed
///   * ticked - whether the menu item is ticked or not (obviously this value is meaningless for menu items that can't be ticked)
///
/// Notes:
///  * This can only search for menu items that don't have children - i.e. you can't search for the name of a submenu
static int application_findmenuitem(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    AXError error;
    AXUIElementRef app = get_app(L, 1);
    AXUIElementRef foundItem;
    NSString *name;
    NSMutableArray *path;
    if (lua_isstring(L, 2)) {
        BOOL nameIsRegex = NO;
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            nameIsRegex = lua_toboolean(L, 3);
        }
        name = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        foundItem = _findmenuitembyname(L, app, name, nameIsRegex);
    } else if (lua_istable(L, 2)) {
        path = [[NSMutableArray alloc] init];
        lua_pushnil(L);
        while (lua_next(L, 2) != 0) {
            NSString *item = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
            [path addObject:item];
            lua_pop(L, 1);
        }
        foundItem = _findmenuitembypath(L, app, path);
    } else {
        [skin logWarn:@"hs.application:findMenuItem() Unrecognised type for menuItem argument. Expecting string or table"];
        lua_pushnil(L);
        return 1;
    }

    if (!foundItem) {
        if (name) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"Couldn't find menu item %@", name]];
        } else if (path) {
            [skin logBreadcrumb:@"Couldn't find menu item"];
        }
        lua_pushnil(L);
        return 1;
    }

    CFTypeRef enabled;
    error = AXUIElementCopyAttributeValue(foundItem, kAXEnabledAttribute, &enabled);
    if (error) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"hs.application:findMenuItem: AXEnabled Error: %d", error]];
        lua_pushnil(L);
        return 1;
    }
    CFTypeRef markchar;
    error = AXUIElementCopyAttributeValue(foundItem, kAXMenuItemMarkCharAttribute, &markchar);
    if (error && error != kAXErrorNoValue) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"hs.application:findMenuItem: AXMenuItemMarkChar: %d", error]];
        lua_pushnil(L);
        return 1;
    }
    BOOL marked;
    if (error == kAXErrorNoValue) {
        // There's no value, which mean MarkChar is (null) and the menu item is not ticked
        marked = false;
    } else {
        // We might want to explicitly check for ✓ here, but this seems to be reliable enough for now
        marked = true;
    }

    lua_newtable(L);

    lua_pushstring(L, "enabled");
    lua_pushboolean(L, [(__bridge NSNumber *)enabled boolValue]);
    lua_settable(L, -3);

    lua_pushstring(L, "ticked");
    lua_pushboolean(L, marked);
    lua_settable(L, -3);

    return 1;
}

/// hs.application:selectMenuItem(menuitem[, isRegex]) -> true or nil
/// Method
/// Selects a menu item (i.e. simulates clicking on the menu item)
///
/// Parameters:
///  * menuitem - The menu item to select, specified as either a string or a table. See the `menuitem` parameter of `hs.application:findMenuItem()` for more information.
///  * isRegex - An optional boolean, defaulting to false, which is only used if `menuItem` is a string. If set to true, `menuItem` will be treated as a regular expression rather than a strict string to match against
///
/// Returns:
///  * True if the menu item was found and selected, or nil if it wasn't (e.g. because the menu item couldn't be found)
///
/// Notes:
///  * Depending on the type of menu item involved, this will either activate or tick/untick the menu item
static int application_selectmenuitem(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    AXUIElementRef app = get_app(L, 1);
    AXUIElementRef foundItem;
    NSString *name;
    NSMutableArray *path;

    if (lua_isstring(L, 2)) {
        BOOL nameIsRegex = NO;
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            nameIsRegex = lua_toboolean(L, 3);
        }
        name = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        foundItem = _findmenuitembyname(L, app, name, nameIsRegex);
    } else if (lua_istable(L, 2)) {
        path = [[NSMutableArray alloc] init];
        lua_pushnil(L);
        while (lua_next(L, 2) != 0) {
            NSString *item = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
            [path addObject:item];
            lua_pop(L, 1);
        }
        foundItem = _findmenuitembypath(L, app, path);
    } else {
        [skin logWarn:@"hs.application:selectMenuItem(): Unrecognised type for menuItem argument, expecting string or table"];
        lua_pushnil(L);
        return 1;
    }

    if (!foundItem) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"Couldn't find %@", name]];
        lua_pushnil(L);
        return 1;
    }

    AXError error = AXUIElementPerformAction(foundItem, kAXPressAction);
    if (error) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"hs.application:selectMenuItem(): AXPress error: %d", (int)error]];
        lua_pushnil(L);
        return 1;
    }

    lua_pushboolean(L, 1);
    return 1;
}

id _getMenuStructure(AXUIElementRef menuItem) {
    id thisMenuItem = nil;

    NSMutableArray *attributeNames = [NSMutableArray arrayWithArray:@[(__bridge NSString *)kAXTitleAttribute,
                                                                      (__bridge NSString *)kAXRoleAttribute,
                                                                      //(__bridge NSString *)kAXSubroleAttribute,
                                                                      (__bridge NSString *)kAXMenuItemMarkCharAttribute,
                                                                      (__bridge NSString *)kAXMenuItemCmdCharAttribute,
                                                                      (__bridge NSString *)kAXMenuItemCmdModifiersAttribute,
                                                                      //(__bridge NSString *)kAXMenuItemCmdVirtualKeyAttribute,
                                                                      (__bridge NSString *)kAXEnabledAttribute,
                                                                      (__bridge NSString *)kAXMenuItemCmdGlyphAttribute]];
    CFArrayRef cfAttributeValues = NULL;
    AXError result;

    result = AXUIElementCopyMultipleAttributeValues(menuItem, (__bridge CFArrayRef)attributeNames, 0, &cfAttributeValues);

    if (result != kAXErrorSuccess) {
        [LuaSkin logBreadcrumb:@"Unable to fetch menu structure"];
    } else {
        // See if we're dealing with the "special" Apple menu, and ignore it
        CFTypeRef firstElement = CFArrayGetValueAtIndex(cfAttributeValues, 0);
        if (firstElement && CFGetTypeID(firstElement) == CFStringGetTypeID()) {
            if (CFStringCompare((CFStringRef)CFArrayGetValueAtIndex(cfAttributeValues, 0), (__bridge CFStringRef)@"Apple", 0) == kCFCompareEqualTo) {
                CFRelease(cfAttributeValues);
                cfAttributeValues = nil;
            }
        }
    }

    if (cfAttributeValues) {
        NSMutableArray *attributeValues = (__bridge_transfer NSMutableArray *)cfAttributeValues;
        NSMutableArray *children = nil;
        CFArrayRef cfChildren = 0;

        // Filter out the attributes that could not be found
        for (NSUInteger j = 0; j < [attributeValues count] ; j++) {
            AXValueRef attributeValue = (__bridge AXValueRef)[attributeValues objectAtIndex:j];
            if (AXValueGetType(attributeValue) == kAXValueAXErrorType) {
                [attributeValues replaceObjectAtIndex:j withObject:@""];
            }
        }

        // Convert the modifier keys into a format we can usefully hand over to Lua
        NSUInteger modifiersIndex = [attributeNames indexOfObjectIdenticalTo:(__bridge NSString *)kAXMenuItemCmdModifiersAttribute];
        id modsSrc = [attributeValues objectAtIndex:modifiersIndex];
        id modsDst = nil;
        if (![modsSrc isKindOfClass:[NSNumber class]]) {
            modsDst = [NSNull null];
        } else {
            int modsInt = [modsSrc intValue];
            NSMutableArray *modsArr = [[NSMutableArray alloc] init];
            modsDst = modsArr;

            if (!(modsInt & kAXMenuItemModifierNoCommand)) {
                // cmd is handled differently, it exists unless kAXMenuItemModifierNoCommand is found
                [modsArr addObject:@"cmd"];
            }

            if (modsInt & kAXMenuItemModifierShift) {
                [modsArr addObject:@"shift"];
            }
            if (modsInt & kAXMenuItemModifierOption) {
                [modsArr addObject:@"alt"];
            }
            if (modsInt & kAXMenuItemModifierControl) {
                [modsArr addObject:@"ctrl"];
            }
        }

        [attributeValues replaceObjectAtIndex:modifiersIndex withObject:modsDst];

        // Get the children of this item, if any
        if (AXUIElementCopyAttributeValues(menuItem, kAXChildrenAttribute, 0, MAX_INT, &cfChildren) == kAXErrorSuccess) {
            children = [[NSMutableArray alloc] init];
            CFIndex numChildren = CFArrayGetCount(cfChildren);

            for (CFIndex i = 0; i < numChildren; i++) {
                CFTypeRef child = CFArrayGetValueAtIndex(cfChildren, i);
                id childValues = _getMenuStructure((AXUIElementRef)child);

                if (![childValues isKindOfClass:[NSNull class]]) {
                    [children addObject:childValues];
                }
            }

            CFRelease(cfChildren);

            if ([children count] > 0) {
                [attributeNames  addObject:(__bridge NSString *)kAXChildrenAttribute];
                [attributeValues addObject:children];
            }
        }

        // If we're not a menuitem, we don't belong in the Lua representation of the menu, so we'll either return this object's dictionary, or its array of children
        if ([[attributeValues objectAtIndex:1] isEqualToString:@"AXMenuItem"] || [[attributeValues objectAtIndex:1] isEqualToString:@"AXMenuBarItem"]) {
            thisMenuItem = [NSMutableDictionary dictionaryWithObjects:attributeValues forKeys:attributeNames];
        } else {
            thisMenuItem = children;
        }
    }

    if (thisMenuItem && [thisMenuItem count] > 0) {
        return thisMenuItem;
    } else {
        return [NSNull null];
    }
}

/// hs.application:getMenuItems([fn]) -> table or nil | hs.application object
/// Method
/// Gets the menu structure of the application
///
/// Parameters:
///  * fn - an optional callback function.  If provided, the function will receive a single argument and return none.
///
/// Returns:
///  * If no argument is provided, returns a table containing the menu structure of the application, or nil if an error occurred. If a callback function is provided, the callback function will receive this table (or nil) and this method will return the application object this method was invoked on.
///
/// Notes:
///  * In some applications, this can take a little while to complete, because quite a large number of round trips are required to the source application, to get the information. When this method is invoked without a callback function, Hammerspoon will block while creating the menu structure table.  When invoked with a callback function, the menu structure is built in a background thread.
///
///  * The table is nested with the same structure as the menus of the application. Each item has several keys containing information about the menu item. Not all keys will appear for all items. The possible keys are:
///   * AXTitle - A string containing the text of the menu item (entries which have no title are menu separators)
///   * AXEnabled - A boolean, 1 if the menu item is clickable, 0 if not
///   * AXRole - A string containing the role of the menu item - this will be either AXMenuBarItem for a top level menu, or AXMenuItem for an item in a menu
///   * AXMenuItemMarkChar - A string containing the "mark" character for a menu item. This is for toggleable menu items and will usually be an empty string or a Unicode tick character (✓)
///   * AXMenuItemCmdModifiers - A table containing string representations of the keyboard modifiers for the menu item's keyboard shortcut, or nil if no modifiers are present
///   * AXMenuItemCmdChar - A string containing the key for the menu item's keyboard shortcut, or an empty string if no shortcut is present
///   * AXMenuItemCmdGlyph - An integer, corresponding to one of the defined glyphs in `hs.application.menuGlyphs` if the keyboard shortcut is a special character usually represented by a pictorial representation (think arrow keys, return, etc), or an empty string if no glyph is used in presenting the keyboard shortcut.
///  * Using `hs.inspect()` on these tables, while useful for exploration, can be extremely slow, taking several minutes to correctly render very complex menus
static int application_getMenus(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.application", LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    AXUIElementRef app = get_app(L, 1);
    if (lua_gettop(L) == 1) {
        NSMutableDictionary *menus = nil;
        AXUIElementRef menuBar;

        if (AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar) == kAXErrorSuccess) {
            menus = _getMenuStructure(menuBar);
            CFRelease(menuBar);
        }

        [skin pushNSObject:menus];
    } else {
        lua_pushvalue(L, 2) ;
        int fnRef = luaL_ref(L, LUA_REGISTRYINDEX) ;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *menus = nil;
            AXUIElementRef menuBar;

            if (AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar) == kAXErrorSuccess) {
                menus = _getMenuStructure(menuBar);
                CFRelease(menuBar);
            }

            LuaSkin *_skin = [LuaSkin shared];
            lua_rawgeti(_skin.L, LUA_REGISTRYINDEX, fnRef) ;
            [_skin pushNSObject:menus] ;
            [_skin protectedCallAndError:@"hs.application:getMenus()" nargs:1 nresults:0];
            luaL_unref(_skin.L, LUA_REGISTRYINDEX, fnRef) ;
        }) ;
        lua_pushvalue(L, 1) ;
    }

    return 1;
}

/// hs.application.launchOrFocus(name) -> boolean
/// Function
/// Launches the app with the given name, or activates it if it's already running
///
/// Parameters:
///  * name - A string containing the name of the application to either launch or focus. This can also be the full path to an application (including the `.app` suffix) if you need to uniquely distinguish between applications in different locations that share the same name
///
/// Returns:
///  * True if the application was either launched or focused, otherwise false (e.g. if the application doesn't exist)
///
/// Notes:
///  * The name parameter should match the name of the application on disk, e.g. "IntelliJ IDEA", rather than "IntelliJ"
static int application_launchorfocus(lua_State* L) {
    NSString* name = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    BOOL success = [[NSWorkspace sharedWorkspace] launchApplication: name];
    lua_pushboolean(L, success);
    return 1;
}

/// hs.application.launchOrFocusByBundleID(bundleID) -> boolean
/// Function
/// Launches the app with the given bundle ID, or activates it if it's already running
///
/// Parameters:
///  * bundleID - A string containing the bundle ID of the application to either launch or focus.
///
/// Returns:
///  * True if the application was either launched or focused, otherwise false (e.g. if the application doesn't exist)
///
/// Notes:
///  * Bundle identifiers typically take the form of `com.company.ApplicationName`
static int application_launchorfocusbybundleID(lua_State* L) {
    NSString* bundleID = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    BOOL success = [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:bundleID options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:NULL];
    lua_pushboolean(L, success);
    return 1;
}

// Trying to make this as close to paste and apply as possible, so not all aspects may apply
// to each module... you may still need to tweak for your specific module.

static int userdata_tostring(lua_State* L) {

// For older modules that don't use this macro, Change this:
#ifndef USERDATA_TAG
#define USERDATA_TAG "hs.application"
#endif

// can't assume, since some older modules and userdata share __index
    void *self = lua_touserdata(L, 1) ;
    if (self) {
// Change these to get the desired title, if available, for your module:
        NSRunningApplication* app = nsobject_for_app(L, 1);
        NSString* title = [app localizedName] ;
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

static const luaL_Reg applicationlib[] = {
    {"runningApplications", application_runningapplications},
    {"frontmostApplication", application_frontmostapplication},
    {"applicationForPID", application_applicationforpid},
    {"applicationsForBundleID", application_applicationsForBundleID},
    {"nameForBundleID", application_nameForBundleID},
    {"pathForBundleID", application_pathForBundleID},
    {"infoForBundleID", application_infoForBundleID},
    {"infoForBundlePath", application_infoForBundlePath},

    {"allWindows", application_allWindows},
    {"mainWindow", application_mainWindow},
    {"focusedWindow", application_focusedWindow},
    {"_activate", application__activate},
    {"_focusedwindow", application__focusedwindow},
    {"_bringtofront", application__bringtofront},
    {"title", application_title},
    {"name", application_title},
    {"bundleID", application_bundleID},
    {"path", application_path},
    {"isRunning", application_isRunning},
    {"unhide", application_unhide},
    {"hide", application_hide},
    {"kill", application_kill},
    {"kill9", application_kill9},
    {"isHidden", application_ishidden},
    {"isFrontmost", application_isfrontmost},
    {"pid", application_pid},
    {"isUnresponsive", application_isunresponsive},
    {"kind", application_kind},
    {"findMenuItem", application_findmenuitem},
    {"selectMenuItem", application_selectmenuitem},
    {"getMenuItems", application_getMenus},
    {"launchOrFocus", application_launchorfocus},
    {"launchOrFocusByBundleID", application_launchorfocusbybundleID},

    {NULL, NULL}
};

static int nsrunningapplication_tolua(lua_State *L, id obj) {
    NSRunningApplication *app = obj ;

    if (!new_application(L, [app processIdentifier])) {
        lua_pop(L, 1) ; // removed aborted userdata
        [[LuaSkin shared] logWarn:[NSString stringWithFormat:@"No Process ID for %@", obj]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static id lua_tonsrunningapplication(lua_State *L, int idx) {
    void *ptr = luaL_testudata(L, idx, "hs.application") ;
    if (ptr) {
        return nsobject_for_app(L, idx);
    } else {
        return nil ;
    }
}

int luaopen_hs_application_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];

    luaL_newlib(L, applicationlib);

    // Inherit hs.uielement
    luaL_getmetatable(L, "hs.uielement");
    lua_setmetatable(L, -2);

    if (luaL_newmetatable(L, "hs.application")) {
        lua_pushvalue(L, -2); // 'application' table
        lua_setfield(L, -2, "__index");

        // Use hs.uilement's equality
        luaL_getmetatable(L, "hs.uielement");
        lua_getfield(L, -1, "__eq");
        lua_remove(L, -2);
        lua_setfield(L, -2, "__eq");

        lua_pushcfunction(L, userdata_tostring) ;
        lua_setfield(L, -2, "__tostring") ;

        lua_pushcfunction(L, application_gc);
        lua_setfield(L, -2, "__gc");

        lua_pushstring(L, "hs.application") ;
        lua_setfield(L, -2, "__type") ;
    }
    lua_pop(L, 1);

    [skin registerPushNSHelper:nsrunningapplication_tolua
                      forClass:"NSRunningApplication"] ;
    [skin registerLuaObjectHelper:lua_tonsrunningapplication
                         forClass:"NSRunningApplication"
              withUserdataMapping:"hs.application"] ;

    return 1;
}
