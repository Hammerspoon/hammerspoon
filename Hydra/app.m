#import "lua/lauxlib.h"
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
        lua_getglobal(L, "hydra");
        lua_getfield(L, -1, "app");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1); // hydra-global
        
        lua_pushcfunction(L, app_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_setmetatable(L, -2);
}

// args: []
// ret: [apps]
int app_runningapps(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        new_app(L, [runningApp processIdentifier]);
        lua_rawseti(L, -2, i++);
    }
    
    return 1;
}

// args: []
// ret: []
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

// args: [app]
// ret: [bool]
int app_activate(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    BOOL success = [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    lua_pushboolean(L, success);
    return 1;
}

// args: [app]
// ret: [string]
int app_title(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

static void set_app_prop(AXUIElementRef app, NSString* propType, id value) {
    AXUIElementSetAttributeValue(app, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
    // yes, we ignore the return value; life is too short to constantly handle rare edge-cases
}

// args: [app]
// ret: []
int app_show(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @NO);
    CFRelease(app);
    return 0;
}

// args: [app]
// ret: []
int app_hide(lua_State* L) {
    lua_getfield(L, 1, "pid");
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, -1));
    
    set_app_prop(app, NSAccessibilityHiddenAttribute, @YES);
    CFRelease(app);
    return 0;
}

// args: [app]
// ret: []
int app_kill(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    [app terminate];
    return 0;
}

// args: [app]
// ret: []
int app_kill9(lua_State* L) {
    lua_getfield(L, 1, "pid");
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, -1)];
    
    [app forceTerminate];
    return 0;
}

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
    
    {"allwindows", app_allwindows},
    {"activate", app_activate},
    {"title", app_title},
    {"show", app_show},
    {"hide", app_hide},
    {"kill", app_kill},
    {"kill9", app_kill9},
    {"ishidden", app_ishidden},
    
    {NULL, NULL}
};

int luaopen_app(lua_State* L) {
    luaL_newlib(L, applib);
    return 1;
}
