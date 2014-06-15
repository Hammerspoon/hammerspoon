#import "lua/lauxlib.h"

int window_gc(lua_State* L) {
    AXUIElementRef* winptr = lua_touserdata(L, 1);
    CFRelease(*winptr);
    return 0;
}

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

int app_get_windows(lua_State* L) {
    AXUIElementRef app = AXUIElementCreateApplication(lua_tonumber(L, 1));
    
    lua_newtable(L); // [{}]
    
    CFArrayRef _windows;
    AXError result = AXUIElementCopyAttributeValues(app, kAXWindowsAttribute, 0, 100, &_windows);
    if (result == kAXErrorSuccess) {
        for (NSInteger i = 0; i < CFArrayGetCount(_windows); i++) {
            // [{}, i]
            lua_pushnumber(L, i + 1);
            
            // [{}, i, ud]
            AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
            *winptr = CFArrayGetValueAtIndex(_windows, i);
            CFRetain(*winptr);
            
            // [{}, i, ud, md]
            if (luaL_newmetatable(L, "window")) {
                lua_pushcfunction(L, window_gc);
                lua_setfield(L, -2, "__gc");
            }
            lua_setmetatable(L, -2); // [{}, i, ud]
            
            lua_settable(L, -3); // [{}]
        }
        CFRelease(_windows);
    }
    
    CFRelease(app);
    
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



//- (NSArray*) allWindows {
//    NSMutableArray* windows = [NSMutableArray array];
//    
//    CFArrayRef _windows;
//    AXError result = AXUIElementCopyAttributeValues(self.app, kAXWindowsAttribute, 0, 100, &_windows);
//    if (result == kAXErrorSuccess) {
//        for (NSInteger i = 0; i < CFArrayGetCount(_windows); i++) {
//            AXUIElementRef win = CFArrayGetValueAtIndex(_windows, i);
//            
//            PHWindow* window = [[PHWindow alloc] initWithElement:win];
//            [windows addObject:window];
//        }
//        CFRelease(_windows);
//    }
//    
//    return windows;
//}
