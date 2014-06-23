#import "api.h"

int mouse_get(lua_State* L) {
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ourEvent);
    
    lua_newtable(L);
    lua_pushnumber(L, p.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, p.y); lua_setfield(L, -2, "y");
    return 1;
}

int mouse_set(lua_State* L) {
    CGFloat x = (lua_getfield(L, 1, "x"), lua_tonumber(L, -1));
    CGFloat y = (lua_getfield(L, 1, "y"), lua_tonumber(L, -1));
    
    CGPoint p = CGPointMake(x, y);
    CGWarpMouseCursorPosition(p);
    return 0;
}

static const luaL_Reg mouselib[] = {
    {"get", mouse_get},
    {"set", mouse_set},
    {NULL, NULL}
};

int luaopen_mouse(lua_State* L) {
    luaL_newlib(L, mouselib);
    return 1;
}
