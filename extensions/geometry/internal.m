#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

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

/// hs.geometry.intersectionRect(rect-table1, rect-table2) -> rect-table
/// Function
/// Returns the intersection of two rects as a new rect
///
/// Parameters:
///  * rect-table1 - The first rect-table used to determine an intersection
///  * rect-table2 - The second rect-table used to determine an intersection
///
/// Returns:
///  * A rect-table describing the intersection. If there is no intersection, all values in this table will be zero
static int geometry_intersectionRect(lua_State* L) {
    NSRect r1 = geom_torect(L, 1);
    NSRect r2 = geom_torect(L, 2);
    geom_pushrect(L, NSIntersectionRect(r1, r2));
    return 1;
}

/// hs.geometry.rectMidPoint(rect) -> point
/// Function
/// Returns the midpoint of a rect
///
/// Parameters:
///  * rect - A rect-table to determine the mid-point of
///
/// Returns:
///  * A point-table containing the location of the middle of the rect
static int geometry_rectMidPoint(lua_State* L) {
    NSRect r = geom_torect(L, 1);
    geom_pushpoint(L, NSMakePoint(NSMidX(r), NSMidY(r)));
    return 1;
}


static const luaL_Reg geometrylib[] = {
    {"intersectionRect", geometry_intersectionRect},
    {"rectMidPoint", geometry_rectMidPoint},
    {NULL, NULL}
};

int luaopen_hs_geometry_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:geometrylib metaFunctions:nil];

    return 1;
}
