#import "helpers.h"
void new_window(lua_State* L, AXUIElementRef win);

#define hydra_app(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "application"))

static NSRunningApplication* nsobject_for_app(lua_State* L, int idx) {
    hydra_app(L, idx); // for type checking
    luaL_getmetafield(L, idx, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    lua_pop(L, 1);
    return app;
}

static int application_eq(lua_State* L) {
    hydra_app(L, 1); // for type checking
    hydra_app(L, 2); // for type checking
    
    luaL_getmetafield(L, 1, "pid");
    luaL_getmetafield(L, 2, "pid");
    
    BOOL equal = (lua_tonumber(L, -1) == lua_tonumber(L, -2));
    lua_pushboolean(L, equal);
    return 1;
}

void new_application(lua_State* L, pid_t pid) {
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    
    AXUIElementRef* appptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *appptr = app;
    
    luaL_getmetatable(L, "application");
    
    lua_pushnumber(L, pid);
    lua_setfield(L, -2, "pid");
    
    lua_setmetatable(L, -2);
}

static hydradoc doc_application_runningapplications = {
    "application", "runningapplications", "application.runningapplications() -> app[]",
    "Returns all running apps."
};

static int application_runningapplications(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        new_application(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

static hydradoc doc_application_applicationforpid = {
    "application", "applicationforpid", "application.applicationforpid(pid) -> app or nil",
    "Returns the running app for the given pid, if it exists."
};

static int application_applicationforpid(lua_State* L) {
    pid_t pid = luaL_checknumber(L, 1);
    
    NSRunningApplication* runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    
    if (runningApp)
        new_application(L, [runningApp processIdentifier]);
    else
        lua_pushnil(L);
    
    return 1;
}

static hydradoc doc_application_applicationsforbundleid = {
    "application", "applicationsforbundleid", "application.applicationsforbundleid(bundleid) -> app[]",
    "Returns any running apps that have the given bundleid."
};

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

static hydradoc doc_application_allwindows = {
    "application", "allwindows", "application:allwindows() -> window[]",
    "Returns all open windows owned by the given app."
};

static int application_allwindows(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
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

static hydradoc doc_application_activate = {
    "application", "activate", "application:activate([allwindows]) -> bool",
    "Tries to activate the app (make it focused) and returns its success; if optional arg allwindows is true, brings all the app's windows to front."
};

static int application_activate(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    BOOL allwindows = lua_toboolean(L, 2);
    
    NSApplicationActivationOptions opts = NSApplicationActivateIgnoringOtherApps;
    if (allwindows)
        opts |= NSApplicationActivateAllWindows;
    
    BOOL success = [app activateWithOptions:opts];
    
    lua_pushboolean(L, success);
    return 1;
}

static hydradoc doc_application_title = {
    "application", "title", "application:title() -> string",
    "Returns the localized name of the app (in UTF8)."
};

static int application_title(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

static hydradoc doc_application_bundleid = {
    "application", "bundleid", "application:bundleid() -> string",
    "Returns the bundle identifier of the app."
};

static int application_bundleid(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    lua_pushstring(L, [[app bundleIdentifier] UTF8String]);
    return 1;
}

static void set_app_prop(AXUIElementRef app, NSString* propType, id value) {
    AXUIElementSetAttributeValue(app, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
    // yes, we ignore the return value; life is too short to constantly handle rare edge-cases
}

static hydradoc doc_application_unhide = {
    "application", "unhide", "application:unhide()",
    "Unhides the app (and all its windows) if it's hidden."
};

static int application_unhide(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @NO);
    CFRelease(app);
    return 0;
}

static hydradoc doc_application_hide = {
    "application", "hide", "application:hide()",
    "Hides the app (and all its windows)."
};

static int application_hide(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @YES);
    CFRelease(app);
    return 0;
}

static hydradoc doc_application_kill = {
    "application", "kill", "application:kill()",
    "Tries to terminate the app."
};

static int application_kill(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    [app terminate];
    return 0;
}

static hydradoc doc_application_kill9 = {
    "application", "kill9", "application:kill9()",
    "Assuredly terminates the app."
};

static int application_kill9(lua_State* L) {
    NSRunningApplication* app = nsobject_for_app(L, 1);
    
    [app forceTerminate];
    return 0;
}

static hydradoc doc_application_ishidden = {
    "application", "ishidden", "application:ishidden() -> bool",
    "Returns whether the app is currently hidden."
};

static int application_ishidden(lua_State* L) {
    AXUIElementRef app = hydra_app(L, 1);
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    CFRelease(app);
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

static hydradoc doc_application_pid = {
    "application", "pid", "application:pid() -> number",
    "Returns the app's process identifier."
};

static int application_pid(lua_State* L) {
    hydra_app(L, 1); // type checking
    luaL_getmetafield(L, 1, "pid");
    return 1;
}

static const luaL_Reg applicationlib[] = {
    {"runningapplications", application_runningapplications},
    {"applicationforpid", application_applicationforpid},
    {"applicationsforbundleid", application_applicationsforbundleid},
    
    {"allwindows", application_allwindows},
    {"activate", application_activate},
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
    hydra_add_doc_group(L, "application", "Manipulate running applications.");
    hydra_add_doc_item(L, &doc_application_runningapplications);
    hydra_add_doc_item(L, &doc_application_applicationforpid);
    hydra_add_doc_item(L, &doc_application_applicationsforbundleid);
    hydra_add_doc_item(L, &doc_application_allwindows);
    hydra_add_doc_item(L, &doc_application_activate);
    hydra_add_doc_item(L, &doc_application_title);
    hydra_add_doc_item(L, &doc_application_bundleid);
    hydra_add_doc_item(L, &doc_application_unhide);
    hydra_add_doc_item(L, &doc_application_hide);
    hydra_add_doc_item(L, &doc_application_kill);
    hydra_add_doc_item(L, &doc_application_kill9);
    hydra_add_doc_item(L, &doc_application_ishidden);
    hydra_add_doc_item(L, &doc_application_pid);
    
    luaL_newlib(L, applicationlib);
    
    if (luaL_newmetatable(L, "application")) {
        lua_pushvalue(L, -2); // 'application' table
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, application_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
