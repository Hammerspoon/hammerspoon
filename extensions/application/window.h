#ifndef Window_application_h
#define Window_application_h

#import <Foundation/Foundation.h>
#import <lua.h>

static void new_window(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;
    
    luaL_getmetatable(L, "mjolnir.window");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_setuservalue(L, -2);
}

#endif
