#import "hydra.h"
void new_window(lua_State* L, AXUIElementRef win);


int app_eq(lua_State* L) {
    lua_getfield(L, 1, "pid");
    lua_getfield(L, 2, "pid");
    
    BOOL equal = (lua_tonumber(L, -1) == lua_tonumber(L, -2));
    lua_pushboolean(L, equal);
    return 1;
}

void new_app(lua_State* L, pid_t pid) {
    lua_newtable(L);
    
    lua_pushnumber(L, pid);
    lua_setfield(L, -2, "pid");
    
    if (luaL_newmetatable(L, "app")) {
        lua_getglobal(L, "api");
        lua_getfield(L, -1, "app");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1); // hydra-global
        
        lua_pushcfunction(L, app_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_setmetatable(L, -2);
}

static hydradoc doc_app_runningapps = {
    "app", "runningapps", "api.app.runningapps() -> app[]",
    "Returns all running apps."
};

int app_runningapps(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        new_app(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

static hydradoc doc_app_appforpid = {
    "app", "appforpid", "api.app.appforpid(pid) -> app or nil",
    "Returns the running app for the given pid, if it exists."
};

int app_appforpid(lua_State* L) {
    pid_t pid = lua_tonumber(L, 1);
    
    NSRunningApplication* runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    
    if (runningApp)
        new_app(L, [runningApp processIdentifier]);
    else
        lua_pushnil(L);
    
    return 1;
}

static hydradoc doc_app_appsforbundleid = {
    "app", "appsforbundleid", "api.app.appsforbundleid(bundleid) -> app[]",
    "Returns any running apps that have the given bundleid."
};

int app_appsforbundleid(lua_State* L) {
    const char* bundleid = lua_tostring(L, 1);
    NSString* bundleIdentifier = [NSString stringWithUTF8String:bundleid];
    
    lua_newtable(L);
    int i = 1;
    
    NSArray* runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    for (NSRunningApplication* runningApp in runningApps) {
        new_app(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

static hydradoc doc_app_allwindows = {
    "app", "allwindows", "api.app:allwindows() -> window[]",
    "Returns all open windows owned by the given app."
};

int app_allwindows(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    lua_newtable(L);
    
    CFArrayRef _windows;
    AXError result = AXUIElementCopyAttributeValues(app, kAXWindowsAttribute, 0, 100, &_windows);
    if (result == kAXErrorSuccess) {
        for (NSInteger i = 0; i < CFArrayGetCount(_windows); i++) {
            AXUIElementRef win = CFArrayGetValueAtIndex(_windows, i);
            CFRetain(win);
            
            new_window(L, win);
            lua_rawseti(L, -2, (int)(i + 1));
        }
        CFRelease(_windows);
    }
    
    CFRelease(app);
    
    return 1;
}

static hydradoc doc_app_activate = {
    "app", "activate", "api.app:activate() -> bool",
    "Tries to activate the app (make it focused) and returns its success."
};

int app_activate(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    BOOL success = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    lua_pushboolean(L, success);
    return 1;
}

static hydradoc doc_app_title = {
    "app", "title", "api.app:title() -> string",
    "Returns the localized name of the app (in UTF8)."
};

int app_title(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

static hydradoc doc_app_bundleid = {
    "app", "bundleid", "api.app:bundleid() -> string",
    "Returns the bundle identifier of the app."
};

int app_bundleid(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    lua_pushstring(L, [[app bundleIdentifier] UTF8String]);
    return 1;
}

static void set_app_prop(AXUIElementRef app, NSString* propType, id value) {
    AXUIElementSetAttributeValue(app, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
    // yes, we ignore the return value; life is too short to constantly handle rare edge-cases
}

static hydradoc doc_app_unhide = {
    "app", "unhide", "api.app:unhide()",
    "Unhides the app (and all its windows) if it's hidden."
};

int app_unhide(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @NO);
    CFRelease(app);
    return 0;
}

static hydradoc doc_app_hide = {
    "app", "hide", "api.app:hide()",
    "Hides the app (and all its windows)."
};

// args: [app]
// ret: []
int app_hide(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @YES);
    CFRelease(app);
    return 0;
}

static hydradoc doc_app_kill = {
    "app", "kill", "api.app:kill()",
    "Tries to terminate the app."
};

// args: [app]
// ret: []
int app_kill(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    [app terminate];
    return 0;
}

static hydradoc doc_app_kill9 = {
    "app", "kill9", "api.app:kill9()",
    "Assuredly terminates the app."
};

// args: [app]
// ret: []
int app_kill9(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    [app forceTerminate];
    return 0;
}

static hydradoc doc_app_ishidden = {
    "app", "ishidden", "api.app:ishidden() -> bool",
    "Returns whether the app is currently hidden."
};

// args: [app]
// ret: [bool]
int app_ishidden(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    CFRelease(app);
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

static const luaL_Reg applib[] = {
    {"runningapps", app_runningapps},
    {"appforpid", app_appforpid},
    {"appsforbundleid", app_appsforbundleid},
    
    {"allwindows", app_allwindows},
    {"activate", app_activate},
    {"title", app_title},
    {"bundleid", app_bundleid},
    {"unhide", app_unhide},
    {"hide", app_hide},
    {"kill", app_kill},
    {"kill9", app_kill9},
    {"ishidden", app_ishidden},
    
    {NULL, NULL}
};

int luaopen_app(lua_State* L) {
    hydra_add_doc_group(L, "app", "Manipulate running applications.");
    hydra_add_doc_item(L, &doc_app_runningapps);
    hydra_add_doc_item(L, &doc_app_appforpid);
    hydra_add_doc_item(L, &doc_app_appsforbundleid);
    hydra_add_doc_item(L, &doc_app_allwindows);
    hydra_add_doc_item(L, &doc_app_activate);
    hydra_add_doc_item(L, &doc_app_title);
    hydra_add_doc_item(L, &doc_app_bundleid);
    hydra_add_doc_item(L, &doc_app_unhide);
    hydra_add_doc_item(L, &doc_app_hide);
    hydra_add_doc_item(L, &doc_app_kill);
    hydra_add_doc_item(L, &doc_app_kill9);
    hydra_add_doc_item(L, &doc_app_ishidden);
    
    luaL_newlib(L, applib);
    return 1;
}
