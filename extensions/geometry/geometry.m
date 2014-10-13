#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

static NSRect geom_torect(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 4);
    return NSMakeRect(x, y, w, h);
}

void geom_pushpoint(lua_State* L, NSPoint point) {
    lua_newtable(L);
    lua_pushnumber(L, point.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, point.y); lua_setfield(L, -2, "y");
}

static void geom_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

/// mjolnir.geometry.intersectionrect(rect1, rect2) -> rect3
/// Function
/// Returns the intersection of two rects as a new rect.
static int geometry_intersectionrect(lua_State* L) {
    NSRect r1 = geom_torect(L, 1);
    NSRect r2 = geom_torect(L, 2);
    geom_pushrect(L, NSIntersectionRect(r1, r2));
    return 1;
}

/// mjolnir.geometry.rectmidpoint(rect) -> point
/// Function
/// Returns the midpoint of a rect.
static int geometry_rectmidpoint(lua_State* L) {
    NSRect r = geom_torect(L, 1);
    geom_pushpoint(L, NSMakePoint(NSMidX(r), NSMidY(r)));
    return 1;
}


static const luaL_Reg geometrylib[] = {
    {"intersectionrect", geometry_intersectionrect},
    {"rectmidpoint", geometry_rectmidpoint},
    {NULL, NULL}
};

int luaopen_mjolnir_geometry_internal(lua_State* L) {
    luaL_newlib(L, geometrylib);
    return 1;
}
