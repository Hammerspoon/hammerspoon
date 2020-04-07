@import Cocoa ;
@import LuaSkin ;

// #define DEBUGGING

#define USERDATA_TAG    "hs.notify"
static int refTable = LUA_NOREF ;

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

// Private API for setting notification identity image http://stackoverflow.com/questions/19797841
@interface NSUserNotification (NSUserNotificationPrivate)
- (void)set_identityImage:(NSImage *)image;
@property BOOL _identityImageHasBorder;
@property BOOL _alwaysShowAlternateActionMenu; // See: https://stackoverflow.com/questions/33631218/show-nsusernotification-additionalactions-on-click
@end

static id <NSUserNotificationCenterDelegate>    old_delegate ;

typedef struct _notification_t {
    BOOL    locked ;      // flag to indicate if changes should no longer be allowed (it's been sent)
    BOOL    delivered ;   // flag to indicate if notification has been delivered to the User Notification Center
    void*   note ;        // user notification object itself
    void*   gus ;         // globally unique identifier for use when verifying/recreating userdata
    int     withdrawAfter; // Number of seconds after which to auto-withdraw the notification
} notification_t ;

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
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
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

// Notification delivered to Notification Center
- (void)userNotificationCenter:(NSUserNotificationCenter *)center
        didDeliverNotification:(NSUserNotification *)notification {

    // NSlog(@"in didDeliverNotification") ;

    NSString *fnTag = [notification.userInfo valueForKey:@"tag"] ;

    notification_t *thisNote = [self getOrCreateUserdata:notification] ;  // necessary in case of reload

    if (fnTag) {
        thisNote->delivered = YES ;
    } // not one of ours, and MJUserNotificationManager doesn't use this, so do nothing else

    if (thisNote->withdrawAfter > 0) {
        [center performSelector:@selector(removeDeliveredNotification:) withObject:notification afterDelay:(NSTimeInterval)thisNote->withdrawAfter];
    }
}

// User clicked on notification...
- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {

    // NSLog(@"in didActivateNotification") ;

        NSString *fnTag = [notification.userInfo valueForKey:@"tag"] ;

        if (fnTag) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);

        // maybe a little more overhead than just assuming its there and putting logic in init.lua to
        // make sure hs.notify is in the right place, but this is more portable and doesn't rely on
        // assumptions.  And luaL_requiref requires knowing the open function name...
            lua_getglobal(skin.L, "require") ;
            lua_pushstring(skin.L, "hs.notify") ;
            if (![skin protectedCallAndTraceback:1 nresults:1]) {
                const char *errorMsg = lua_tostring(skin.L, -1);
                [skin logError:[NSString stringWithFormat:@"Unable to require('hs.notify'): %s", errorMsg]];
                lua_pop(skin.L, 1) ; // remove error message
                _lua_stackguard_exit(skin.L);
                return;
            }
            lua_getfield(skin.L, -1, "_tag_handler") ;
        // now we know the function hs.notify._tag_handler is on the stack...

            lua_pushstring(skin.L, [fnTag UTF8String]) ;

            notification_t __unused *thisNote = [self getOrCreateUserdata:notification] ; // necessary in case of reload
            [skin pushLuaRef:refTable ref:[[notification.userInfo valueForKey:@"userdata"] intValue]];

    // NSLog(@"invoking callback handler") ;

            if ([skin protectedCallAndError:@"hs.notify callback" nargs:2 nresults:0] == NO) {
                lua_pop(skin.L, 1); // pop the hs.notify module
                _lua_stackguard_exit(skin.L);
                return;
            }
            lua_pop(skin.L, 1); // pop the hs.notify module

            BOOL shouldWithdraw = [[notification.userInfo valueForKey:@"autoWithdraw"] boolValue] ;
            if (notification.deliveryRepeatInterval != nil) shouldWithdraw = YES ;

            if (shouldWithdraw) {
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification:notification];
            }
            _lua_stackguard_exit(skin.L);
        } else {
    // NSLog(@"hs.notify passing off to original handler") ;
            if ([old_delegate respondsToSelector:@selector(userNotificationCenter:didActivateNotification:)]) {
                [old_delegate userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:notification];
            }
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

/// hs.notify.deliveredNotifications() -> table
/// Function
/// Returns a table containing notifications which have been delivered.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the notification userdata objects for all Hammerspoon notifications currently in the notification center
///
/// Notes:
///  * Only notifications which have been presented but not cleared, either by the user clicking on the [hs.notify:otherButtonTitle](#otherButtonTitle) or through auto-withdrawal (see [hs.notify:autoWithdraw](#autoWithdraw) for more details), will be in the array returned.
///
///  * You can use this function along with [hs.notify:getFunctionTag](#getFunctionTag) to re=register necessary callback functions with [hs.notify.register](#register) when Hammerspoon is restarted.
///
///  * Since notifications which the user has closed (or cancelled) do not trigger a callback, you can check this table with a timer to see if the user has cleared a notification, e.g.
/// ~~~lua
/// myNotification = hs.notify.new():send()
/// clearCheck = hs.timer.doEvery(10, function()
///     if not hs.fnutils.contains(hs.notify.deliveredNotifications(), myNotification) then
///         if myNotification:activationType() == hs.notify.activationTypes.none then
///             print("You dismissed me!")
///         else
///             print("A regular action occurred, so callback (if any) was invoked")
///         end
///         clearCheck:stop() -- either way, no need to keep polling
///         clearCheck = nil
///     end
/// end)
/// ~~~
static int notification_deliveredNotifications(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications]] ;
    return 1 ;
}

/// hs.notify.scheduledNotifications() -> table
/// Function
/// Returns a table containing notifications which are scheduled but have not yet been delivered.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the notification userdata objects for all Hammerspoon notifications currently scheduled to be delivered.
///
/// Notes:
///  * Once a notification has been delivered, it is moved to [hs.notify.deliveredNotifications](#deliveredNotifications) or removed, depending upon the users action.
///
///  * You can use this function along with [hs.notify:getFunctionTag](#getFunctionTag) to re=register necessary callback functions with [hs.notify.register](#register) when Hammerspoon is restarted.
static int notification_scheduledNotifications(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[NSUserNotificationCenter defaultUserNotificationCenter] scheduledNotifications]] ;
    return 1 ;
}

static int notification_new(lua_State* L) {
// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
// hs.notify._new(fntag) -> notificationObject
// Constructor
// Returns a new notification object with the specified information and the assigned callback function.
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
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
    note.hasActionButton     = NO;

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
///  * This value is ignored if [hs.notify:hasReplyButton](#hasReplyButton) is true.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).actionButtonTitle UTF8String]);
    } else if (!notification->locked) {
        NSString *title = lua_isnil(L, 2) ? nil : [skin toNSObjectAtIndex:2] ;
        if (!title) {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).actionButtonTitle = title ;
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
///  * Due to OSX limitations, it is NOT possible to get a callback for this button.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushstring(L, [((__bridge NSUserNotification *) notification->note).otherButtonTitle UTF8String]);
    } else if (!notification->locked) {
        NSString *title = lua_isnil(L, 2) ? nil : [skin toNSObjectAtIndex:2] ;
        if (!title) {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).otherButtonTitle = title;
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
///  * The proper way to release a notifications callback is to remove its tag from the [hs.notify.registry](#registry) with [hs.notify.unregister](#unregister).
///  * This is included for backwards compatibility.

    [[LuaSkin sharedWithState:L] logInfo:@"hs.notify:release() is a no-op. If you want to remove a notification's callback, see hs.notify:getFunctionTag()."] ;
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
///  * This tag should correspond to a function in [hs.notify.registry](#registry) and can be used to either add a replacement with `hs.notify.register(...)` or remove it with `hs.notify.unregister(...)`
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (lua_isnone(L, 2)) {
        if ([((__bridge NSUserNotification *) notification->note) respondsToSelector:@selector(contentImage)]) {
            contentImage = ((__bridge NSUserNotification *) notification->note).contentImage ;
            [skin pushNSObject:contentImage];
        } else {
            lua_pushnil(L) ;
        }
    } else if (!notification->locked) {
        if ([((__bridge NSUserNotification *) notification->note) respondsToSelector:@selector(contentImage)]) {
            contentImage = [skin luaObjectAtIndex:2 toClass:"NSImage"] ;
            if (!contentImage) {
                return luaL_error(L, "invalid image specified");
            } else {
                contentImage = ((__bridge NSUserNotification *) notification->note).contentImage = contentImage ;
                notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
                lua_settop(L, 1) ;
            }
        } else {
            [skin logInfo:@"hs.notify:contentImage() is only supported in OS X 10.9 and newer."] ;
            lua_settop(L, 1) ;
        }
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1 ;
}

static int notification_setIdImage(lua_State *L) {
// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBOOLEAN, LS_TBREAK];
    notification_t *notificationUserdata = luaL_checkudata(L, 1, USERDATA_TAG);
    BOOL hasBorder = (BOOL)lua_toboolean(L, 3);

    NSUserNotification *notification = ((__bridge NSUserNotification *) notificationUserdata->note);
    if (!([notification respondsToSelector:@selector(set_identityImage:)] &&
          [notification respondsToSelector:@selector(_identityImageHasBorder)])) {
        [skin logInfo:@"hs.notify:setIdImage() is not supported. Please file an issue"];
        lua_settop(L, 1);
    }

    if (!notificationUserdata->locked) {
        NSImage *idImage = [skin luaObjectAtIndex:2 toClass:"NSImage"];
        if (!(idImage && idImage.valid)) {
            return luaL_error(L, "invalid image specified");
        } else {
            [notification set_identityImage:idImage];
            notification._identityImageHasBorder = hasBorder;
            notificationUserdata->delivered = NO; // modifying a notification means that it is considered new by the User Notification Center
            lua_settop(L, 1);
        }
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified");
    }

    return 1;
}

/// hs.notify:hasReplyButton([state]) -> notificationObject | boolean
/// Method
/// Get or set whether an alert notification has a "Reply" button for additional user input.
///
/// Parameters:
///  * state - An optional boolean, default false, indicating whether the notification should include a reply button for additional user input.
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value
///
/// Note:
///  * This method has no effect unless the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences.
///  * [hs.notify:hasActionButton](#hasActionButton) must also be true or the "Reply" button will not be displayed.
///  * If this is set to true, the action button will be "Reply" even if you have set another one with [hs.notify:actionButtonTitle](#actionButtonTitle).
static int notification_hasReplyButton(lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note).hasReplyButton);
    } else if (!notification->locked) {
        ((__bridge NSUserNotification *) notification->note).hasReplyButton = (BOOL) lua_toboolean(L, 2);
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

/// hs.notify:alwaysShowAdditionalActions([state]) -> notificationObject | boolean
/// Method
/// Get or set whether an alert notification should always show an alternate action menu.
///
/// Parameters:
///  * state - An optional boolean, default false, indicating whether the notification should always show an alternate action menu.
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value.
///
/// Note:
///  * This method has no effect unless the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences.
///  * [hs.notify:additionalActions](#additionalActions) must also be used for this method to have any effect.
///  * **WARNING:** This method uses a private API. It could break at any time. Please file an issue if it does.
static int notification_alwaysShowAdditionalActions(lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushboolean(L, ((__bridge NSUserNotification *) notification->note)._alwaysShowAlternateActionMenu);
    } else if (!notification->locked) {
        ((__bridge NSUserNotification *) notification->note)._alwaysShowAlternateActionMenu = (BOOL) lua_toboolean(L, 2);
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

/// hs.notify:withdrawAfter([seconds]) -> notificationObject | number
/// Method
/// Get or set the number of seconds after which to automatically withdraw a notification
///
/// Paramters:
///  * seconds - An optional number, default 5, of seconds after which to withdraw a notification. A value of 0 will not withdraw a notification automatically
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value.
///
/// Note:
///  * While this setting applies to both Banner and Alert styles of notifications, it is functionally meaningless for Banner styles
///  * A value of 0 will disable auto-withdrawal
static int notification_withdrawAfter(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    notification_t *notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        lua_pushnumber(L, notification->withdrawAfter);
    } else if (!notification->locked){
        notification->withdrawAfter = lua_tonumber(L, 2);
        lua_settop(L, 1);
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified");
    }
    return 1;
}

/// hs.notify:responsePlaceholder([string]) -> notificationObject | string
/// Method
/// Set a placeholder string for alert type notifications with a reply button.
///
/// Parameters:
///  * `string` - an optional string specifying placeholder text to display in the reply box before the user has types anything in an alert type notification with a reply button.
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value
///
/// Notes:
///  * In macOS 10.13, this text appears so light that it is almost unreadable; so far no workaround has been found.
///  * See also [hs.notify:hasReplyButton](#hasReplyButton)
static int notification_responsePlaceholder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_isnone(L, 2)) {
        [skin pushNSObject:((__bridge NSUserNotification *) notification->note).responsePlaceholder] ;
    } else if (!notification->locked) {
        NSString *placeholder = lua_isnil(L, 2) ? nil : [skin toNSObjectAtIndex:2] ;
        if (!placeholder) {
            ((__bridge NSUserNotification *) notification->note).responsePlaceholder = @"";
        } else {
            ((__bridge NSUserNotification *) notification->note).responsePlaceholder = placeholder;
        }
        notification->delivered = NO ; // modifying a notification means that it is considered new by the User Notification Center
        lua_settop(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1;
}

/// hs.notify:response() -> string | nil
/// Method
/// Get the users input from an alert type notification with a reply button.
///
/// Parameters:
///  * None
///
/// Returns:
///  * If the notification has a reply button and the user clicks on it, returns a string containing the user input (may be an empty string); otherwise returns nil.
///
/// Notes:
///  * [hs.notify:activationType](#activationType) will equal `hs.notify.activationTypes.replied` if the user clicked on the Reply button and then clicks on Send.
///  * See also [hs.notify:hasReplyButton](#hasReplyButton)
static int notification_response(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    NSAttributedString *response = ((__bridge NSUserNotification *) notification->note).response ;
    if (response) {
        // since placeholder is a string, and there are no tools to edit within the reply, let's leave it as a string unless someone cares. Remember to local `hs.styledtext` in init.lua if this changes
        [skin pushNSObject:response.string] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.notify:additionalActions([actionsTable]) -> notificationObject | table
/// Method
/// Get or set additional actions which will be displayed for an alert type notification when the user clicks and holds down the action button of the alert.
///
/// Parameters:
///  * an optional table containing an array of strings specifying the additional options to list for the user to select from the notification.
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value
///
/// Notes:
///  * The additional items will be listed in a pop-up menu when the user clicks and holds down the mouse button in the action button of the alert.
///  * If the user selects one of the additional actions, [hs.notify:activationType](#activationType) will equal `hs.notify.activationTypes.additionalActionClicked`
///  * See also [hs.notify:additionalActivationAction](#additionalActivationAction)
static int notification_additionalActions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    if (lua_gettop(L) == 1) {
        NSArray *actions = ((__bridge NSUserNotification *) notification->note).additionalActions ;
        lua_newtable(L) ;
        if (actions) {
            for (NSUserNotificationAction *action in actions) {
                [skin pushNSObject:action.title] ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1 ) ;
            }
        }
    } else if (!notification->locked) {
        NSArray *actions = [skin toNSObjectAtIndex:2] ;
        NSMutableArray *newActions = [[NSMutableArray alloc] init] ;
        __block NSString *errorMsg = nil ;
        if ([actions isKindOfClass:[NSArray class]]) {
            [actions enumerateObjectsUsingBlock:^(NSString *item, NSUInteger idx, BOOL *stop) {
                if (![item isKindOfClass:[NSString class]]) {
                    errorMsg = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                    *stop = YES ;
                } else {
                    [newActions addObject:[NSUserNotificationAction actionWithIdentifier:item title:item]] ;
                }
            }] ;
        } else {
            errorMsg = @"expected a table containing an array of strings" ;
        }
        if (errorMsg) return luaL_argerror(L, 2, errorMsg.UTF8String) ;
        ((__bridge NSUserNotification *) notification->note).additionalActions = newActions ;
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
    }
    return 1 ;
}

/// hs.notify:additionalActivationAction() -> string | nil
/// Method
/// Return the additional action that the user selected from an alert type notification that has additional actions available.
///
/// Parameters:
///  * None
///
/// Returns:
///  * If the notification has additional actions assigned with [hs.notify:additionalActions](#additionalActions) and the user selects one, returns a string containing the selected action; otherwise returns nil.
///
/// Notes:
///  * If the user selects one of the additional actions, [hs.notify:activationType](#activationType) will equal `hs.notify.activationTypes.additionalActionClicked`
///  * See also [hs.notify:additionalActions](#additionalActions)
static int notification_additionalActivationAction(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    NSUserNotificationAction *action = ((__bridge NSUserNotification *) notification->note).additionalActivationAction ;
    if (action) {
        [skin pushNSObject:action.title] ;
    } else {
        lua_pushnil(L) ;
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
/// * None                    - The user has not interacted with the notification.
/// * ContentsClicked         - User clicked on notification
/// * ActionButtonClicked     - User clicked on Action button
/// * Replied                 - User used Reply button
/// * AdditionalActionClicked - Additional Action selected
///
/// Notes:
///  * Count starts at zero. (implemented in Objective-C)
    lua_newtable(L) ;
    lua_pushinteger(L, NSUserNotificationActivationTypeNone);
        lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeContentsClicked);
        lua_setfield(L, -2, "contentsClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeActionButtonClicked);
        lua_setfield(L, -2, "actionButtonClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeReplied);
        lua_setfield(L, -2, "replied") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeAdditionalActionClicked);
        lua_setfield(L, -2, "additionalActionClicked") ;

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
    return 0;
}

#ifdef DEBUGGING
static int showMyDict(lua_State* L) {
    notification_t* notification = luaL_checkudata(L, 1, USERDATA_TAG);
    [[LuaSkin sharedWithState:L] pushNSObject:((__bridge NSUserNotification *) notification->note).userInfo withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}
#endif

static int pushNSUserNotification(lua_State *L, id obj) {
    NSUserNotification *value = obj;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    notification_t *notification = [[ourNotificationManager sharedManager] getOrCreateUserdata:value] ;
    [skin pushLuaRef:refTable ref:[[((__bridge NSUserNotification *) notification->note).userInfo valueForKey:@"userdata"] intValue]];
    return 1;
}

static int userdata_eq(lua_State *L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        notification_t* notification1 = luaL_checkudata(L, 1, USERDATA_TAG);
        notification_t* notification2 = luaL_checkudata(L, 2, USERDATA_TAG);
        NSString *gus1 = (__bridge NSString *)notification1->gus ;
        NSString *gus2 = (__bridge NSString *)notification2->gus ;
        lua_pushboolean(L, [gus1 isEqualToString:gus2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

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
    {"send",                        notification_send},
    {"schedule",                    notification_scheduleNotification},
    {"withdraw",                    notification_withdraw},
    {"title",                       notification_title},
    {"subTitle",                    notification_subtitle},
    {"informativeText",             notification_informativeText},
    {"actionButtonTitle",           notification_actionButtonTitle},
    {"otherButtonTitle",            notification_otherButtonTitle},
    {"hasActionButton",             notification_hasActionButton},
    {"soundName",                   notification_soundName},
    {"alwaysPresent",               notification_alwaysPresent},
    {"autoWithdraw",                notification_autoWithdraw},
    {"_contentImage",               notification_contentImage},
    {"_setIdImage",                 notification_setIdImage},
    {"release",                     notification_release},
    {"getFunctionTag",              notification_getFunctionTag},
    {"presented",                   notification_presented},
    {"delivered",                   notification_delivered},
    {"activationType",              notification_activationType},
    {"actualDeliveryDate",          notification_actualDeliveryDate},

    {"responsePlaceholder",         notification_responsePlaceholder},
    {"hasReplyButton",              notification_hasReplyButton},
    {"additionalActions",           notification_additionalActions},
    {"response",                    notification_response},
    {"additionalActivationAction",  notification_additionalActivationAction},
    {"alwaysShowAdditionalActions", notification_alwaysShowAdditionalActions},
    {"withdrawAfter",               notification_withdrawAfter},

// Maybe add in the future, if there is interest...
//
//     {"repeatInterval",              notification_deliveryRepeatInterval},

//     {"remote",                      notification_remote},

#ifdef DEBUGGING
    {"showMyDict", showMyDict},
#endif

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"_new",                   notification_new},
    {"withdrawAll",            notification_withdraw_all},
    {"withdrawAllScheduled",   notification_withdraw_allScheduled},
    {"deliveredNotifications", notification_deliveredNotifications},
    {"scheduledNotifications", notification_scheduledNotifications},
    {NULL,                     NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_notify_internal(lua_State* L) {

    notification_delegate_setup(L);

    LuaSkin *skin = [LuaSkin sharedWithState:L];
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

    [skin registerPushNSHelper:pushNSUserNotification forClass:"NSUserNotification"];

    return 1;
}
