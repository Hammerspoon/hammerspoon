@import Foundation;
@import Cocoa;
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.distributednotifications"

static int refTable = LUA_NOREF;

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
    NSLog(@"In callback for %@", note.name);
    if (self.fnRef != LUA_NOREF && self.fnRef != LUA_REFNIL) {
        LuaSkin *skin = [LuaSkin shared];
        [skin pushLuaRef:refTable ref:self.fnRef];
        [skin pushNSObject:note.name];
        [skin pushNSObject:note.object];
        [skin pushNSObject:note.userInfo];
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            NSLog(@"ERROR: %@", [skin toNSObjectAtIndex:-1]); // FIXME: Turn into proper logging
        }
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
///  * name - An optional string containing the name of notifications to watch for. A value of `nil` will cause all notifications to be watched. Defaults to `nil`.
///  * object - An optional string containing the name of sending objects to watch for. A value of `nil` will cause all sending objects to be watched. Defaults to `nil`.
///
/// Returns:
///  * An `hs.distributednotifications` object
static int distnot_new(lua_State *L) {
    NSLog(@"in distnot_new");
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TFUNCTION, LS_TSTRING|LS_TNIL|LS_TOPTIONAL, LS_TSTRING|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    distnot_t *userData = lua_newuserdata(L, sizeof(distnot_t));
    memset(userData, 0, sizeof(distnot_t));

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    HSDistNotWatcher *watcher = [[HSDistNotWatcher alloc] init];
    userData->watcher = (__bridge_retained void*)watcher;

    lua_pushvalue(L, 1);
    watcher.fnRef = [skin luaRef:refTable];
    watcher.name = [skin toNSObjectAtIndex:2];
    watcher.object = [skin toNSObjectAtIndex:3];

    return 1;
}

#pragma mark - Module Methods

static int distnot_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    distnot_t *userData = lua_touserdata(L, 1);
    HSDistNotWatcher *watcher = (__bridge HSDistNotWatcher *)userData->watcher;

    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center addObserver:watcher selector:@selector(callback:) name:watcher.name object:watcher.object];

    lua_pushvalue(L, 1);
    return 1;
}

static int distnot_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin pushNSObject:@"LOL NOT YET"];
    return 1;
}

static int userdata_gc(lua_State* L) {
//    HSdistributednotificationsScan *scanner = get_objectFromUserdata(__bridge_transfer HSdistributednotificationsScan, L, 1);
//    LuaSkin *skin = [LuaSkin shared];
//
//    scanner.fnRef = [skin luaUnref:refTable ref:scanner.fnRef];
//
// Remove the Metatable so future use of the variable in Lua won't think its valid
//    lua_pushnil(L);
//    lua_setmetatable(L, 1);

    return 0;
}

// static int distributednotifications_gc(lua_State* L __unused) {
//     return 0;
// }

static const luaL_Reg distributednotificationslib[] = {
    {"new", distnot_new},

    {NULL, NULL}
};

// static const luaL_Reg metalib[] = {
//     {"__gc", distributednotifications_gc},
//
//     {NULL, NULL}
// };

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"start", distnot_start},
    {"stop", distnot_stop},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_distributednotifications_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:distributednotificationslib
                                 metaFunctions:nil // metalib
                               objectFunctions:userdata_metaLib];

    return 1;
}

// #pragma clang diagnostic pop

