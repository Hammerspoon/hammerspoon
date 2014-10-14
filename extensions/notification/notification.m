#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

//void NSLog(NSString* format, ...) {}

// Common Code

#define USERDATA_TAG    "hs.notification"

static int store_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [theHandler addIndex: x];
    return x;
}

static void remove_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [theHandler removeIndex: x];
}

static void* push_udhandler(lua_State* L, int x) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, x);
    return lua_touserdata(L, -1);
}

// Not so common code

static NSMutableIndexSet* notificationHandlers;

// Hammerspoon's notification interface

@interface MJUserNotificationManager : NSObject
+ (MJUserNotificationManager*) sharedManager;
- (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler;
@end

@interface MJUserNotificationManager () <NSUserNotificationCenterDelegate>
@property NSMutableDictionary* callbacks;
@end

// Delegate for notifications

@interface noteDelegate : NSObject <NSUserNotificationCenterDelegate>
+ (noteDelegate*) sharedManagerForLua:(lua_State*)L;
- (void) sendNotification:(NSUserNotification*)note;
- (void) releaseNotification:(NSUserNotification*)note;
- (void) withdrawNotification:(NSUserNotification*)note;

@property (retain) NSMutableDictionary* ActiveCallbacks;
@property lua_State* L;
@end

static noteDelegate*                            notification_delegate ;
static id <NSUserNotificationCenterDelegate>    old_delegate ;

typedef struct _notification_t {
    bool                delivered;
    bool                autoWithdraw;
    bool                alwaysPresent;
    int                 fn;
    NSUserNotification* note;
    int                 registryHandle;
} notification_t;

@implementation noteDelegate

+ (noteDelegate*) sharedManagerForLua:(lua_State*)L {
    static noteDelegate* sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[noteDelegate alloc] init];
        sharedManager.ActiveCallbacks = [[NSMutableDictionary dictionary] retain];
        sharedManager.L = L;
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:sharedManager];
    });
    return sharedManager;
}

- (void) sendNotification:(NSUserNotification*)note {
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: note];
}

- (void) releaseNotification:(NSUserNotification*)note {
    NSNumber* value = [[note userInfo] objectForKey:@"handler"];
    if (value) {
        [self.ActiveCallbacks removeObjectForKey:[[note userInfo] objectForKey:@"handler"]];
        note.userInfo = @{};
    } else {
        NSLog(@"releaseNotification: no tagged handler -- already released?");
    }
}

- (void) withdrawNotification:(NSUserNotification*)note {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: note];
//    [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification: note];
}

// Notification delivered to Notification Center
- (void)userNotificationCenter:(NSUserNotificationCenter *)center
    didDeliverNotification:(NSUserNotification *)notification {
        NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
            [self.ActiveCallbacks setObject:@1 forKey:value];
            int myHandle = [value intValue];
            lua_State* L = self.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
            notification_t* thisNote = lua_touserdata(L, -1);
            [thisNote->note release];
            thisNote->note = [notification copy];
            lua_pop(L,1);
            if (thisNote) {
                thisNote->delivered = YES;
            } else {
                NSLog(@"didDeliverNotification: userdata NULL");
            }
        } else {
            NSLog(@"didDeliverNotification: no tagged handler -- not ours?");
        }
    }

// User clicked on notification...
- (void)userNotificationCenter:(NSUserNotificationCenter *)center
    didActivateNotification:(NSUserNotification *)notification {
        NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
            if ([self.ActiveCallbacks objectForKey:value]) {
                if (value) {
                    int myHandle = [value intValue];
                    lua_State* L = self.L;
                    lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
                    notification_t* thisNote = lua_touserdata(L, -1);
                    [thisNote->note release];
                    thisNote->note = [notification copy];
                    if (thisNote->autoWithdraw) {
                        [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: notification];
                    }
//                    lua_pop(L,1);
                    if (thisNote) {
                        lua_rawgeti(L, LUA_REGISTRYINDEX, thisNote->fn);
                        lua_pushvalue(L, -2);
                        lua_call(L, 1, 0);
                    } else {
                        NSLog(@"didActivateNotification: userdata NULL");
                    }
                }
            } else {
                NSLog(@"didActivateNotification: handler not Active");
            }
        } else {
            NSLog(@"didActivateNotification: no tagged handler -- passing along");
            [old_delegate userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:notification];
        }
    }

// Should notification show, even if we're the foremost application?
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
    shouldPresentNotification:(NSUserNotification *)notification {
         NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
            [self.ActiveCallbacks setObject:@1 forKey:value];
            int myHandle = [value intValue];
            lua_State* L = self.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
            notification_t* thisNote = lua_touserdata(L, -1);
            [thisNote->note release];
            thisNote->note = [notification copy];
            lua_pop(L,1);
            if (thisNote) {
                return thisNote->alwaysPresent;
            } else {
                NSLog(@"didDeliverNotification: userdata NULL");
               return YES;
            }
        } else {
            NSLog(@"didDeliverNotification: no tagged handler -- not ours?");
           return YES;
        }
    }
@end

static int notification_delegate_setup(lua_State* L) {
    old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    if (!old_delegate) {
        [MJUserNotificationManager sharedManager];
        old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    }
    notification_delegate = [noteDelegate sharedManagerForLua:L];

    if (!notificationHandlers) notificationHandlers = [[NSMutableIndexSet indexSet] retain];

    return 0;
}

// End of delegate definition

/// hs.notification.withdraw_all()
/// Function
/// Withdraw all posted notifications for Hammerspoon.  Note that this will withdraw all notifications for Hammerspoon, including those not sent by us or that linger from previous loads of Hammerspoon.
static int notification_withdraw_all(lua_State* L) {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    return 0;
}

// hs.notification.new(fn) -> notification
// Constructor
// Returns a new notification object with the specified information and the assigned callback function.
static int notification_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    int theFunction = luaL_ref(L, LUA_REGISTRYINDEX);

    notification_t* notification = lua_newuserdata(L, sizeof(notification_t)) ;
    memset(notification, 0, sizeof(notification_t)) ;
    notification->delivered = NO;
    notification->alwaysPresent = YES;
    notification->autoWithdraw = YES;
    notification->fn        = theFunction ;
    notification->registryHandle = store_udhandler(L, notificationHandlers, -1);

    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.userInfo           = @{@"handler": [NSNumber numberWithInt: notification->registryHandle]};

    notification->note = (__bridge_retained NSUserNotification*)note;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.notification:send() -> self
/// Method
/// Delivers the notification to the Notification Center.  If a notification has been modified, then this will resend it, setting the delivered status again.  You can invoke this multiple times if you wish to repeat the same notification.
static int notification_send(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    [[noteDelegate sharedManagerForLua:L] sendNotification:(NSUserNotification*)notification->note];
    return 1;
}

/// hs.notification:release() -> self
/// Method
/// Disables the callback function for a notification.  Is also invoked during garbage collection (or a hs.reload()).
static int notification_release(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    [[noteDelegate sharedManagerForLua:L] releaseNotification:(NSUserNotification*)notification->note];
    luaL_unref(L, LUA_REGISTRYINDEX, notification->fn);
    remove_udhandler(L, notificationHandlers, notification->registryHandle);
    return 1;
}

/// hs.notification:withdraw() -> self
/// Method
/// Withdraws a delivered notification from the Notification Center.  Note that if you modify a delivered note, even with `release`, then it is no longer considered delivered and this method will do nothing.  If you want to fully remove a notification, invoke this method and then invoke `release`, not the other way around.
static int notification_withdraw(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    [[noteDelegate sharedManagerForLua:L] withdrawNotification:(NSUserNotification*)notification->note];
//    lua_pushcfunction(L, notification_release) ; lua_pushvalue(L,1); lua_call(L, 1, 1);
    return 1;
}

/// hs.notification:title([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's title to that value.  Returns current value for notification title. Can be blank, but not nil.  Defaults to "Notification".
static int notification_title(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->note.title = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    }
    lua_pushstring(L, [notification->note.title UTF8String]);
    return 1;
}

/// hs.notification:subtitle([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's subtitle to that value.  Returns current value for notification subtitle.
static int notification_subtitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            notification->note.subtitle = nil;
        } else {
            notification->note.subtitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [notification->note.subtitle UTF8String]);
    return 1;
}

/// hs.notification:informativeText([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's informativeText to that value.  Returns current value for notification informativeText.
static int notification_informativeText(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            notification->note.informativeText = nil;
        } else {
            notification->note.informativeText = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [notification->note.informativeText UTF8String]);
    return 1;
}

/// hs.notification:actionButtonTitle([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's action button title to that value.  Returns current value for notification action button title.
static int notification_actionButtonTitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            notification->note.actionButtonTitle = nil;
        } else {
            notification->note.actionButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [notification->note.actionButtonTitle UTF8String]);
    return 1;
}

/// hs.notification:otherButtonTitle([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's cancel button's title to that value.  Returns current value for notification cancel button title.
static int notification_otherButtonTitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            notification->note.otherButtonTitle = nil;
        } else {
            notification->note.otherButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [notification->note.otherButtonTitle UTF8String]);
    return 1;
}

/// hs.notification:hasActionButton([bool]) -> bool
/// Attribute
/// If a boolean argument is provided, first set whether or not the notification has an action button.  Returns current presence of notification action button. Defaults to true.
static int notification_hasActionButton(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->note.hasActionButton = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, notification->note.hasActionButton);
    return 1;
}

/// hs.notification:alwaysPresent([bool]) -> bool
/// Attribute
/// If a boolean argument is provided, determines whether or not the notification should be presented, even if the Notification Center's normal decision would be not to.  This does not affect the return value of the `presented` attribute -- that will still reflect the decision of the Notification Center. Returns the current status. Defaults to true.
static int notification_alwaysPresent(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->alwaysPresent = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, notification->alwaysPresent);
    return 1;
}

/// hs.notification:autoWithdraw([bool]) -> bool
/// Attribute
/// If a boolean argument is provided, sets whether or not a notification should be automatically withdrawn once activated. Returns the current status.  Defaults to true.
static int notification_autoWithdraw(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->autoWithdraw = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, notification->autoWithdraw);
    return 1;
}

/// hs.notification:soundName([string]) -> string
/// Attribute
/// If a string argument is provided, first set the notification's delivery sound to that value.  Returns current value for notification delivery sound.  If it's nil, no sound will be played.  Defaults to nil.
static int notification_soundName(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            notification->note.soundName = nil;
        } else {
            notification->note.soundName = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [notification->note.soundName UTF8String]);
    return 1;
}

/// hs.notification:presented() -> bool
/// Attribute
/// Returns whether the notification was presented by the decision of the Notification Center.  Under certain conditions (most notably if you're currently active in the application which sent the notification), the Notification Center can decide not to present a notification.  This flag represents that decision.
static int notification_presented(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, notification->note.presented);
    return 1;
}

/// hs.notification:delivered() -> bool
/// Attribute
/// Returns whether the notification has been delivered to the Notification Center.
static int notification_delivered(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, notification->delivered);
    return 1;
}

/// hs.notification:remote() -> bool
/// Attribute
/// Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.
static int notification_remote(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, notification->note.remote);
    return 1;
}

/// hs.notification:activationType() -> int
/// Attribute
/// Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.
static int notification_activationType(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushnumber(L, notification->note.activationType);
    return 1;
}

/// hs.notification:actualDeliveryDate() -> int
/// Attribute
/// Returns the delivery date of the notification in seconds since 1970-01-01 00:00:00 +0000 (e.g. `os.time()`).
static int notification_actualDeliveryDate(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushnumber(L, [notification->note.actualDeliveryDate timeIntervalSince1970]);
    return 1;
}

/// hs.notification.activationType[]
/// Variable
/// Convenience array of the possible activation types for a notification, and their reverse for reference.
/// ~~~lua
///     None                        The user has not interacted with the notification.
///     ContentsClicked             User clicked on notification
///     ActionButtonClicked         User clicked on Action button
///     Replied                     User used Reply button (10.9) (not implemented yet)
///     AdditionalActionClicked     Additional Action selected (10.10) (not implemented yet)
/// ~~~
static void notification_activationTypeTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSUserNotificationActivationTypeNone);
        lua_setfield(L, -2, "None") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeContentsClicked);
        lua_setfield(L, -2, "ContentsClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeActionButtonClicked);
        lua_setfield(L, -2, "ActionButtonClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeReplied);
        lua_setfield(L, -2, "Replied") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeAdditionalActionClicked);
        lua_setfield(L, -2, "AdditionalActionClicked") ;
    lua_pushstring(L, "None") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeNone);
    lua_pushstring(L, "ContentsClicked") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeContentsClicked);
    lua_pushstring(L, "ActionButtonClicked") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeActionButtonClicked);
    lua_pushstring(L, "Replied") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeReplied);
    lua_pushstring(L, "AdditionalActionClicked") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeAdditionalActionClicked);
}

static int notification_gc(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, notification_release) ; lua_pushvalue(L,1); lua_call(L, 1, 1);
    [notification->note release];
    return 0;
}

static int meta_gc(lua_State* L) {
    [notificationHandlers release];
    notificationHandlers = nil;

    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:(id <NSUserNotificationCenterDelegate>)old_delegate];
    [notification_delegate release];
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg notification_metalib[] = {                        // Notification Methods
    {"send",                        notification_send},                     // Send to notification center
    {"release",                     notification_release},                  // Leave in NC, but detach callback
    {"withdraw",                    notification_withdraw},                 // Remove from the notification center
    {"title",                       notification_title},                // Attribute Methods
    {"subtitle",                    notification_subtitle},
    {"informativeText",             notification_informativeText},
    {"actionButtonTitle",           notification_actionButtonTitle},
    {"otherButtonTitle",            notification_otherButtonTitle},
    {"hasActionButton",             notification_hasActionButton},
    {"soundName",                   notification_soundName},
    {"alwaysPresent",               notification_alwaysPresent},
    {"autoWithdraw",                notification_autoWithdraw},
//    {"deliveryDate",                notification_deliveryDate},             // requires scheduleNotification
//    {"deliveryRepeatInterval",      notification_deliveryRepeatInterval},   // requires scheduleNotification
//    {"deliveryTimeZone",            notification_deliveryTimeZone},         // requires scheduleNotification
//    {"identifier",                  NULL},                                  // 10.9
//    {"contentImage",                NULL},                                  // 10.9
//    {"responsePlaceholder",         NULL},                                  // 10.9
//    {"hasReplyButton",              NULL},                                  // 10.9
//    {"additionalActions",           NULL},                                  // 10.10
    {"presented",                   notification_presented},            // Result methods
    {"delivered",                   notification_delivered},
    {"remote",                      notification_remote},
    {"activationType",              notification_activationType},
    {"actualDeliveryDate",          notification_actualDeliveryDate},
//    {"response",                    NULL},                                  // 10.9
//    {"additionalActivationAction",  NULL},                                  // 10.10
    {"__gc",                        notification_gc},                   // GC: basically release, so it stays in NC
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static const luaL_Reg notificationLib[] = {
    {"_new",            notification_new},
    {"withdraw_all",    notification_withdraw_all},
    {NULL,              NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_notification_internal(lua_State* L) {
    notification_delegate_setup(L);

// Metatable for created objects
    luaL_newlib(L, notification_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, notificationLib);
        notification_activationTypeTable(L) ;
        lua_setfield(L, -2, "activationType") ;
/// hs.notification.defaultNotificationSound
/// Variable
/// The string representation of the default notification sound.  Set `soundName` attribute to this if you want to use the default sound.
        lua_pushstring(L, [NSUserNotificationDefaultSoundName UTF8String]) ;
        lua_setfield(L, -2, "defaultNotificationSound") ;

        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}

// n = rq("ui.notification") ; f = function(obj) print(obj:presented(), obj:remote(), os.date("%c",obj:actualDeliveryDate()), n.activationType[obj:activationType()]) end ; a = n.new(f)
