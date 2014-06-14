#import "lua/lauxlib.h"

// stack: [table]
static pid_t app_get_app_pid(lua_State* L) {
    lua_getfield(L, -1, "pid");
    pid_t pid = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return pid;
}

// stack: [table]
static AXUIElementRef app_get_app_carbonapp(lua_State* L) {
    lua_getfield(L, -1, "_carbonapp");
    AXUIElementRef* ud = lua_touserdata(L, -1);
    lua_pop(L, 2);
    return *ud;
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
    AXUIElementRef carbonapp = app_get_app_carbonapp(L);
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(carbonapp, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}

static int app_gc(lua_State* L) {
    AXUIElementRef* ud = lua_touserdata(L, 1);
    AXUIElementRef app = *ud;
    CFRelease(app);
    return 0;
}

static int app_running_apps(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        pid_t p = [runningApp processIdentifier];
        AXUIElementRef carbonapp = AXUIElementCreateApplication(p);
        
        lua_pushnumber(L, i++);                                           // [apps, i]
        lua_newtable(L);                                                  // [apps, i, {}]
        
        lua_pushnumber(L, p);                                             // [apps, i, {}, pid]
        lua_setfield(L, -2, "pid");                                       // [apps, i, {}]
        
        AXUIElementRef* ud = lua_newuserdata(L, sizeof(AXUIElementRef));  // [apps, i, {}, userdata]
        *ud = carbonapp;                                                  // [apps, i, {}, userdata]
        lua_pushvalue(L, lua_upvalueindex(2));                            // [apps, i, {}, userdata, userdata_mt]
        
        lua_setmetatable(L, -2);                                          // [apps, i, {}, userdata]
        lua_setfield(L, -2, "_carbonapp");                                // [apps, i, {}]
        
        lua_pushvalue(L, lua_upvalueindex(1));                            // [apps, i, {}, mt]
        lua_setmetatable(L, -2);                                          // [apps, i, {}]
        
        lua_settable(L, -3);                                              // [apps]
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
    luaL_newlib(L, applib);                    // [app, {}, {..app..}]
    lua_setfield(L, -2, "__index");            // [app, {__index = {..app..}}]
    lua_newtable(L);                           // [app, {__index = {..app..}}, {}]
    lua_pushcfunction(L, app_gc);              // [app, {__index = {..app..}}, {}, gc}
    lua_setfield(L, -2, "__gc");               // [app, {__index = {..app..}}, {__gc = gc}]
    lua_pushcclosure(L, app_running_apps, 2);  // [app, running_apps]
    lua_setfield(L, -2, "running_apps");       // [app]
    
    return 1;
}
