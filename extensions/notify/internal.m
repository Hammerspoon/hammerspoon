#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

// Common Code

#define USERDATA_TAG    "hs.notify"

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

// static void* push_udhandler(lua_State* L, int x) {
//     lua_rawgeti(L, LUA_REGISTRYINDEX, x);
//     return lua_touserdata(L, -1);
// }

// Not so common code

static NSMutableIndexSet* notificationHandlers;

// // Hammerspoon's notification interface (from MJUserNotificationManager.h and MJUserNotificationUser.m)

@interface MJUserNotificationManager : NSObject
+ (MJUserNotificationManager*) sharedManager;
- (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler;
@end

@interface MJUserNotificationManager () <NSUserNotificationCenterDelegate>
@property NSMutableDictionary* callbacks;
@end

// // New Delegate for notifications

// // our delegate header

@interface ourNotificationManager : NSObject
+ (ourNotificationManager*) sharedManagerForLua:(lua_State*)L;
// - (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler;
- (void) sendNotification:(NSUserNotification*)note;
- (void) releaseNotification:(NSUserNotification*)note;
- (void *) withdrawNotification:(NSUserNotification*)note;
@end

// // our delegate code

@interface ourNotificationManager () <NSUserNotificationCenterDelegate>
@property (retain) NSMutableDictionary* activeCallbacks;
@property lua_State* L;
@end

static id <NSUserNotificationCenterDelegate>    old_delegate ;
static ourNotificationManager*                  sharedManager;

typedef struct _notification_t {
    bool    delivered;
    bool    autoWithdraw;
    bool    alwaysPresent;
    int     fn;
    void*   note;
    int     registryHandle;
} notification_t;

@implementation ourNotificationManager

+ (ourNotificationManager*) sharedManagerForLua:(lua_State*)L {
//NSLog(@"sharedManagerForLua") ;
//    static ourNotificationManager* sharedManager;
    if (!sharedManager) {
        sharedManager = [[ourNotificationManager alloc] init];
        sharedManager.ActiveCallbacks = [NSMutableDictionary dictionary];
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:sharedManager];
    }
    sharedManager.L = L;
    return sharedManager;
}

- (void) sendNotification:(NSUserNotification*)note {
//NSLog(@"sendNotification") ;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: note];
}

- (void) releaseNotification:(NSUserNotification*)note {
//NSLog(@"releaseNotification") ;
    NSNumber* value = [[note userInfo] objectForKey:@"handler"];
    if (value) {
        [self.activeCallbacks removeObjectForKey:[[note userInfo] objectForKey:@"handler"]];
        note.userInfo = @{};
    } else {
        NSLog(@"releaseNotification: no tagged handler -- already released?");
    }
}

- (void *) withdrawNotification:(NSUserNotification*)note {
//NSLog(@"withdrawNotification") ;

    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: note];
    return (__bridge_retained void *) [note copy] ;
//    [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification: note];
}

// Notification delivered to Notification Center
- (void)userNotificationCenter:(NSUserNotificationCenter __unused *)center
    didDeliverNotification:(NSUserNotification *)notification {
//NSLog(@"didDeliverNotification") ;
        NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
            [self.activeCallbacks setObject:@1 forKey:value];
//NSLog(@"uservalue = %@", value) ;
            int myHandle = [value intValue];
            lua_State* L = self.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
            notification_t* thisNote = lua_touserdata(L, -1);
            thisNote->note = nil ;
            thisNote->note = (__bridge_retained void *) [notification copy];
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
//NSLog(@"didActivateNotification") ;
        NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
            if ([self.activeCallbacks objectForKey:value]) {
                if (value) {
//NSLog(@"uservalue = %@", value) ;
                    int myHandle = [value intValue];
                    lua_State* L = self.L;
                    if (L && (lua_status(L) == LUA_OK)) {
                        lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
                        notification_t* thisNote = lua_touserdata(L, -1);
                        thisNote->note = nil ;
                        thisNote->note = (__bridge_retained void *) [notification copy];
                        if (thisNote->autoWithdraw) {
                            [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: notification];
                        }
                        if (thisNote) {
                            lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
                            lua_rawgeti(L, LUA_REGISTRYINDEX, thisNote->fn);
                            lua_pushvalue(L, -3);
                            if (lua_pcall(L, 1, 0, -3) != 0) {
                                NSLog(@"%s", lua_tostring(L, -1));
                                lua_getglobal(L, "hs"); lua_getfield(L, -1, "showerror"); lua_remove(L, -2);
                                lua_pushvalue(L, -2);
                                lua_pcall(L, 1, 0, 0);
                            }
                        } else {
                            NSLog(@"didActivateNotification: userdata NULL");
                        }
                    } else {
                        NSLog(@"undefined lua_State -- ours went away, didn't it?") ;
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
- (BOOL)userNotificationCenter:(NSUserNotificationCenter __unused *)center
    shouldPresentNotification:(NSUserNotification *)notification {
//NSLog(@"shouldPresentNotification") ;
        NSNumber* value = [[notification userInfo] objectForKey:@"handler"];
        if (value) {
//NSLog(@"uservalue = %@", value) ;
            int myHandle = [value intValue];
            lua_State* L = self.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, (int)myHandle);
            notification_t* thisNote = lua_touserdata(L, -1);
            thisNote->note = nil ;
            thisNote->note = (__bridge_retained void *) [notification copy];
            lua_pop(L,1);
            if (thisNote) {
                return thisNote->alwaysPresent;
            } else {
                NSLog(@"shouldPresentNotification: userdata NULL");
               return YES;
            }
        } else {
            NSLog(@"shouldPresentNotification: no tagged handler -- not ours?");
           return YES;
        }
    }
@end

// // End of new delegate code

static int notification_delegate_setup(lua_State* L) {
    // Get and store old (core app) delegate.  If it hasn't been setup yet, do so.
    old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    if (!old_delegate) {
        [MJUserNotificationManager sharedManager];
        old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    }
    // Create our delegate
    [ourNotificationManager sharedManagerForLua:L];

    if (!notificationHandlers) notificationHandlers = [NSMutableIndexSet indexSet];

    return 0;
}

// // Module Lua Interface // //

/// hs.notify.withdraw_all()
/// Function
/// Withdraw all notifications from Hammerspoon
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This will withdraw all notifications for Hammerspoon, including those not sent by us or that linger from previous loads of Hammerspoon.
static int notification_withdraw_all(lua_State* __unused L) {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    return 0;
}

// hs.notify._new(fn) -> notification
// Constructor
// Returns a new notification object with the specified information and the assigned callback function.
static int notification_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    notification_t* notification = lua_newuserdata(L, sizeof(notification_t)) ;
    memset(notification, 0, sizeof(notification_t)) ;

    lua_pushvalue(L, 1);
    notification->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    notification->delivered = NO;
    notification->alwaysPresent = YES;
    notification->autoWithdraw = YES;
    notification->registryHandle = store_udhandler(L, notificationHandlers, -1);

    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.userInfo           = @{@"handler": [NSNumber numberWithInt: notification->registryHandle]};

    notification->note = (__bridge_retained void *)note;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.notify:send() -> self
/// Method
/// Delivers the notification to the Notification Center.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * If a notification has been modified, then this will resend it, setting the delivered status again.
///  * You can invoke this multiple times if you wish to repeat the same notification.
static int notification_send(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    [[ourNotificationManager sharedManagerForLua:L] sendNotification:(__bridge_transfer NSUserNotification*)notification->note];
    return 1;
}

/// hs.notify:release() -> self
/// Method
/// Disables the callback function for a notification.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * This is automatically invoked during garbage collection and when Hammerspoon reloads its config 
static int notification_release(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    [[ourNotificationManager sharedManagerForLua:L] releaseNotification:(__bridge_transfer NSUserNotification*)notification->note];
    luaL_unref(L, LUA_REGISTRYINDEX, notification->fn);
    remove_udhandler(L, notificationHandlers, notification->registryHandle);
    return 1;
}

/// hs.notify:withdraw() -> self
/// Method
/// Withdraws a delivered notification from the Notification Center.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * If you modify a delivered note, even with `hs.notify:release()`, then it is no longer considered delivered and this method will do nothing.  To fully remove a notification, invoke this method and then invoke `hs.notify:release()`, not the other way around.
static int notification_withdraw(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1);
    notification->note = [[ourNotificationManager sharedManagerForLua:L] withdrawNotification:(__bridge_transfer NSUserNotification*)notification->note];
//    lua_pushcfunction(L, notification_release) ; lua_pushvalue(L,1); lua_call(L, 1, 1);
    return 1;
}

/// hs.notify:title([titleText]) -> string
/// Method
/// Set the title of a notification
///
/// Parameters:
///  * titleText - An optional string containing the title to be set on the notification object. This can be an empty string, but if `nil` is passed, the title will not be changed and the current title will be returned. The default value is "Notification".
///
/// Returns:
///  * A string containing the title of the notification
static int notification_title(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        ((__bridge NSUserNotification *) notification->note).title = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).title UTF8String]);
    return 1;
}

/// hs.notify:subtitle([subtitleText]) -> string
/// Method
/// Set the subtitle of a notification
///
/// Parameters:
///  * subtitleText - An optional string containing the subtitle to be set on the notification object. This can be an empty string. If `nil` is passed, any existing subtitle will be removed.
///
/// Returns:
///  * A string containing the subtitle of the notification
static int notification_subtitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).subtitle = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).subtitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).subtitle UTF8String]);
    return 1;
}

/// hs.notify:informativeText([informativeText]) -> string
/// Method
/// Set the informative text of a notification
///
/// Parameters:
///  * informativeText - An optional string containing the informative text to be set on the notification object. This can be an empty string. If `nil` is passed, any existing informative text will be removed.
///
/// Returns:
///  * A string containing the informative text of the notification
static int notification_informativeText(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).informativeText = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).informativeText = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).informativeText UTF8String]);
    return 1;
}

/// hs.notify:actionButtonTitle([buttonTitle]) -> string
/// Method
/// Set the title of a notification's action button
///
/// Parameters:
///  * buttonTitle - An optional string containing the title for the notification's action button
///
/// Returns:
///  * A string containing the title of the action button
static int notification_actionButtonTitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).actionButtonTitle UTF8String]);
    return 1;
}

/// hs.notify:otherButtonTitle([buttonTitle]) -> string
/// Method
/// Set the title of a notification's other button
///
/// Parameters:
///  * buttonTitle - An optional string containing the title for the notification's other button
///
/// Returns:
///  * A string containing the title of the other button
static int notification_otherButtonTitle(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).otherButtonTitle UTF8String]);
    return 1;
}

/// hs.notify:hasActionButton([hasButton]) -> bool
/// Method
/// Controls the presence of an action button in a notification
///
/// Parameters:
///  * hasButton - An optional boolean indicating whether an action button should be present
///
/// Returns:
///  * A boolean indicating whether an action button is present
static int notification_hasActionButton(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        ((__bridge NSUserNotification *) notification->note).hasActionButton = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).hasActionButton);
    return 1;
}

/// hs.notify:alwaysPresent([isAlwaysPresent]) -> bool
/// Method
/// Controls whether a notification should be presented, overriding Notification Center's decisions otherwise
///
/// Parameters:
///  * isAlwaysPresent - An optional boolean indicating whether the notification should override Notification Center's settings. Defaults to true
///
/// Returns:
///  * A boolean indicating whether the notification will override Notification Center's settings
///
/// Notes:
///  * This does not affect the return value of `hs.notify:presented()` -- that will still reflect the decision of the Notification Center
static int notification_alwaysPresent(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->alwaysPresent = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, notification->alwaysPresent);
    return 1;
}

/// hs.notify:autoWithdraw([shouldWithdraw]) -> bool
/// Method
/// Controls whether a notification should automatically withdraw once activated
///
/// Parameters:
///  * shouldWithdraw - An optional boolean indicating whether the notification should automatically withdraw. Defaults to true.
///
/// Returns:
///  * A boolean indicating whether the notification will automatically withdraw
static int notification_autoWithdraw(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        notification->autoWithdraw = lua_toboolean(L, 2);
    }
    lua_pushboolean(L, notification->autoWithdraw);
    return 1;
}

/// hs.notify:soundName([soundName]) -> string or nil
/// Method
/// Set the sound for a notification
///
/// Parameters:
///  * soundName - An optional string containing the name of a sound to play with the notification. If `nil`, no sound will be played. Defaults to `nil`
///
/// Returns:
///  * A string containing the name of the sound that will be played, or nil if no sound will be played
///
/// Notes:
///  * Sounds will first be matched against the names of system sounds. If no matches can be found, they will then be searched for in the following paths, in order:
///   * `~/Library/Sounds`
///   * `/Library/Sounds`
///   * `/Network/Sounds`
///   * `/System/Library/Sounds`
static int notification_soundName(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).soundName = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).soundName = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
    }
    lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).soundName UTF8String]);
    return 1;
}

/// hs.notify:presented() -> bool
/// Method
/// Returns whether Notification Center decided to display the notification
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether Notification Center decided to display the notification
///
/// Notes:
///  * A typical example of why Notification Center would choose not to display a notification would be if Hammerspoon is the currently focussed application. Others may include being attached to a projector, or the user having set Do Not Disturb
static int notification_presented(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).presented);
    return 1;
}

/// hs.notify:delivered() -> bool
/// Method
/// Returns whether the notification has been delivered to the Notification Center
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the notification has been delivered to Notification Center
static int notification_delivered(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, notification->delivered);
    return 1;
}

// hs.notify:remote() -> bool
// Method
// Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.
static int notification_remote(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).remote);
    return 1;
}

// hs.notify:activationType() -> number
// Method
// Returns whether the notification was generated by a push notification (remotely).  Currently unused, but perhaps not forever.
static int notification_activationType(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushnumber(L, ((__bridge NSUserNotification *) notification->note).activationType);
    return 1;
}

/// hs.notify:actualDeliveryDate() -> number
/// Method
/// Returns the date and time when a notification was delivered
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the delivery date/time of the notification, in seconds since the epoch (i.e. 1970-01-01 00:00:00 +0000)
///
/// Notes:
///  * You can turn epoch times into a useful table of date information with: `os.date("*t", epochTime)`
static int notification_actualDeliveryDate(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushnumber(L, [((__bridge NSUserNotification *) notification->note).actualDeliveryDate timeIntervalSince1970]);
    return 1;
}

// hs.notify.activationType[]
// Constant
// Convenience array of the possible activation types for a notification, and their reverse for reference.
// * None - The user has not interacted with the notification.
// * ContentsClicked - User clicked on notification
// * ActionButtonClicked - User clicked on Action button
static void notification_activationTypeTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSUserNotificationActivationTypeNone);
        lua_setfield(L, -2, "None") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeContentsClicked);
        lua_setfield(L, -2, "ContentsClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeActionButtonClicked);
        lua_setfield(L, -2, "ActionButtonClicked") ;
// /     Replied                     User used Reply button (10.9) (not implemented yet)
// /     AdditionalActionClicked     Additional Action selected (10.10) (not implemented yet)
//     lua_pushinteger(L, NSUserNotificationActivationTypeReplied);
//         lua_setfield(L, -2, "Replied") ;
//     lua_pushinteger(L, NSUserNotificationActivationTypeAdditionalActionClicked);
//         lua_setfield(L, -2, "AdditionalActionClicked") ;
    lua_pushstring(L, "None") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeNone);
    lua_pushstring(L, "ContentsClicked") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeContentsClicked);
    lua_pushstring(L, "ActionButtonClicked") ;
        lua_rawseti(L, -2, NSUserNotificationActivationTypeActionButtonClicked);
//     lua_pushstring(L, "Replied") ;
//         lua_rawseti(L, -2, NSUserNotificationActivationTypeReplied);
//     lua_pushstring(L, "AdditionalActionClicked") ;
//         lua_rawseti(L, -2, NSUserNotificationActivationTypeAdditionalActionClicked);
}

static int notification_gc(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, notification_release) ; lua_pushvalue(L,1); lua_call(L, 1, 1);
    notification->note = nil;
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [notificationHandlers removeAllIndexes];
    notificationHandlers = nil;

    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:(id <NSUserNotificationCenterDelegate>)old_delegate];
    sharedManager = nil;
    return 0;
}

// Everything so far is 10.8 compliant -- I list the 10.9 and 10.10 stuff in the labels above and
// below as a reminder to perhaps add a companion module later for those who can use them.

// Metatable for created objects when _new invoked
static const luaL_Reg notification_metalib[] = {                        // Notification Methods
    {"send",                        notification_send},                     // Send to notification center
    {"release",                     notification_release},                  // Leave in NC, but detach callback
    {"withdraw",                    notification_withdraw},                 // Remove from the notification center
    {"title",                       notification_title},                // Attribute Methods
    {"subTitle",                    notification_subtitle},
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

int luaopen_hs_notify_internal(lua_State* L) {
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
/// hs.notify.defaultNotificationSound
/// Constant
/// The string representation of the default notification sound. Use `hs.notify:soundName()` or set the `soundName` attribute in `hs:notify.new()`, to this constant, if you want to use the default sound
        lua_pushstring(L, [NSUserNotificationDefaultSoundName UTF8String]) ;
        lua_setfield(L, -2, "defaultNotificationSound") ;

        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
