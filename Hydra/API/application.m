#import "helpers.h"
void new_window(lua_State* L, AXUIElementRef win);

/// application
///
/// Manipulate running applications.

#define hydra_app(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "application"))
#define nsobject_for_app(L, idx) [NSRunningApplication runningApplicationWithProcessIdentifier: pid_for_app(L, idx)]

static pid_t pid_for_app(lua_State* L, int idx) {
    hydra_app(L, idx); // type-checking
    lua_getuservalue(L, idx);
    lua_getfield(L, -1, "pid");
    pid_t p = lua_tonumber(L, -1);
    lua_pop(L, 2);
    return p;
}

static int application_eq(lua_State* L) {
    pid_t p1 = pid_for_app(L, 1);
    pid_t p2 = pid_for_app(L, 2);
    lua_pushboolean(L, (p1 == p2));
    return 1;
}

static int application_gc(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    CFRelease(app);
    return 0;
}

void new_application(lua_State* L, pid_t pid) {
    AXUIElementRef* appptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *appptr = AXUIElementCreateApplication(pid);
    
    luaL_getmetatable(L, "application");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_pushnumber(L, pid);
    lua_setfield(L, -2, "pid");
    lua_setuservalue(L, -2);
}

/// application.runningapplications() -> app[]
/// Returns all running apps.
static int application_runningapplications(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        new_application(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

/// application.applicationforpid(pid) -> app or nil
/// Returns the running app for the given pid, if it exists.
static int application_applicationforpid(lua_State* L) {
    pid_t pid = luaL_checknumber(L, 1);
    
    NSRunningApplication* runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    
    if (runningApp)
        new_application(L, [runningApp processIdentifier]);
    else
        lua_pushnil(L);
    
    return 1;
}

/// application.applicationsforbundleid(bundleid) -> app[]
/// Returns any running apps that have the given bundleid.
static int application_applicationsforbundleid(lua_State* L) {
    const char* bundleid = luaL_checkstring(L, 1);
    NSString* bundleIdentifier = [NSString stringWithUTF8String:bundleid];
    
    lua_newtable(L);
    int i = 1;
    
    NSArray* runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    for (NSRunningApplication* runningApp in runningApps) {
        new_application(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

/// application:allwindows() -> window[]
/// Returns all open windows owned by the given app.
static int application_allwindows(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
    lua_newtable(L);
    
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

// a few private methods for app:activate(), defined in Lua

static int application__activate(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    BOOL allwindows = lua_toboolean(L, 2);
    BOOL success = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps | (allwindows ? NSApplicationActivateAllWindows : 0)];
    lua_pushboolean(L, success);
    return 1;
}

static int application__focusedwindow(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(app, (__bridge CFStringRef)NSAccessibilityFocusedWindowAttribute, &window) == kAXErrorSuccess) {
        new_window(L, window);
    }
    else {
        lua_pushnil(L);
    }
    return 1;
}

static int application__bringtofront(lua_State* L) {
    pid_t pid = pid_for_app(L, 1);
    BOOL allwindows = lua_toboolean(L, 2);
    ProcessSerialNumber psn;
    GetProcessForPID(pid, &psn);
    BOOL success = (SetFrontProcessWithOptions(&psn, allwindows ? 0 : kSetFrontProcessFrontWindowOnly) == noErr);
    lua_pushboolean(L, success);
    return 1;
}

/// application:title() -> string
/// Returns the localized name of the app (in UTF8).
static int application_title(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

/// application:bundleid() -> string
/// Returns the bundle identifier of the app.
static int application_bundleid(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    lua_pushstring(L, [[app bundleIdentifier] UTF8String]);
    return 1;
}

/// application:unhide()
/// Unhides the app (and all its windows) if it's hidden.
static int application_unhide(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    [app unhide];
    return 0;
}

/// application:hide()
/// Hides the app (and all its windows).
static int application_hide(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    [app hide];
    return 0;
}

/// application:kill()
/// Tries to terminate the app.
static int application_kill(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    [app terminate];
    return 0;
}

/// application:kill9()
/// Assuredly terminates the app.
static int application_kill9(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    [app forceTerminate];
    return 0;
}

/// application:ishidden() -> bool
/// Returns whether the app is currently hidden.
static int application_ishidden(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

/// application:pid() -> number
/// Returns the app's process identifier.
static int application_pid(lua_State* L) {
    lua_pushnumber(L, pid_for_app(L, 1));
    return 1;
}

static const luaL_Reg applicationlib[] = {
    {"runningapplications", application_runningapplications},
    {"applicationforpid", application_applicationforpid},
    {"applicationsforbundleid", application_applicationsforbundleid},
    
    {"allwindows", application_allwindows},
    {"_activate", application__activate},
    {"_focusedwindow", application__focusedwindow},
    {"_bringtofront", application__bringtofront},
    {"title", application_title},
    {"bundleid", application_bundleid},
    {"unhide", application_unhide},
    {"hide", application_hide},
    {"kill", application_kill},
    {"kill9", application_kill9},
    {"ishidden", application_ishidden},
    {"pid", application_pid},
    
    {NULL, NULL}
};

int luaopen_application(lua_State* L) {
    luaL_newlib(L, applicationlib);
    
    if (luaL_newmetatable(L, "application")) {
        lua_pushvalue(L, -2); // 'application' table
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, application_eq);
        lua_setfield(L, -2, "__eq");
        
        lua_pushcfunction(L, application_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);
    
    return 1;
}
