#import "HSuicore.h"
#import "eventtap_event.h"
#include "IOHIDEvent.h"

static int eventtap_iohidevent_newEventFromData(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSData *data = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;

    IOHIDEventRef event = IOHIDEventCreateWithData(NULL, (__bridge CFDataRef)data);
    if (event) {
        new_eventtap_iohidevent(L, event);
        CFRelease(event);
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

static int eventtap_iohidevent_asData(lua_State* L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    CFDataRef data = IOHIDEventCreateData(NULL, event) ;
    if (data) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:(__bridge_transfer NSData *)data] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int eventtap_iohidevent_dump(lua_State* L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    CFStringRef description = IOHIDEventCopyDescription(event) ;
    if (description) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:(__bridge_transfer NSString *)description] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int eventtap_iohidevent_getType(lua_State* L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    lua_pushinteger(L, IOHIDEventGetType(event));
    return 1;
}

static int eventtap_iohidevent_getFlags(lua_State* L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    lua_pushinteger(L, IOHIDEventGetEventFlags(event));
    return 1;
}

static int eventtap_iohidevent_setFlags(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IOHIDEVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventSetEventFlags(event, (uint32_t)lua_tointeger(L, 2));
    return 1;
}

static int eventtap_iohidevent_getChildren(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    CFArrayRef children = IOHIDEventGetChildren(event);
    if (children) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        lua_newtable(L);
        for (CFIndex i = 0; i < CFArrayGetCount(children); i++) {
            IOHIDEventRef child = (IOHIDEventRef) CFArrayGetValueAtIndex(children, i);
            new_eventtap_iohidevent(L, child);
            lua_rawseti(L, -2, i + 1);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int eventtap_iohidevent_addChild(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IOHIDEVENT_USERDATA_TAG, LS_TUSERDATA, IOHIDEVENT_USERDATA_TAG, LS_TBREAK] ;
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventRef newChild = *(IOHIDEventRef*)luaL_checkudata(L, 2, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventAppendEvent(event, newChild, 0);
    return 1;
}

static int eventtap_iohidevent_removeChild(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, IOHIDEVENT_USERDATA_TAG, LS_TUSERDATA, IOHIDEVENT_USERDATA_TAG, LS_TBREAK] ;
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventRef newChild = *(IOHIDEventRef*)luaL_checkudata(L, 2, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventRemoveEvent(event, newChild, 0);
    return 1;
}

static int eventtap_iohidevent_gc(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    if (event)
        CFRelease(event);
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0;
}

static int eventtap_iohidevent_getIntProperty(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventField field = (IOHIDEventField)(luaL_checkinteger(L, 2));
    lua_pushinteger(L, IOHIDEventGetIntegerValue(event, field));
    return 1;
}

static int eventtap_iohidevent_setIntProperty(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventField field = (IOHIDEventField)(luaL_checkinteger(L, 2));
    IOHIDEventSetIntegerValue(event, field, lua_tointeger(L, 3));
    return 1;
}

static int eventtap_iohidevent_getFloatProperty(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventField field = (IOHIDEventField)(luaL_checkinteger(L, 2));
    lua_pushnumber(L, IOHIDEventGetFloatValue(event, field));
    return 1;
}

static int eventtap_iohidevent_setFloatProperty(lua_State *L) {
    IOHIDEventRef event = *(IOHIDEventRef*)luaL_checkudata(L, 1, IOHIDEVENT_USERDATA_TAG);
    IOHIDEventField field = (IOHIDEventField)(luaL_checkinteger(L, 2));
    IOHIDEventSetFloatValue(event, field, lua_tonumber(L, 3));
    return 1;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg eventtapiohidevent_metalib[] = {
    {"asData", eventtap_iohidevent_asData},
    {"dump", eventtap_iohidevent_dump},
    {"getType", eventtap_iohidevent_getType},
    {"getFlags", eventtap_iohidevent_getFlags},
    {"setFlags", eventtap_iohidevent_setFlags},
    {"getIntProperty", eventtap_iohidevent_getIntProperty},
    {"setIntProperty", eventtap_iohidevent_setIntProperty},
    {"getFloatProperty", eventtap_iohidevent_getFloatProperty},
    {"setFloatProperty", eventtap_iohidevent_setFloatProperty},
    {"getChildren", eventtap_iohidevent_getChildren},
    {"addChild", eventtap_iohidevent_addChild},
    {"removeChild", eventtap_iohidevent_removeChild},
    {"__gc", eventtap_iohidevent_gc},
    {NULL, NULL},
};

// Functions for returned object when module loads
static luaL_Reg eventtapiohideventlib[] = {
//    {"newEvent", eventtap_iohidevent_newEvent},
    {"newEventFromData", eventtap_iohidevent_newEventFromData},
    {NULL, NULL},
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_libeventtapiohidevent(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibraryWithObject:IOHIDEVENT_USERDATA_TAG functions:eventtapiohideventlib metaFunctions:meta_gcLib objectFunctions:eventtapiohidevent_metalib];
    return 1;
}
