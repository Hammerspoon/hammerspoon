#import "lua/lauxlib.h"

int app_running_apps(lua_State* L) {
    lua_newtable(L);
    int i = 1;
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        pid_t p = [runningApp processIdentifier];
        lua_pushnumber(L, i++);  // [apps, i]
        lua_pushnumber(L, p);    // [apps, i, pid]
        lua_settable(L, -3);     // [apps]
    }
    
    return 1;
}

int app_title(lua_State* L) {
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, 1)];
    lua_pushstring(L, [[app localizedName] UTF8String]);
    return 1;
}

void SDSetAppProperty(AXUIElementRef app, NSString* propType, id value) {
    AXUIElementSetAttributeValue(app, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
    // yes, we ignore the return value; life is too short to constantly handle rare edge-cases
}

int app_show(lua_State* L) {
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, 1));
    SDSetAppProperty(app, NSAccessibilityHiddenAttribute, @NO);
    CFRelease(app);
    return 0;
}

int app_hide(lua_State* L) {
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, 1));
    SDSetAppProperty(app, NSAccessibilityHiddenAttribute, @YES);
    CFRelease(app);
    return 0;
}

int app_kill(lua_State* L) {
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, 1)];
    [app terminate];
    return 0;
}

int app_kill9(lua_State* L) {
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: lua_tonumber(L, 1)];
    [app forceTerminate];
    return 0;
}

int app_is_hidden(lua_State* L) {
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, 1));
    
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    
    CFRelease(app);
    
    lua_pushboolean(L, [isHidden boolValue]);
    return 1;
}
