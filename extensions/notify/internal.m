@import Cocoa ;
@import LuaSkin ;

#import "MJUserNotificationManager.h"

#define DEBUGGING

// NSUserNotification and it's relations are deprecated but we're not ready to switch quite yet...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

static const char * const USERDATA_TAG = "hs.notify" ;
static LSRefTable refTable = LUA_NOREF ;

// changes made to userInfo dictionary in userNotificationCenter:didDeliverNotification: are not
// kept (is notification object a copy?) so we can't update delivered if it's in that particular
// dictionary... track it in here instead, keyed to unique id added when created (see new).
static NSMutableDictionary *ourNotificationSpecifics ;

#define KEY_LOCKED        @"locked"
#define KEY_ID            @"gus"
#define KEY_WITHDRAWAFTER @"withdrawAfter"
#define KEY_FNTAG         @"fntag"
#define KEY_ALWAYSPRESENT @"alwaysPresent"
#define KEY_AUTOWITHDRAW  @"autoWithdraw"
#define KEY_SELFREFCOUNT  @"selfRefCount"
#define KEY_DELIVERED     @"delivered"

static id <NSUserNotificationCenterDelegate>    old_delegate ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

// Private API for setting notification identity image http://stackoverflow.com/questions/19797841
@interface NSUserNotification (NSUserNotificationPrivate)
- (void)set_identityImage:(NSImage *)image;
@property BOOL _identityImageHasBorder;
@property BOOL _alwaysShowAlternateActionMenu; // See: https://stackoverflow.com/questions/33631218/show-nsusernotification-additionalactions-on-click
@end

#pragma mark - Support Functions and Classes

@interface HSModuleNotificationManager : NSObject <NSUserNotificationCenterDelegate>
+ (HSModuleNotificationManager*) sharedManager;
@end

@implementation HSModuleNotificationManager

+ (instancetype) sharedManager {
    static HSModuleNotificationManager *sharedManager ;
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        sharedManager = [[HSModuleNotificationManager alloc] init] ;
    }) ;
    return sharedManager ;
}

// Notification delivered to Notification Center
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s in didDeliverNotification %@", USERDATA_TAG, notification.userInfo]] ;

    // if it's ours, we've copied the necessary info into the userInfo dictionary...
    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        // however we *might* need to recreate the local record so we can update KEY_DELIVERED
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        if (!userInfo) {
            ourNotificationSpecifics[gus] = [notification.userInfo mutableCopy] ;
            userInfo = ourNotificationSpecifics[gus] ;
        }
        userInfo[KEY_DELIVERED] = @(YES) ;

        NSNumber       *NSwithdrawAfter = userInfo[KEY_WITHDRAWAFTER] ;
        NSTimeInterval withdrawAfter    = NSwithdrawAfter ? NSwithdrawAfter.doubleValue : 0.0 ;

        if (withdrawAfter > 0) {
            [center performSelector:@selector(removeDeliveredNotification:)
                         withObject:notification
                         afterDelay:withdrawAfter];
        }
    } // else not one of ours, and MJUserNotificationManager doesn't use this, so do nothing else
}

// User clicked on notification...
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s in didActivateNotification %@", USERDATA_TAG, notification.userInfo]] ;

    // if it's ours, we've copied the necessary info into the userInfo dictionary...
    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        // however we *might* need to recreate the local record so we can update KEY_DELIVERED
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        if (!userInfo) {
            ourNotificationSpecifics[gus] = [notification.userInfo mutableCopy] ;
            userInfo = ourNotificationSpecifics[gus] ;
        }
        userInfo[KEY_DELIVERED] = @(YES) ; // just in case its a holdover from before a reload/relaunch

        LuaSkin   *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L    = skin.L ;

        _lua_stackguard_entry(L);
        if (![skin requireModule:"hs.notify"]) {
            [skin logError:[NSString stringWithFormat:@"%s:_didActivateNotification - unable to load tag handler: %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ; // remove error message
            _lua_stackguard_exit(L);
            return;
        }
        lua_getfield(L, -1, "_tag_handler") ; // now we know the function hs.notify._tag_handler is on the stack...
        [skin pushNSObject:userInfo[KEY_FNTAG]] ;
        [skin pushNSObject:notification] ;

        if ([skin protectedCallAndError:[NSString stringWithFormat:@"%s callback", USERDATA_TAG] nargs:2 nresults:0] == NO) {
            lua_pop(L, 1); // pop the hs.notify module
            _lua_stackguard_exit(L);
            return;
        }
        lua_pop(L, 1); // pop the hs.notify module

        NSNumber *NSshouldWithdraw = userInfo[KEY_AUTOWITHDRAW] ;
        BOOL shouldWithdraw = NSshouldWithdraw ? NSshouldWithdraw.boolValue : YES ;
        if (notification.deliveryRepeatInterval != nil) shouldWithdraw = YES ;

        if (shouldWithdraw) {
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification:notification];
        }
        _lua_stackguard_exit(skin.L);
    } else {
        [LuaSkin logInfo:[NSString stringWithFormat:@"%s passing off to original handler", USERDATA_TAG]] ;
        if ([old_delegate respondsToSelector:@selector(userNotificationCenter:didActivateNotification:)]) {
            [old_delegate userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:notification];
        }
    }
}

// Should notification show, even if we're the foremost application?
- (BOOL)userNotificationCenter:(NSUserNotificationCenter __unused *)center shouldPresentNotification:(NSUserNotification *)notification {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s in shouldPresentNotification %@", USERDATA_TAG, notification.userInfo]] ;

    // if it's ours, we've copied the necessary info into the userInfo dictionary...
    NSNumber *shouldPresent = notification.userInfo[KEY_ALWAYSPRESENT] ;
    if (shouldPresent != nil) {
        return (BOOL)(shouldPresent.boolValue) ;
    } else { // MJNotificationManager just returns YES, so this is simpler.
        return YES ;
    }
}

@end

static void notification_delegate_setup() {
    // Get and store old (core app) delegate.  If it hasn't been setup yet, do so.
    old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    if (!old_delegate) {
        [MJUserNotificationManager sharedManager];
        old_delegate = [[NSUserNotificationCenter defaultUserNotificationCenter] delegate];
    }
    // Create our delegate
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:[HSModuleNotificationManager sharedManager]];
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

#pragma mark - Module Functions

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
static int notification_withdraw_all(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    return 0;
}

/// hs.notify.withdrawAllScheduled()
/// Function
/// Withdraw all scheduled notifications from Hammerspoon
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int notification_withdraw_allScheduled(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
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
    NSArray *deliveredNotifications = [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications] ;

    [skin pushNSObject:deliveredNotifications] ;
    // just in case pushNSUserNotification had to recreate our entries in ourNotificationSpecifics
    for (NSUserNotification *notification in deliveredNotifications) {
        NSString *gus = notification.userInfo[KEY_ID] ;
        if (gus) {
            NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
            userInfo[KEY_DELIVERED] = @(YES) ;
        }
    }
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

// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
// hs.notify._new(fntag) -> notificationObject
// Constructor
// Returns a new notification object with the specified information and the assigned callback function.
static int notification_new(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *gus = [[NSProcessInfo processInfo] globallyUniqueString] ;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
        KEY_LOCKED        : @(NO),
        KEY_ID            : gus,
        KEY_WITHDRAWAFTER : @(0.0),
        KEY_FNTAG         : [skin toNSObjectAtIndex:1],
        KEY_ALWAYSPRESENT : @(YES),
        KEY_AUTOWITHDRAW  : @(YES),
        KEY_SELFREFCOUNT  : @(0),
        KEY_DELIVERED     : @(NO)
    }] ;

    ourNotificationSpecifics[gus] = userInfo ;

    NSUserNotification* notification = [[NSUserNotification alloc] init];
    notification.userInfo            = @{ KEY_ID : gus } ;
    notification.hasActionButton     = NO;

    [skin pushNSObject:notification] ;
    return 1;
}

#pragma mark - Module Methods

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
static int notification_send(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        userInfo[KEY_DELIVERED] = @(NO) ;
        userInfo[KEY_LOCKED] = @(YES) ;
        notification.userInfo = [userInfo copy] ;

        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification] ;
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

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
static int notification_scheduleNotification(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;
    NSDate* myDate = lua_isnumber(L, 2) ? [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval) lua_tonumber(L,2)] :
                     lua_isstring(L, 2) ? date_from_string([NSString stringWithUTF8String:lua_tostring(L, 2)]) : nil ;
    if (myDate) {
        notification.deliveryDate = myDate ;
    } else {
        return luaL_error(L, "-- %s:schedule: improper date specified: must be a number (# of seconds since 1970-01-01 00:00:00Z) or string in the format of 'YYYY-MM-DD[T]HH:MM:SS[Z]' (rfc3339)", USERDATA_TAG) ;
    }

    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        userInfo[KEY_DELIVERED] = @(NO) ;
        userInfo[KEY_LOCKED] = @(YES) ;
        notification.userInfo = [userInfo copy] ;

        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification] ;
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    lua_settop(L,1);
    return 1;
}

// Too easy to create runaway repeaters that persist through reboots.
//
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
// static int notification_deliveryRepeatInterval(lua_State* L) {
// }

/// hs.notify:withdraw() -> notificationObject
/// Method
/// Withdraws a delivered notification from the Notification Center.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The notification object
///  * This method allows you to unlock a dispatched notification so that it can be modified and resent.
///
///  * if the notification was not created by this module, it will still be withdrawn if possible
static int notification_withdraw(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        NSNumber *isLocked = userInfo[KEY_LOCKED] ;

        if (isLocked.boolValue == YES) {
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification:notification];

            userInfo[KEY_DELIVERED] = @(NO) ;
            userInfo[KEY_LOCKED] = @(NO) ;
            notification.userInfo = @{ KEY_ID : gus } ;
        } else {
            return luaL_error(L, "notification has not yet been dispatched and cannot be withdrawn") ;
        }
    } else { // not ours, but withdraw anyways
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
    }
    lua_pushvalue(L, 1) ;
    return 1;
}

/// hs.notify:title([titleText]) -> notificationObject | current-setting
/// Method
/// Get or set the title of a notification
///
/// Parameters:
///  * titleText - An optional string containing the title to be set on the notification object.  The default value is "Notification".  If `nil` is passed, then the title is set to the empty string.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if titleText is present; otherwise the current setting.
static int notification_title(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.title] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.title = @"";
            } else {
                notification.title = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

/// hs.notify:subTitle([subtitleText]) -> notificationObject | current-setting
/// Method
/// Get or set the subtitle of a notification
///
/// Parameters:
///  * subtitleText - An optional string containing the subtitle to be set on the notification object. This can be an empty string. If `nil` is passed, any existing subtitle will be removed.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if subtitleText is present; otherwise the current setting.
static int notification_subtitle(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.subtitle] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.subtitle = nil ;
            } else {
                notification.subtitle = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

/// hs.notify:informativeText([informativeText]) -> notificationObject | current-setting
/// Method
/// Get or set the informative text of a notification
///
/// Parameters:
///  * informativeText - An optional string containing the informative text to be set on the notification object. This can be an empty string. If `nil` is passed, any existing informative text will be removed.  If no parameter is provided, then the current setting is returned.
///
/// Returns:
///  * The notification object, if informativeText is present; otherwise the current setting.
static int notification_informativeText(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.informativeText] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.informativeText = nil ;
            } else {
                notification.informativeText = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

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
static int notification_actionButtonTitle(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.actionButtonTitle] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.actionButtonTitle = @"" ;
            } else {
                notification.actionButtonTitle = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

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
static int notification_otherButtonTitle(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.otherButtonTitle] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.otherButtonTitle = @"" ;
            } else {
                notification.otherButtonTitle = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

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
static int notification_hasActionButton(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        lua_pushboolean(L, notification.hasActionButton) ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            notification.hasActionButton = (BOOL)(lua_toboolean(L, 2)) ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

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
///
///  * if the notification was not created by this module, this method will return nil
static int notification_alwaysPresent(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        if (gus) {
            NSNumber *alwaysPresent = userInfo[KEY_ALWAYSPRESENT] ;
            lua_pushboolean(L, alwaysPresent.boolValue) ;
        } else {
            lua_pushnil(L) ;
        }
    } else if (gus) {
            if (isLocked.boolValue == NO) {
            userInfo[KEY_ALWAYSPRESENT] = lua_toboolean(L, 2) ? @(YES) : @(NO) ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

// /// hs.notify:release() -> notificationObject
// /// Method
// /// This is a no-op included for backwards compatibility.
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * The notification object
// ///
// /// Notes:
// ///  * This is no longer required during garbage collection as function tags can be re-established after a reload.
// ///  * The proper way to release a notifications callback is to remove its tag from the [hs.notify.registry](#registry) with [hs.notify.unregister](#unregister).
// ///  * This is included for backwards compatibility.
// static int notification_release(lua_State* L) {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s:release() is a no-op. If you want to remove a notification's callback, see hs.notify:getFunctionTag().", USERDATA_TAG] ;
//     lua_pushvalue(L, 1) ;
//     return 1;
// }

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
///
///  * if the notification was not created by this module, this method will return nil
static int notification_getFunctionTag(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        [skin pushNSObject:userInfo[KEY_FNTAG]] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1;
}

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
///
///  * if the notification was not created by this module, this method will return nil
static int notification_autoWithdraw(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        if (gus) {
            NSNumber *alwaysPresent = userInfo[KEY_AUTOWITHDRAW] ;
            lua_pushboolean(L, alwaysPresent.boolValue) ;
        } else {
            lua_pushnil(L) ;
        }
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            userInfo[KEY_AUTOWITHDRAW] = lua_toboolean(L, 2) ? @(YES) : @(NO) ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

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
static int notification_soundName(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.soundName] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.soundName = nil ;
            } else {
                notification.soundName = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
static int notification_contentImage(lua_State *L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.contentImage];
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            notification.contentImage = [skin toNSObjectAtIndex:2] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1;
}

// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
static int notification_setIdImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBOOLEAN, LS_TBREAK];
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (gus) {
        if (isLocked.boolValue == NO) {
            NSImage *idImage = [skin toNSObjectAtIndex:2] ;
            BOOL hasBorder = (BOOL)(lua_toboolean(L, 3)) ;

            if ([notification respondsToSelector:@selector(set_identityImage:)] && [notification respondsToSelector:@selector(_identityImageHasBorder)]) {
                [notification set_identityImage:idImage];
                notification._identityImageHasBorder = hasBorder;
            } else {
                [skin logInfo:[NSString stringWithFormat:@"%s:setIdImage() is not supported on this machine or macOS version. Please file an issue", USERDATA_TAG]];
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified");
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
    }
    return 1 ;
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
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        lua_pushboolean(L, notification.hasReplyButton) ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            notification.hasReplyButton = (BOOL)(lua_toboolean(L, 2)) ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
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
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if ([notification respondsToSelector:@selector(_alwaysShowAlternateActionMenu)]) {
        if (lua_isnone(L,2)) {
            lua_pushboolean(L, notification._alwaysShowAlternateActionMenu) ;
        } else if (gus) {
            if (isLocked.boolValue == NO) {
                notification._alwaysShowAlternateActionMenu = (BOOL)(lua_toboolean(L, 2)) ;
                lua_pushvalue(L, 1) ;
            } else {
                return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
            }
        } else {
            return luaL_error(L, "notification was not created by this module") ;
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:alwaysShowAdditionalActions() is not supported on this machine or macOS version. Please file an issue", USERDATA_TAG]];
    }
    return 1;
}

/// hs.notify:withdrawAfter([seconds]) -> notificationObject | number
/// Method
/// Get or set the number of seconds after which to automatically withdraw a notification
///
/// Parameters:
///  * seconds - An optional number, default 5, of seconds after which to withdraw a notification. A value of 0 will not withdraw a notification automatically
///
/// Returns:
///  * The notification object, if an argument is present; otherwise the current value.
///
/// Note:
///  * While this setting applies to both Banner and Alert styles of notifications, it is functionally meaningless for Banner styles
///  * A value of 0 will disable auto-withdrawal
///
///  * if the notification was not created by this module, this method will return nil
static int notification_withdrawAfter(lua_State *L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        if (gus) {
            [skin pushNSObject:userInfo[KEY_WITHDRAWAFTER]] ;
        } else {
            lua_pushnil(L) ;
        }
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            userInfo[KEY_WITHDRAWAFTER] = [skin toNSObjectAtIndex:2] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
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
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_isnone(L,2)) {
        [skin pushNSObject:notification.responsePlaceholder] ;
    } else if (gus) {
        if (isLocked.boolValue == NO) {
            if (lua_isnil(L,2)) {
                notification.responsePlaceholder = @"";
            } else {
                notification.responsePlaceholder = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
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
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSAttributedString *response = notification.response ;
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
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
    NSNumber *isLocked = userInfo[KEY_LOCKED] ;

    if (lua_gettop(L) == 1) {
        NSArray *actions = notification.additionalActions ;
        lua_newtable(L) ;
        if (actions) {
            for (NSUserNotificationAction *action in actions) {
                [skin pushNSObject:action.title] ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1 ) ;
            }
        }
    } else if (gus) {
        if (isLocked.boolValue == NO) {
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
            notification.additionalActions = newActions ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "notification has been dispatched and can no longer be modified") ;
        }
    } else {
        return luaL_error(L, "notification was not created by this module") ;
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
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSUserNotificationAction *action = notification.additionalActivationAction ;
    if (action) {
        [skin pushNSObject:action.title] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

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
static int notification_presented(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, notification.presented);
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
///  * A boolean indicating whether the notification has been delivered to the users Notification Center
static int notification_delivered(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    NSString *gus = notification.userInfo[KEY_ID] ;
    if (gus) {
        NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
        NSNumber *delivered = userInfo[KEY_DELIVERED] ;

        lua_pushboolean(L, delivered.boolValue) ;
    } else {
        NSArray *deliveredNotifications = [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications] ;
        lua_pushboolean(L, [deliveredNotifications containsObject:notification]) ;
    }
    return 1 ;
}

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
// static int notification_remote(lua_State* L) {
// }

/// hs.notify:activationType() -> number
/// Method
/// Returns how the notification was activated by the user.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the integer value corresponding to how the notification was activated by the user.  See the table `hs.notify.activationTypes[]` for more information.
static int notification_activationType(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, notification.activationType) ;
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
///  * You can turn epoch times into a human readable string or a table of date elements with the `os.date()` function.
static int notification_actualDeliveryDate(lua_State* L) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:notification.actualDeliveryDate] ;
    return 1;
}

#ifdef DEBUGGING
static int showMyDict(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSUserNotification *notification = [skin toNSObjectAtIndex:1] ;

    BOOL fromNotificationItself = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (fromNotificationItself) {
        [skin pushNSObject:notification.userInfo] ;
    } else {
        NSString *gus = notification.userInfo[KEY_ID] ;
        [skin pushNSObject:ourNotificationSpecifics[gus]] ;
    }
    return 1 ;
}
#endif

#pragma mark - Module Constants

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
    lua_pushinteger(L, NSUserNotificationActivationTypeNone);                    lua_setfield(L, -2, "none") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeContentsClicked);         lua_setfield(L, -2, "contentsClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeActionButtonClicked);     lua_setfield(L, -2, "actionButtonClicked") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeReplied);                 lua_setfield(L, -2, "replied") ;
    lua_pushinteger(L, NSUserNotificationActivationTypeAdditionalActionClicked); lua_setfield(L, -2, "additionalActionClicked") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushNSUserNotification(lua_State *L, id obj) {
    NSUserNotification *value = obj;

    if (value.userInfo) {
        NSString *gus = value.userInfo[KEY_ID] ;
        if (gus) {
            NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
            if (userInfo) {
                NSNumber *NSselfRefCount = userInfo[KEY_SELFREFCOUNT] ;
                userInfo[KEY_SELFREFCOUNT] = @(NSselfRefCount.intValue + 1) ;
            } else {
                if (value.userInfo[KEY_DELIVERED]) { // it's a holdover from a reload/relaunch
                    ourNotificationSpecifics[gus] = [value.userInfo mutableCopy] ;
                    userInfo = ourNotificationSpecifics[gus] ;
                    userInfo[KEY_SELFREFCOUNT] = @(1) ;
                }
            }
        } // else not ours -- how does it exist?
    } // else not ours (probably from core app)
    void** valuePtr = lua_newuserdata(L, sizeof(NSUserNotification *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSUserNotificationFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSUserNotification *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge NSUserNotification, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSUserNotification *obj = [skin luaObjectAtIndex:1 toClass:"NSUserNotification"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSUserNotification *obj1 = [skin luaObjectAtIndex:1 toClass:"NSUserNotification"] ;
        NSUserNotification *obj2 = [skin luaObjectAtIndex:2 toClass:"NSUserNotification"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSUserNotification *obj = get_objectFromUserdata(__bridge_transfer NSUserNotification, L, 1, USERDATA_TAG) ;

    if (obj.userInfo) {
        NSString *gus = obj.userInfo[KEY_ID] ;
        if (gus) { // it's ours
            NSMutableDictionary *userInfo = ourNotificationSpecifics[gus] ;
            if (userInfo) { // and we have a record for it
                NSNumber *NSselfRefCount = userInfo[KEY_SELFREFCOUNT] ;
                userInfo[KEY_SELFREFCOUNT] = @(NSselfRefCount.intValue - 1) ;
                if (NSselfRefCount.intValue == 0) ourNotificationSpecifics[gus] = nil ;
            } // else this shouldn't be possible except *maybe* if meta_gc gets called before userdata one does... unlikely (impossible?)
        }
    }
    obj = nil ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metamethods for the module
static int meta_gc(lua_State* __unused L) {
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:(id <NSUserNotificationCenterDelegate>)old_delegate];
    [ourNotificationSpecifics removeAllObjects] ;
    ourNotificationSpecifics = nil ;
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
//     {"release",                     notification_release},
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    notification_activationTypesTable(L) ; lua_setfield(L, -2, "activationTypes") ;

/// hs.notify.defaultNotificationSound
/// Constant
/// The string representation of the default notification sound. Use `hs.notify:soundName()` or set the `soundName` attribute in `hs:notify.new()`, to this constant, if you want to use the default sound
    lua_pushstring(L, [NSUserNotificationDefaultSoundName UTF8String]) ; lua_setfield(L, -2, "defaultNotificationSound") ;

    [skin registerPushNSHelper:pushNSUserNotification         forClass:"NSUserNotification"];
    [skin registerLuaObjectHelper:toNSUserNotificationFromLua forClass:"NSUserNotification"
                                                   withUserdataMapping:USERDATA_TAG];

    notification_delegate_setup() ;
    ourNotificationSpecifics = [NSMutableDictionary dictionary] ;

    return 1;
}

#pragma clang diagnostic pop
