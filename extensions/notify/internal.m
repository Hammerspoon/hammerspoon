#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

// you hate us Apple, don't you
@interface PHNotificationDelegate : NSObject <NSUserNotificationCenterDelegate>
@property (copy) void(^callback)(NSString* tag);
@end

static PHNotificationDelegate* notify_delegate;

@implementation PHNotificationDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    self.callback([[notification userInfo] objectForKey:@"tag"]);
    [center removeDeliveredNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)__unused center shouldPresentNotification:(NSUserNotification *)__unused notification { return YES; }

@end


/// hs.notify.show(title, subtitle, text, tag)
/// Function
/// Show an Apple notification. Tag is a unique string that identifies this notification; any functions registered for the given tag will be called if the notification is clicked. None of the strings are optional, though they may each be blank.
static int notify_show(lua_State* L) {
    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.title = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    note.subtitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    note.informativeText = [NSString stringWithUTF8String: luaL_checkstring(L, 3)];
    note.userInfo = @{@"tag": [NSString stringWithUTF8String: luaL_checkstring(L, 4)]};
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
    
    return 0;
}

static int notify_setup(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int closure = luaL_ref(L, LUA_REGISTRYINDEX);
    
    notify_delegate = [[PHNotificationDelegate alloc] init];
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = notify_delegate;
    
    notify_delegate.callback = ^(NSString* tag) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, closure);
        lua_pushstring(L, [tag UTF8String]);
        lua_pcall(L, 1, 0, 0);
    };
    
    return 0;
}

/// hs.notify.withdraw_all()
/// Function
/// Withdraw all posted notifications.  This is called automatically during a reload to prevent crashes upon user activation of a notification, so you should seldom need to use this directly.
static int notify_gc(lua_State* L __unused) {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    return 0;
}

static const luaL_Reg notifylib[] = {
    {"show", notify_show},
    {"_setup", notify_setup},
    {"withdraw_all", notify_gc},
    {NULL, NULL}
};

int luaopen_hs_notify_internal(lua_State* L) {
    luaL_newlib(L, notifylib);
    return 1;
}
