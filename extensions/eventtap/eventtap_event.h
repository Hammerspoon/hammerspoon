#ifndef _eventtap_event_h
#define _eventtap_event_h

#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define EVENT_USERDATA_TAG  "hs.eventtap.event"
#define MODS_USERDATA_TAG   "hs.eventtap.event.modifiers"

NSPoint hs_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}


CGEventRef hs_to_eventtap_event(lua_State* L, int idx) {
    return *(CGEventRef*)luaL_checkudata(L, idx, EVENT_USERDATA_TAG);
}

void new_eventtap_event(lua_State* L, CGEventRef event) {
    CFRetain(event);
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;

    luaL_getmetatable(L, EVENT_USERDATA_TAG);
    lua_setmetatable(L, -2);
}

#endif
