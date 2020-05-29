//
//  HSuielementwatcher.m
//  Hammerspoon
//
//  Created by Chris Jones on 12/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

@import LuaSkin;

#import "HSuicore.h"

static const char* USERDATA_TAG = "hs.uielement.watcher";
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

/*
 CMSJ: I don't remember why I added this in the refactor of hs.application/window/uielement, but it's not needed, so I'm leaving it commented for now (mid-2020), on the assumption it can be removed later.
/// hs.uielement.watcher.new(element, callback[, userdata]) -> hs.uielement.watcher object
/// Function
/// Creates a new hs.uielement.watcher object for a given hs.uielement object
///
/// Paramters:
///  * element - An hs.uielement object
///  * callback - A function that will be called when events happen on the hs.uielement object. The function should accept four arguments:
///   * element - The element the event occurred on (which may not be the element being watched)
///   * event - A string containing the name of the event
///   * watcher - The hs.uielement.watcher object
///   * userdata - Some data you want to send along to the callback. This can be of any type
///
/// Returns:
///  * An hs.uielement.watcher object
static int watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, "hs.uielement", LS_TFUNCTION, LS_TANY|LS_TOPTIONAL, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    int callbackRef = [skin luaRef:refTable atIndex:2];
    int userdataRef = LUA_NOREF;
    if (lua_type(L, 3) != LUA_TNONE) {
        userdataRef = [skin luaRef:refTable atIndex:3];
    }

    // FIXME move reftable to an argument for newWatcher
    HSuielementWatcher *watcher = [element newWatcher:callbackRef withUserdata:userdataRef];
    watcher.refTable = refTable;
    [skin pushNSObject:watcher];
    return 1;
}
*/

static int watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    [watcher start:[skin toNSObjectAtIndex:2] withState:L];
    lua_pushvalue(L, 1);
    return 1;
}

static int watcher_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    [watcher stop];
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSuielementWatcher(lua_State *L, id obj) {
    HSuielementWatcher *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSuielementWatcher *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSuielementWatcherFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSuielementWatcher *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSuielementWatcher, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    lua_pushstring(L, [NSString stringWithFormat:@"%s: %p", USERDATA_TAG, lua_topointer(L, 1)].UTF8String);
    return 1 ;
}

static int userdata_eq(lua_State *L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSuielementWatcher *watcher1 = [skin toNSObjectAtIndex:1];
        HSuielementWatcher *watcher2 = [skin toNSObjectAtIndex:2];
        isEqual = [watcher1 isEqual:watcher2];
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

// Perform cleanup if the watcher is not required anymore.
static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = get_objectFromUserdata(__bridge_transfer HSuielementWatcher, L, 1, USERDATA_TAG);
    if (watcher) {
        watcher.selfRefCount--;
        if (watcher.selfRefCount == 0) {
            [watcher stop];
            watcher.handlerRef = [skin luaUnref:watcher.refTable ref:watcher.handlerRef];
            watcher.userDataRef = [skin luaUnref:watcher.refTable ref:watcher.userDataRef];
            watcher = nil;
        }
    }
    return 0;
}

static const luaL_Reg moduleLib[] = {
    //{"newWatcher", watcher_new},

    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

static const luaL_Reg userdata_metaLib[] = {
    {"_start", watcher_start},
    {"_stop", watcher_stop},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},

    {NULL, NULL}
};

int luaopen_hs_uielement_watcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSuielementWatcher
                      forClass:"HSuielementWatcher"];

    [skin registerLuaObjectHelper:toHSuielementWatcherFromLua
                         forClass:"HSuielementWatcher"
              withUserdataMapping:USERDATA_TAG];

    return 1;
}
