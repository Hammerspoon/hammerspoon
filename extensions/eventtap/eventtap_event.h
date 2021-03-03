#ifndef _eventtap_event_h
#define _eventtap_event_h

@import Cocoa ;
@import Carbon ;
@import LuaSkin ;

#define EVENT_USERDATA_TAG          "hs.eventtap.event"
#define APPLICATION_USERDATA_TAG    "hs.application"
#define MODS_USERDATA_TAG           "hs.eventtap.event.modifiers"

@interface NSTouch (private)
@property (atomic, readonly) NSPoint previousNormalizedPosition ;
@property (atomic, readonly) double  timestamp ;

- (double)_force ;
@end

NSPoint hs_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = ((void)lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = ((void)lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
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
