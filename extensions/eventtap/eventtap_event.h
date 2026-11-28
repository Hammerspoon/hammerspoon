#ifndef _eventtap_event_h
#define _eventtap_event_h

@import Cocoa ;
@import Carbon ;
@import LuaSkin ;

#include "IOHIDEvent.h"

#define EVENT_USERDATA_TAG          "hs.eventtap.event"
#define IOHIDEVENT_USERDATA_TAG     "hs.eventtap.iohidevent"
#define APPLICATION_USERDATA_TAG    "hs.application"
#define MODS_USERDATA_TAG           "hs.eventtap.event.modifiers"

@interface NSTouch (private)
@property (atomic, readonly) NSPoint previousNormalizedPosition ;
@property (atomic, readonly) double  timestamp ;

- (double)_force ;
@end

static inline NSPoint hs_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = ((void)lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = ((void)lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}


static inline CGEventRef hs_to_eventtap_event(lua_State* L, int idx) {
    return *(CGEventRef*)luaL_checkudata(L, idx, EVENT_USERDATA_TAG);
}

static inline void new_eventtap_event(lua_State* L, CGEventRef event) {
    CFRetain(event);
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;

    luaL_getmetatable(L, EVENT_USERDATA_TAG);
    lua_setmetatable(L, -2);
}

void new_eventtap_iohidevent(lua_State *L, IOHIDEventRef event) {
    CFRetain(event);
    *(IOHIDEventRef*)lua_newuserdata(L, sizeof(IOHIDEventRef*)) = event;

    luaL_getmetatable(L, IOHIDEVENT_USERDATA_TAG);
    lua_setmetatable(L, -2);
}

#endif
