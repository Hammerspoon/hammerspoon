#import "helpers.h"

// you hate us Apple, don't you
@interface PHNotificationDelegate : NSObject <NSUserNotificationCenterDelegate>
@property lua_State* L;
@property int notifyref;
@end

static PHNotificationDelegate* delegate;

@implementation PHNotificationDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    NSString* tag = [[notification userInfo] objectForKey:@"tag"];
    
    lua_State* L = self.L;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, delegate.notifyref);
    lua_getfield(L, -1, "_clicked");
    
    if (lua_isfunction(L, -1)) {
        lua_pushstring(L, [tag UTF8String]);
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
        lua_pop(L, 1);
    }
    else {
        lua_pop(L, 2);
    }
    
    [center removeDeliveredNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification { return YES; }

@end

static hydradoc doc_notify_show = {
    "notify", "show", "notify.show(title, subtitle, text, tag)",
    "Show an Apple notification. Tag is a unique string that identifies this notification, and will be passed to notify.clicked() if the notification is clicked. None of the strings are optional, though they may each be blank."
};

static int notify_show(lua_State* L) {
    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.title = [NSString stringWithUTF8String: lua_tostring(L, 1)];
    note.subtitle = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    note.informativeText = [NSString stringWithUTF8String: lua_tostring(L, 3)];
    note.userInfo = @{@"tag": [NSString stringWithUTF8String: lua_tostring(L, 4)]};
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
    
    return 0;
}

static const luaL_Reg notifylib[] = {
    {"show", notify_show},
    {NULL, NULL}
};

int luaopen_notify(lua_State* L) {
    hydra_add_doc_group(L, "notify", "Apple's built-in notifications system.");
    hydra_add_doc_item(L, &doc_notify_show);
    
    luaL_newlib(L, notifylib);
    
    delegate = [[PHNotificationDelegate alloc] init];
    delegate.L = L;
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = delegate;
    
    lua_pushvalue(L, -1);
    delegate.notifyref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    return 1;
}
