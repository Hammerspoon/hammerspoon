#import "helpers.h"

static hydradoc doc_geometry_intersectionrect = {
    "geometry", "intersectionrect", "geometry.intersectionrect(rect1, rect2) -> rect3",
    "Returns the intersection of two rects as a new rect."
};

static int geometry_intersectionrect(lua_State* L) {
    NSRect r1 = hydra_torect(L, 1);
    NSRect r2 = hydra_torect(L, 2);
    hydra_pushrect(L, NSIntersectionRect(r1, r2));
    return 1;
}

static hydradoc doc_geometry_rectmidpoint = {
    "geometry", "rectmidpoint", "geometry.rectmidpoint(rect) -> point",
    "Returns the midpoint of a rect."
};

static int geometry_rectmidpoint(lua_State* L) {
    NSRect r = hydra_torect(L, 1);
    hydra_pushpoint(L, NSMakePoint(NSMidX(r), NSMidY(r)));
    return 1;
}

static const luaL_Reg geometrylib[] = {
    {"intersectionrect", geometry_intersectionrect},
    {"rectmidpoint", geometry_rectmidpoint},
    {NULL, NULL}
};

int luaopen_geometry(lua_State* L) {
    hydra_add_doc_group(L, "geometry", "Mathy stuff.");
    hydra_add_doc_item(L, &doc_geometry_intersectionrect);
    hydra_add_doc_item(L, &doc_geometry_rectmidpoint);
    
    luaL_newlib(L, geometrylib);
    return 1;
}
