#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
// #import "objectconversion.h"

#define USERDATA_TAG    "hs.notify"
int refTable;

// NOTE: Hammerspoon's internal notification delegate (from MJUserNotificationManager.h and MJUserNotificationUser.m)

@interface MJUserNotificationManager : NSObject
+ (MJUserNotificationManager*) sharedManager;
- (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler;
@end

@interface MJUserNotificationManager () <NSUserNotificationCenterDelegate>
@property NSMutableDictionary* callbacks;
@end

// NOTE: Our internals and replacement delegate

@interface ourNotificationManager : NSObject
+ (ourNotificationManager*) sharedManager;
@end

@interface ourNotificationManager () <NSUserNotificationCenterDelegate>
@end

static id <NSUserNotificationCenterDelegate>    old_delegate ;
// static ourNotificationManager*                  sharedManager;

typedef struct _notification_t {
    BOOL    locked ;      // flag to indicate if changes should no longer be allowed (it's been sent)
    BOOL    delivered ;   // flag to indicate if notification has been delivered to the User Notification Center
    void*   note ;        // user notification object itself
    void*   gus ;         // globally unique identifier for use when verifying/recreating userdata
} notification_t ;

// #define USERDATA_TAG        "hs.module"
int refTable ;

@implementation ourNotificationManager

+ (instancetype) sharedManager {
    static ourNotificationManager* sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[ourNotificationManager alloc] init];
    });
    return sharedManager;
}

// Checks to see if userdata exists and is appropriate type at location referenced in userInfo
// dictionary and creates it if it doesn't exist -- this is necessary for notifications which
// are delivered or activated after Hammerspoon has been reloaded.
//
// Need to add unique identifier in notification_t and userInfo dict to verify correct matchup
// after reload.

- (notification_t *)getOrCreateUserdata:(NSUserNotification *)notification {
    LuaSkin *skin = [LuaSkin shared];
    NSMutableDictionary *noteInfoDict = [notification.userInfo mutableCopy];
    BOOL rebuild = NO ;

    int myHandle = [[noteInfoDict valueForKey:@"userdata"] intValue] ;
    notification_t *thisNote = NULL ;

    [skin pushLuaRef:refTable ref:myHandle];

    if (lua_type(skin.L, -1) == LUA_TUSERDATA && luaL_testudata(skin.L, -1, USERDATA_TAG)) {
        thisNote = lua_touserdata(skin.L, -1);
        if ([[noteInfoDict valueForKey:@"gus"] isEqualToString:(__bridge NSString *)thisNote->gus]) {

            // Because the notification object changes behind the scenes, we need to clear the userdata's
            // cached version and replace it with the current one at the end.
            NSUserNotification *tmpHolder = (__bridge_transfer NSUserNotification *) thisNote->note ;
            tmpHolder = nil ;
        } else {
            rebuild = YES ;
        }
    } else {
        rebuild = YES ;
    }

    if (rebuild) {
        [skin logBreadcrumb:@"hs.notify: creating new userdata for orphaned notification"] ;
    // If notification userdata does not exist, then we've been reloaded
    // and the reference is bad.  Make a new one.
        thisNote = lua_newuserdata(skin.L, sizeof(notification_t)) ;
        memset(thisNote, 0, sizeof(notification_t)) ;
        luaL_getmetatable(skin.L, USERDATA_TAG);
        lua_setmetatable(skin.L, -2);
    // this function is only called for an orphaned notification, so it's safe to assume it's
    // either being delivered or activated right now (i.e. previously delivered)
        thisNote->delivered = YES;
        thisNote->locked    = YES ;
        thisNote->gus       = (__bridge_retained void *)[noteInfoDict valueForKey:@"gus"] ;

        [noteInfoDict setValue:[NSNumber numberWithInt:[skin luaRef:refTable]]
                        forKey:@"userdata"];
        notification.userInfo = noteInfoDict ;
    }

    lua_pop(skin.L, 1) ;  // Clear the stack of our userdata, retrieved or new

    thisNote->note = (__bridge_retained void *) notification;
    return thisNote ;
}

// + (ourNotificationManager*) sharedManager {
//         if (!sharedManager) {
//             sharedManager = [[ourNotificationManager alloc] init];
//             [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:sharedManager];
//         }
//         return sharedManager;
//     }

// Notification delivered to Notification Center
- (void)userNotificationCenter:(NSUserNotificationCenter __unused *)center
        didDeliverNotification:(NSUserNotification *)notification {

    // NSlog(@"in didDeliverNotification") ;

        NSString *fnTag = [notification.userInfo valueForKey:@"tag"] ;

        if (fnTag) {
            notification_t *thisNote = [self getOrCreateUserdata:notification] ;  // necessary in case of reload
            thisNote->delivered = YES ;
        } // not one of ours, and MJUserNotificationManager doesn't use this, so do nothing else
    }

// User clicked on notification...
- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {

    // NSLog(@"in didActivateNotification") ;

        NSString *fnTag = [notification.userInfo valueForKey:@"tag"] ;

        if (fnTag) {
            LuaSkin *skin = [LuaSkin shared];

        // maybe a little more overhead than just assuming its there and putting logic in init.lua to
        // make sure hs.notify is in the right place, but this is more portable and doesn't rely on
        // assumptions.  And luaL_requiref requires knowing the open function name...
            lua_getglobal(skin.L, "require") ;
            lua_pushstring(skin.L, "hs.notify") ;
            if (![skin protectedCallAndTraceback:1 nresults:1]) {
                const char *errorMsg = lua_tostring(skin.L, -1);
                [skin logError:[NSString stringWithFormat:@"Unable to require('hs.notify'): %s", errorMsg]];
                return;
            }
            lua_getfield(skin.L, -1, "_tag_handler") ;
        // now we know the function hs.notify._tag_handler is on the stack...

            lua_pushstring(skin.L, [fnTag UTF8String]) ;

            notification_t __unused *thisNote = [self getOrCreateUserdata:notification] ; // necessary in case of reload
            [skin pushLuaRef:refTable ref:[[notification.userInfo valueForKey:@"userdata"] intValue]];

    // NSLog(@"invoking callback handler") ;

            if(![skin protectedCallAndTraceback:2 nresults:0]) {
                const char *errorMsg = lua_tostring(skin.L, -1);
                [skin logError:[NSString stringWithFormat:@"hs.notify callback error: %s", errorMsg]];
                return;
            }

            BOOL shouldWithdraw = [[notification.userInfo valueForKey:@"autoWithdraw"] boolValue] ;
            if (notification.deliveryRepeatInterval != nil) shouldWithdraw = YES ;

            if (shouldWithdraw) {
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification:notification];
            }
        } else {
    // NSLog(@"hs.notify passing off to original handler") ;
            [old_delegate userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:notification];
        }
    }

// Should notification show, even if we're the foremost application?
- (BOOL)userNotificationCenter:(NSUserNotificationCenter __unused *)center
     shouldPresentNotification:(NSUserNotification *)notification {

    // NSLog(@"in shouldPresentNotification") ;

        NSNumber *shouldPresent = [notification.userInfo valueForKey:@"alwaysPresent"] ;
        if (shouldPresent != nil) {
            notification_t __unused *thisNote = [self getOrCreateUserdata:notification] ; // necessary in case of reload
            return (BOOL)[shouldPresent boolValue] ;
        } else // MJNotificationManager just returns YES, so this is simpler.
            return YES ;
    }

@end

// NOTE: hs.notify functions that interface with Lua

static int notification_withdraw_all(lua_State* __unused L) {
/// hs.notify.withdrawAll()
/// Function
/// Withdraw all delivered notifications from Hammerspoon
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This will withdraw all notifications for Hammerspoon, including those not sent by this module or that linger from a previous load of Hammerspoon.
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    return 0;
}

static int notification_withdraw_allScheduled(lua_State* __unused L) {
/// hs.notify.withdrawAllScheduled()
/// Function
/// Withdraw all scheduled notifications from Hammerspoon
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
    ([NSUserNotificationCenter defaultUserNotificationCenter]).scheduledNotifications = @[];
    return 0;
}

static int notification_new(lua_State* L) {
// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
// hs.notify._new(fntag) -> notificationObject
// Constructor
// Returns a new notification object with the specified information and the assigned callback function.
    LuaSkin *skin  = [LuaSkin shared];
    NSString *myID = [[NSProcessInfo processInfo] globallyUniqueString] ;

    NSMutableDictionary *noteInfoDict = [@{
                              @"autoWithdraw": @(YES),
                              @"alwaysPresent":@(YES),
                              @"gus":          myID,
//                            @"tag":          see below,
//                            @"userdata":     see below,
    } mutableCopy];

    notification_t* notification = lua_newuserdata(L, sizeof(notification_t)) ;
    memset(notification, 0, sizeof(notification_t)) ;

    [noteInfoDict setValue:[NSString stringWithUTF8String:luaL_checkstring(L, 1)]
                     forKey:@"tag"] ;
    lua_pushvalue(L, -1) ;
    [noteInfoDict setValue:[NSNumber numberWithInt:[skin luaRef:refTable]]
                     forKey:@"userdata"];

    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.userInfo            = noteInfoDict ;

    notification->delivered = NO ;
    notification->locked    = NO ;

    notification->note = (__bridge_retained void *)note;
    notification->gus  = (__bridge_retained void *)myID;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

static int notification_send(lua_State* L) {
/// hs.notify:send() -> notificationObject
/// Method
/// Delivers the notification immediately to the users Notification Center.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * See also hs.notify:schedule()
///  * If a notification has been modified, then this will resend it.
///  * You can invoke this multiple times if you wish to repeat the same notification.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    notification->locked = YES ;
    lua_settop(L,1);
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:(__bridge NSUserNotification*)notification->note];
    return 1;
}

static NSDate* date_from_string(NSString* dateString) {
    // rfc3339 (Internet Date/Time) formated date.  More or less.
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSDate *date = [rfc3339DateFormatter dateFromString:dateString];
    return date;
}

static int notification_scheduleNotification(lua_State* L) {
/// hs.notify:schedule(date) -> notificationObject
/// Method
/// Schedules a notification for delivery in the future.
///
/// Parameters:
///  * date - the date the notification should be delivered to the users Notification Center specified as the number of seconds since 1970-01-01 00:00:00Z or as a string in rfc3339 format: "YYYY-MM-DD[T]HH:MM:SS[Z]".
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * See also hs.notify:send()
///  * hs.settings.dateFormat specifies a lua format string which can be used with `os.date()` to properly present the date and time as a string for use with this method.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    NSDate* myDate = lua_isnumber(L, 2) ? [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval) lua_tonumber(L,2)] :
                     lua_isstring(L, 2) ? date_from_string([NSString stringWithUTF8String:lua_tostring(L, 2)]) : nil ;
    if (myDate) {
        ((__bridge NSUserNotification *) notification->note).deliveryDate = myDate ;
    } else {
        return luaL_error(L, "-- hs.notify:schedule: improper date specified: must be a number (# of seconds since 1970-01-01 00:00:00Z) or string in the format of 'YYYY-MM-DD[T]HH:MM:SS[Z]' (rfc3339)") ;
    }

    notification->locked    = YES ;
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:(__bridge NSUserNotification*)notification->note];

    lua_settop(L,1);
    return 1;
}

// Too easy to create runaway repeaters that persist through reboots.  Default Hammerspoon delegate and this one would stop it if
// activated (user clicks on it) but only if Hammerspoon is available and running.  Also possible to "recapture" userdata in a callback
// by swapping it out after a reload of Hammerspoon and using that to withdraw, but that's more complex then I want to describe in
// the core docs.  Better to put this into an external module so only those who really want it have to deal with the possible messes.
//
// static int notification_deliveryRepeatInterval(lua_State* L) {
// /// hs.notify:repeatInterval([seconds]) -> notificationObject | current-setting
// /// Method
// /// Get or set the repeat interval for a notification which is to be scheduled.
// ///
// /// Parameters:
// ///  * seconds - An optional number specifying how often in seconds the scheduled notification should repeat.  If no parameter is provided, then the current setting is returned.
// ///
// /// Returns:
// ///  * The notification object, if seconds is present; otherwise the current setting.
// ///
// /// Notes:
// ///  * For a notification to be repeated, it must be delivered by `hs.notify:schedule()`.  If you use `hs.notify:send()`, this setting is ignored.
// ///  * A repeating notification will autoWithdraw when activated. Setting this to anything but 0 will cause the notification to ignore `hs.notify:autoWithdraw()`.
// ///  * The interval must be at least 60 seconds (1 minute).
// ///  * Specify an interval of 0 if the notification should not repeat.
//     notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
//     if (lua_isnone(L, 2)) {
//         NSDateComponents *interval = ((__bridge NSUserNotification *) notification->note).deliveryRepeatInterval ;
//         lua_pushinteger(L, interval.second) ;
//    } else if (!notification->locked) {
//         luaL_checktype(L, 2, LUA_TNUMBER) ;
//         lua_Integer seconds = lua_tointeger(L, 2) ;
//         if (seconds == 0) {
//             ((__bridge NSUserNotification *) notification->note).deliveryRepeatInterval = nil ;
//         } else if (seconds < 60) {
//             return luaL_error(L, "notification repeat interval must be 60 seconds or greater") ;
//         } else {
//             NSDateComponents *interval = [[NSDateComponents alloc] init];
//             [interval setSecond:seconds];
//             ((__bridge NSUserNotification *) notification->note).deliveryRepeatInterval = interval ;
//         }
//         notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
//         lua_settop(L, 1) ;
//     } else {
//         return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
//     }
//     return 1;
// }

static int notification_withdraw(lua_State* L) {
/// hs.notify:withdraw() -> notificationObject
/// Method
/// Withdraws a delivered notification from the Notification Center.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: (__bridge NSUserNotification*)notification->note];
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification: (__bridge NSUserNotification*)notification->note];
    notification->locked    = NO ;

    lua_settop(L, 1) ;
    return 1;
}

static int notification_title(lua_State* L) {
/// hs.notify:title([titleText]) -> notificationObject | current-setting
/// Method
/// Get or set the title of a notification
///
/// Parameters:
///  * titleText - An optional string containing the title to be set on the notification object.  The default value is "Notification".  If `nil` is passed, then the title is set to the empty string.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if titleText is present; otherwise the current setting.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L,2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).title UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).title = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).title = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_subtitle(lua_State* L) {
/// hs.notify:subTitle([subtitleText]) -> notificationObject | current-setting
/// Method
/// Get or set the subtitle of a notification
///
/// Parameters:
///  * subtitleText - An optional string containing the subtitle to be set on the notification object. This can be an empty string. If `nil` is passed, any existing subtitle will be removed.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if subtitleText is present; otherwise the current setting.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).subtitle UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).subtitle = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).subtitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_informativeText(lua_State* L) {
/// hs.notify:informativeText([informativeText]) -> notificationObject | current-setting
/// Method
/// Get or set the informative text of a notification
///
/// Parameters:
///  * informativeText - An optional string containing the informative text to be set on the notification object. This can be an empty string. If `nil` is passed, any existing informative text will be removed.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if informativeText is present; otherwise the current setting.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).informativeText UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).informativeText = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).informativeText = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_actionButtonTitle(lua_State* L) {
/// hs.notify:actionButtonTitle([buttonTitle]) -> notificationObject | current-setting
/// Method
/// Get or set the label of a notification's action button
///
/// Parameters:
///  * buttonTitle - An optional string containing the title for the notification's action button.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if buttonTitle is present; otherwise the current setting.
///
/// Notes:
///  * The affects of this method only apply if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).actionButtonTitle UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_otherButtonTitle(lua_State* L) {
/// hs.notify:otherButtonTitle([buttonTitle]) -> notificationObject | current-setting
/// Method
/// Get or set the label of a notification's other button
///
/// Parameters:
///  * buttonTitle - An optional string containing the title for the notification's other button.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if buttonTitle is present; otherwise the current setting.
///
/// Notes:
///  * The affects of this method only apply if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).otherButtonTitle UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_hasActionButton(lua_State* L) {
/// hs.notify:hasActionButton([hasButton]) -> notificationObject | current-setting
/// Method
/// Get or set the presence of an action button in a notification
///
/// Parameters:
///  * hasButton - An optional boolean indicating whether an action button should be present.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if hasButton is present; otherwise the current setting.
///
/// Notes:
///  * The affects of this method only apply if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).hasActionButton);
    } else if (!notification->locked) {
        ((__bridge NSUserNotification *) notification->note).hasActionButton = (BOOL) lua_toboolean(L, 2);
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_alwaysPresent(lua_State* L) {
/// hs.notify:alwaysPresent([alwaysPresent]) -> notificationObject | current-setting
/// Method
/// Get or set whether a notification should be presented even if this overrides Notification Center's decision process.
///
/// Parameters:
///  * alwaysPresent - An optional boolean parameter indicating whether the notification should override Notification Center's decision about whether to present the notification or not. Defaults to true.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if alwaysPresent is provided; otherwise the current setting.
///
/// Notes:
///  * This does not affect the return value of `hs.notify:presented()` -- that will still reflect the decision of the Notification Center
///  * Examples of why the users Notification Center would choose not to display a notification would be if Hammerspoon is the currently focussed application, being attached to a projector, or the user having set Do Not Disturb.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        BOOL alwaysPresent = [(NSNumber *)[((__bridge NSUserNotification *) notification->note).userInfo valueForKey:@"alwaysPresent"] boolValue];
        lua_pushboolean(L, alwaysPresent);
    } else if (!notification->locked) {
        NSMutableDictionary *noteInfoDict = [((__bridge NSUserNotification *) notification->note).userInfo mutableCopy];
        [noteInfoDict setValue:@((BOOL)lua_toboolean(L, 2)) forKey:@"alwaysPresent"] ;
        ((__bridge NSUserNotification *) notification->note).userInfo = noteInfoDict ;
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_release(lua_State* L) {
/// hs.notify:release() -> notificationObject
/// Method
/// This is a no-op included for backwards compatibility.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///
/// Notes:
///  * This is no longer required during garbage collection as function tags can be re-established after a reload.
///  * The proper way to release a notifications callback is to remove its tag from the `hs.notify.registry` with `hs.notify.unregister`.
///  * This is included for backwards compatibility.

    [[LuaSkin shared] logInfo:@"hs.notify:release() is a no-op. If you want to remove a notification's callback, see hs.notify:getFunctionTag()."] ;
    lua_settop(L, 1) ;
    return 1;
}

static int notification_getFunctionTag(lua_State* L) {
/// hs.notify:getFunctionTag() -> functiontag
/// Method
/// Return the name of the function tag the notification will call when activated.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The function tag for this notification as a string.
///
/// Notes:
///  * This tag should correspond to a function in `hs.notify.registry` and can be used to either add a replacement with `hs.notify.register(...)` or remove it with `hs.notify.unregister(...)`
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);

    NSString *fnTag = [((__bridge NSUserNotification *) notification->note).userInfo valueForKey:@"tag"] ;

    lua_pushstring(L, [fnTag UTF8String]) ;
    return 1;
}

static int notification_autoWithdraw(lua_State* L) {
/// hs.notify:autoWithdraw([shouldWithdraw]) -> notificationObject | current-setting
/// Method
/// Get or set whether a notification should automatically withdraw once activated
///
/// Parameters:
///  * shouldWithdraw - An optional boolean indicating whether the notification should automatically withdraw. Defaults to true.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if shouldWithdraw is present; otherwise the current setting.
///
/// Note:
///  * This method has no effect if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences: clicking on either the action or other button will clear the notification automatically.
///  * If a notification which was created before your last reload (or restart) of Hammerspoon and is clicked upon before hs.notify has been loaded into memory, this setting will not be honored because the initial application delegate is not aware of this option and is set to automatically withdraw all notifications which are acted upon.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        BOOL autoWithdraw = [(NSNumber *)[((__bridge NSUserNotification *) notification->note).userInfo valueForKey:@"autoWithdraw"] boolValue];
        lua_pushboolean(L, autoWithdraw);
    } else if (!notification->locked) {
        NSMutableDictionary *noteInfoDict = [((__bridge NSUserNotification *) notification->note).userInfo mutableCopy];
        [noteInfoDict setValue:@((BOOL)lua_toboolean(L, 2)) forKey:@"autoWithdraw"] ;
        ((__bridge NSUserNotification *) notification->note).userInfo = noteInfoDict ;
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_soundName(lua_State* L) {
/// hs.notify:soundName([soundName]) -> notificationObject | current-setting
/// Method
/// Get or set the sound for a notification
///
/// Parameters:
///  * soundName - An optional string containing the name of a sound to play with the notification. If `nil`, no sound will be played. Defaults to `nil`.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if soundName is present; otherwise the current setting.
///
/// Notes:
///  * Sounds will first be matched against the names of system sounds. If no matches can be found, they will then be searched for in the following paths, in order:
///   * `~/Library/Sounds`
///   * `/Library/Sounds`
///   * `/Network/Sounds`
///   * `/System/Library/Sounds`
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).soundName UTF8String]);
    } else if (!notification->locked) {
        if (lua_isnil(L,2)) {
            ((__bridge NSUserNotification *) notification->note).soundName = nil;
        } else {
            ((__bridge NSUserNotification *) notification->note).soundName = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

static int notification_contentImage(lua_State *L) {
// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
    NSImage *contentImage;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);

    if (lua_isnone(L, 2)) {
        if ([((__bridge NSUserNotification *) notification->note) respondsToSelector:@selector(contentImage)]) {
            contentImage = ((__bridge NSUserNotification *) notification->note).contentImage ;
            [[LuaSkin shared] pushNSObject:contentImage];
        } else {
            lua_pushnil(L) ;
        }
    } else if (!notification->locked) {
        if ([((__bridge NSUserNotification *) notification->note) respondsToSelector:@selector(contentImage)]) {
            contentImage = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"] ;
            if (!contentImage) {
                return luaL_error(L, "invalid image specified");
            } else {
                contentImage = ((__bridge NSUserNotification *) notification->note).contentImage = contentImage ;
                notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
                lua_settop(L, 1) ;
            }
        } else {
            [[LuaSkin shared] logInfo:@"hs.notify:contentImage() is only supported in OS X 10.9 and newer."] ;
            lua_settop(L, 1) ;
        }
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1 ;
}

// Get status of a notification

static int notification_presented(lua_State* L) {
/// hs.notify:presented() -> bool
/// Method
/// Returns whether the users Notification Center decided to display the notification
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the users Notification Center decided to display the notification
///
/// Notes:
///  * Examples of why the users Notification Center would choose not to display a notification would be if Hammerspoon is the currently focussed application, being attached to a projector, or the user having set Do Not Disturb.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).presented);
    return 1;
}

static int notification_delivered(lua_State* L) {
/// hs.notify:delivered() -> bool
/// Method
/// Returns whether the notification has been delivered to the Notification Center
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean indicating whether the notification has been delivered to the users Notification Center
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, notification->delivered);
    return 1;
}

// static int notification_remote(lua_State* L) {
// /// hs.notify:remote() -> bool
// /// Method
// /// Returns whether the notification was generated by a push notification (remotely).
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * True if the notification was generated by a push or false if it was generated locally.
// ///
// /// Notes:
// ///  * Currently Hammerspoon only supports locally generated notifications, not push notifications, so this method will always return false.
//     notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
//     lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).remote);
//     return 1;
// }

static int notification_activationType(lua_State* L) {
/// hs.notify:activationType() -> number
/// Method
/// Returns how the notification was activated by the user.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the integer value corresponding to how the notification was activated by the user.  See the table `hs.notify.activationTypes[]` for more information.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushinteger(L, ((__bridge NSUserNotification *) notification->note).activationType);
    return 1;
}

static int notification_actualDeliveryDate(lua_State* L) {
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
///  * You can turn epoch times into a human readable string or a table of date elements with the `os.date()` function.
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushinteger(L, lround([((__bridge NSUserNotification *) notification->note).actualDeliveryDate timeIntervalSince1970]));
    return 1;
}

static int notification_activationTypesTable(lua_State *L) {
/// hs.notify.activationTypes[]
/// Constant
/// Convenience array of the possible activation types for a notification, and their reverse for reference.
/// * None - The user has not interacted with the notification.
/// * ContentsClicked - User clicked on notification
/// * ActionButtonClicked - User clicked on Action button
// /// * Replied - User used Reply button (10.9) (not implemented yet)
// /// * AdditionalActionClicked - Additional Action selected (10.10) (not implemented yet)
    lua_newtable(L) ;
    lua_pushinteger(L, NSUserNotificationActivationTypeNone);
        lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeContentsClicked);
        lua_setfield(L, -2, "contentsClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeActionButtonClicked);
        lua_setfield(L, -2, "actionButtonClicked") ;
//     lua_pushinteger(L, NSUserNotificationActivationTypeReplied);
//         lua_setfield(L, -2, "replied") ;
//     lua_pushinteger(L, NSUserNotificationActivationTypeAdditionalActionClicked);
//         lua_setfield(L, -2, "additionalActionClicked") ;

    return 1 ;
}

// NOTE: Metamethods and module setup/teardown

static int notification_delegate_setup(lua_State* __unused L) {
    // Get and store old (core app) delegate.  If it hasn't been setup yet, do so.
    old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    if (!old_delegate) {
        [MJUserNotificationManager sharedManager];
        old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    }
    // Create our delegate
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:[ourNotificationManager sharedManager]];
//     [ourNotificationManager sharedManager];
    return 0;
}

// static int showMyDict(lua_State* L) {
//     notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
//     lua_pushNSObject(L, [((__bridge NSUserNotification *) notification->note) userInfo]) ;
//     return 1 ;
// }

static int userdata_tostring(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    NSString* title = ((__bridge NSUserNotification *) notification->note).title ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;

    return 1 ;
}

static int userdata_gc(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    NSUserNotification *holding = (__bridge_transfer NSUserNotification *) notification->note ;
    notification->note = nil ; holding = nil ;

    NSString *myID = (__bridge_transfer NSString *) notification->gus ;
    myID = nil ; notification->gus = nil ;

    return 0;
}

// Metamethods for the module
static int meta_gc(lua_State* __unused L) {
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:(id <NSUserNotificationCenterDelegate>)old_delegate];
//     sharedManager = nil;
    return 0;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"send",                notification_send},
    {"schedule",            notification_scheduleNotification},
    {"withdraw",            notification_withdraw},
    {"title",               notification_title},
    {"subTitle",            notification_subtitle},
    {"informativeText",     notification_informativeText},
    {"actionButtonTitle",   notification_actionButtonTitle},
    {"otherButtonTitle",    notification_otherButtonTitle},
    {"hasActionButton",     notification_hasActionButton},
    {"soundName",           notification_soundName},
    {"alwaysPresent",       notification_alwaysPresent},
    {"autoWithdraw",        notification_autoWithdraw},
    {"_contentImage",       notification_contentImage},
    {"release",             notification_release},
    {"getFunctionTag",      notification_getFunctionTag},
    {"presented",           notification_presented},
    {"delivered",           notification_delivered},
    {"activationType",      notification_activationType},
    {"actualDeliveryDate",  notification_actualDeliveryDate},

// Maybe add in the future, if there is interest...
//
//     {"repeatInterval",              notification_deliveryRepeatInterval},
//     {"responsePlaceholder",         NULL},                                  // 10.9
//     {"hasReplyButton",              NULL},                                  // 10.9
//     {"additionalActions",           NULL},                                  // 10.10

//     {"remote",                      notification_remote},
//     {"response",                    NULL},                                  // 10.9
//     {"additionalActivationAction",  NULL},                                  // 10.10

// debugging
//     {"showMyDict", showMyDict},

    {"__tostring",          userdata_tostring},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"_new",                  notification_new},
    {"withdrawAll",           notification_withdraw_all},
    {"withdrawAllScheduled",  notification_withdraw_allScheduled},
    {NULL,                    NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_notify_internal(lua_State* L) {

    notification_delegate_setup(L);

    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    notification_activationTypesTable(L) ;
    lua_setfield(L, -2, "activationTypes") ;

/// hs.notify.defaultNotificationSound
/// Constant
/// The string representation of the default notification sound. Use `hs.notify:soundName()` or set the `soundName` attribute in `hs:notify.new()`, to this constant, if you want to use the default sound
    lua_pushstring(L, [NSUserNotificationDefaultSoundName UTF8String]) ;
    lua_setfield(L, -2, "defaultNotificationSound") ;

    return 1;
}
