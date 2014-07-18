#import "helpers.h"

/// === notify ===
///
/// Apple's built-in notifications system.

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

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification { return YES; }

@end


/// notify.show(title, subtitle, text, tag)
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
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

static const luaL_Reg notifylib[] = {
    {"show", notify_show},
    {"_setup", notify_setup},
    {NULL, NULL}
};

int luaopen_notify(lua_State* L) {
    luaL_newlib(L, notifylib);
    return 1;
}
