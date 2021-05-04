@import Foundation;
@import Cocoa;
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.distributednotifications"

static LSRefTable refTable = LUA_NOREF;

typedef struct _distnot_t {
    void *watcher;
} distnot_t;

#pragma mark - HSDistNotWatcher Definition

@interface HSDistNotWatcher : NSObject
@property int fnRef ;
@property (copy, nonatomic) NSString *object;
@property (copy, nonatomic) NSString *name;
@end

@implementation HSDistNotWatcher

- (void)callback:(NSNotification *)note {
    if (self.fnRef != LUA_NOREF && self.fnRef != LUA_REFNIL) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.fnRef];
        [skin pushNSObject:note.name];
        [skin pushNSObject:note.object];
        [skin pushNSObject:note.userInfo];
        [skin protectedCallAndError:@"hs.distributednotification callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

@end

#pragma mark - Module Functions

/// hs.distributednotifications.new(callback[, name[, object]]) -> object
/// Constructor
/// Creates a new NSDistributedNotificationCenter watcher
///
/// Parameters:
///  * callback - A function to be called when a matching notification arrives. The function should accept one argument:
///   * notificationName - A string containing the name of the notification
///  * name - An optional string containing the name of notifications to watch for. A value of `nil` will cause all notifications to be watched on macOS versions earlier than Catalina. Defaults to `nil`.
///  * object - An optional string containing the name of sending objects to watch for. A value of `nil` will cause all sending objects to be watched. Defaults to `nil`.
///
/// Returns:
///  * An `hs.distributednotifications` object
///
/// Notes:
///  * On Catalina and above, it is no longer possible to observe all notifications - the `name` parameter is effectively now required. See https://mjtsai.com/blog/2019/10/04/nsdistributednotificationcenter-no-longer-supports-nil-names/
static int distnot_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING|LS_TNIL|LS_TOPTIONAL, LS_TSTRING|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    NSString *name = lua_isnoneornil(L, 2) ? nil : [skin toNSObjectAtIndex:2];
    NSString *obj  = lua_isnoneornil(L, 3) ? nil : [skin toNSObjectAtIndex:3];

    distnot_t *userData = lua_newuserdata(L, sizeof(distnot_t));
    memset(userData, 0, sizeof(distnot_t));

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    HSDistNotWatcher *watcher = [[HSDistNotWatcher alloc] init];
    userData->watcher = (__bridge_retained void*)watcher;

    lua_pushvalue(L, 1);
    watcher.fnRef = [skin luaRef:refTable];
    watcher.name = name;
    watcher.object = obj;

    return 1;
}

#pragma mark - Module Methods

/// hs.distributednotifications.post(name[, sender[, userInfo]])
/// Function
/// Sends a distributed notification
///
/// Parameters:
///  * name - A string containing the name of the notification
///  * sender - An optional string containing the name of the sender of the notification (in the form `com.domain.application.foo`). Defaults to nil.
///  * userInfo - An optional table containing additional information to post with the notification. Defaults to nil.
///
/// Returns:
///  * None
static int distnot_post(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    NSString *object;
    NSDictionary *userInfo;

    if (lua_isnoneornil(L, 2)) {
        object = nil;
    } else {
        object = [skin toNSObjectAtIndex:2];
    }

    if (lua_isnoneornil(L, 3)) {
        userInfo = nil;
    } else {
        userInfo = [skin toNSObjectAtIndex:3];
    }

    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center postNotificationName:[skin toNSObjectAtIndex:1] object:object userInfo:userInfo deliverImmediately:YES];

    return 0;
}

#pragma mark - Module Methods

/// hs.distributednotifications:start() -> object
/// Method
/// Starts a NSDistributedNotificationCenter watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.distributednotifications` object
static int distnot_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    distnot_t *userData = lua_touserdata(L, 1);
    HSDistNotWatcher *watcher = (__bridge HSDistNotWatcher *)userData->watcher;

    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center addObserver:watcher selector:@selector(callback:) name:watcher.name object:watcher.object suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.distributednotifications:stop() -> object
/// Method
/// Stops a NSDistributedNotificationCenter watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.distributednotifications` object
static int distnot_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    distnot_t *userData = lua_touserdata(L, 1);
    HSDistNotWatcher *watcher = (__bridge HSDistNotWatcher *)userData->watcher;

    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center removeObserver:watcher name:watcher.name object:watcher.object];

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    distnot_t *userData = lua_touserdata(L, 1);
    HSDistNotWatcher *watcher = (__bridge HSDistNotWatcher *)userData->watcher;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: name: %@ object: %@ (%p)", USERDATA_TAG, watcher.name, watcher.object, (void *)watcher]];
    return 1;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    distnot_t *userData = lua_touserdata(L, 1);
    HSDistNotWatcher *watcher = (__bridge_transfer HSDistNotWatcher *)userData->watcher;

    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center removeObserver:watcher name:watcher.name object:watcher.object];

    watcher.fnRef = [skin luaUnref:refTable ref:watcher.fnRef];
    watcher = nil;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);

    return 0;
}

static const luaL_Reg distributednotificationslib[] = {
    {"new", distnot_new},
    {"post", distnot_post},

    {NULL, NULL}
};

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"start", distnot_start},
    {"stop", distnot_stop},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_distributednotifications_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:distributednotificationslib metaFunctions:nil];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    return 1;
}
