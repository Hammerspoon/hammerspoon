#import "lua/lauxlib.h"

static pid_t app_get_app_pid(lua_State* L) {
    lua_getfield(L, 1, "pid");
    pid_t pid = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return pid;
}

static NSRunningApplication* app_get_app(lua_State* L) {
    return [NSRunningApplication runningApplicationWithProcessIdentifier: app_get_app_pid(L)];
}

static int app_title(lua_State* L) {
    NSRunningApplication* app = app_get_app(L);
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

static int app_is_hidden(lua_State* L) {
    pid_t pid = app_get_app_pid(L);
    AXUIElementRef carbonapp = AXUIElementCreateApplication(pid); // TODO: put this in a field on self and give it a __gc
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(carbonapp, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    CFRelease(carbonapp); // TODO: move this into a __gc
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

static int app_running_apps(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        pid_t p = [runningApp processIdentifier];
        
        lua_pushnumber(L, i++);                 // [i]
        lua_newtable(L);                        // [i, {}]
        lua_pushnumber(L, p);                   // [i, {}, pid]
        lua_setfield(L, -2, "pid");             // [i, {}]
        lua_pushvalue(L, lua_upvalueindex(1));  // [i, {}, mt]
        lua_setmetatable(L, -2);                // [i, {}]
        lua_settable(L, -3);                    // []
    }
    
    return 1;
}

static const luaL_Reg applib[] = {
    {"title", app_title},
    {"is_hidden", app_is_hidden},
    {NULL, NULL}
};

int luaopen_app(lua_State * L) {
    lua_newtable(L);                           // [app]
    lua_newtable(L);                           // [app, {}]
    luaL_newlib(L, applib);                    // [app, {}, {...}]
    lua_setfield(L, -2, "__index");            // [app, {__index = {...}}]
    lua_pushcclosure(L, app_running_apps, 1);  // [app, running_apps]
    lua_setfield(L, -2, "running_apps");       // [app]
    
    return 1;
}
