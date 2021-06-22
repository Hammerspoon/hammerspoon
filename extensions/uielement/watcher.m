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
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

// This is wrapped, and documented, in init.lua
static int watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    watcher.watcherRef = [skin luaRef:LUA_REGISTRYINDEX atIndex:1];
    [watcher start:[skin toNSObjectAtIndex:2] withState:L];
    lua_pushvalue(L, 1);
    return 1;
}

// This is wrapped, and documented, in init.lua
static int watcher_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    [watcher stop];
    watcher.watcherRef = [skin luaUnref:LUA_REGISTRYINDEX ref:watcher.watcherRef];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.uielement.watcher:pid() -> number
/// Method
/// Returns the PID of the element being watched
///
/// Parameters:
///  * None
///
/// Returns:
///  * The PID of the element being watched
static int watcher_pid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    lua_pushnumber(L, watcher.pid);
    return 1;
}

/// hs.uielement.watcher:element() -> object
/// Method
/// Returns the element the watcher is watching.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The element the watcher is watching.
static int watcher_element(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    HSuielement *element = [[HSuielement alloc] initWithElementRef:watcher.elementRef];

    if (element.isWindow) {
        HSwindow *window = [[HSwindow alloc] initWithAXUIElementRef:watcher.elementRef];
        [skin pushNSObject:window];
    } else if (element.isApplication) {
        HSapplication *application = [[HSapplication alloc] initWithPid:watcher.pid withState:L];
        [skin pushNSObject:application];
    } else {
        [skin pushNSObject:element];
    }
    return 1;
}

// This is internal API only and does not require documentation
static int watcher_watchDestroyed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];

    if (lua_type(L, LS_TBOOLEAN)) {
        watcher.watchDestroyed = lua_toboolean(L, 2);
        lua_pushvalue(L, 1);
    } else {
        lua_pushboolean(L, watcher.watchDestroyed);
    }

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
        LSGCCanary tmplsCanary = watcher.lsCanary;
        [skin destroyGCCanary:&tmplsCanary];
        watcher.lsCanary = tmplsCanary;

        watcher.selfRefCount--;
        if (watcher.selfRefCount == 0) {
            [watcher stop];
            watcher.handlerRef = [skin luaUnref:watcher.refTable ref:watcher.handlerRef];
            watcher.userDataRef = [skin luaUnref:watcher.refTable ref:watcher.userDataRef];
            watcher = nil;
        }
    }
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0;
}

static const luaL_Reg moduleLib[] = {
    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

static const luaL_Reg userdata_metaLib[] = {
    {"_start", watcher_start},
    {"_stop", watcher_stop},
    {"pid", watcher_pid},
    {"element", watcher_element},
    {"watchDestroyed", watcher_watchDestroyed},

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
