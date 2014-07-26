#import "helpers.h"

void new_eventtap_event(lua_State* L, CGEventRef event) {
    CFRetain(event);
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;
    
    luaL_getmetatable(L, "eventtap_event");
    lua_setmetatable(L, -2);
}

static int eventtap_event_gc(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CFRelease(event);
    return 0;
}

static int eventtap_event_copy(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    
    CGEventRef copy = CGEventCreateCopy(event);
    new_eventtap_event(L, copy);
    CFRelease(copy);
    
    return 1;
}

static luaL_Reg eventtapeventlib[] = {
    // module methods
    
    // instance methods
    {"copy", eventtap_event_copy},
    
    // metamethods
    {"__gc", eventtap_event_gc},
    
    {}
};

int luaopen_eventtap_event(lua_State* L) {
    luaL_newlib(L, eventtapeventlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "eventtap_event");
    
    return 1;
}
