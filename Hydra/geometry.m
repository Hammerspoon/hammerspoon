#import "hydra.h"

static hydradoc doc_geometry_intersectionrect = {
    "geometry", "intersectionrect", "geometry.intersectionrect(rect1, rect2) -> rect3",
    "Returns the intersection of two rects as a new rect."
};

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
    {NULL, NULL}
};

int luaopen_geometry(lua_State* L) {
    hydra_add_doc_group(L, "geometry", "Mathy stuff.");
    hydra_add_doc_item(L, &doc_geometry_intersectionrect);
    
    luaL_newlib(L, geometrylib);
    return 1;
}
