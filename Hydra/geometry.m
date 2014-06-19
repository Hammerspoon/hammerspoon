#import "lua/lauxlib.h"

// args: [rect]
// returns: [point]
int geometry_rectmidpoint(lua_State* L) {
    CGFloat x = (lua_getfield(L, 1, "x"), lua_tonumber(L, -1));
    CGFloat y = (lua_getfield(L, 1, "y"), lua_tonumber(L, -1));
    CGFloat w = (lua_getfield(L, 1, "w"), lua_tonumber(L, -1));
    CGFloat h = (lua_getfield(L, 1, "h"), lua_tonumber(L, -1));
    
    NSRect r = NSMakeRect(x, y, w, h);
    
    lua_newtable(L);
    lua_pushnumber(L, NSMidX(r)); lua_setfield(L, -2, "x");
    lua_pushnumber(L, NSMidY(r)); lua_setfield(L, -2, "y");
    
    return 1;
}

// args: [rect]
// returns: [point]
int geometry_intersectionrect(lua_State* L) {
    CGFloat x1 = (lua_getfield(L, 1, "x"), lua_tonumber(L, -1));
    CGFloat y1 = (lua_getfield(L, 1, "y"), lua_tonumber(L, -1));
    CGFloat w1 = (lua_getfield(L, 1, "w"), lua_tonumber(L, -1));
    CGFloat h1 = (lua_getfield(L, 1, "h"), lua_tonumber(L, -1));
    
    CGFloat x2 = (lua_getfield(L, 2, "x"), lua_tonumber(L, -1));
    CGFloat y2 = (lua_getfield(L, 2, "y"), lua_tonumber(L, -1));
    CGFloat w2 = (lua_getfield(L, 2, "w"), lua_tonumber(L, -1));
    CGFloat h2 = (lua_getfield(L, 2, "h"), lua_tonumber(L, -1));
    
    NSRect r1 = NSMakeRect(x1, y1, w1, h1);
    NSRect r2 = NSMakeRect(x2, y2, w2, h2);
    NSRect r3 = NSIntersectionRect(r1, r2);
    
    lua_newtable(L);
    lua_pushnumber(L, r3.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, r3.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, r3.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, r3.size.height); lua_setfield(L, -2, "h");
    
    return 1;
}

static const luaL_Reg geometrylib[] = {
    {"intersectionrect", geometry_intersectionrect},
    {"rectmidpoint", geometry_rectmidpoint},
    {NULL, NULL}
};

int luaopen_geometry(lua_State* L) {
    luaL_newlib(L, geometrylib);
    return 1;
}
