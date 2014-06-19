#import "lua/lauxlib.h"

int geometry_rectmidpoint(lua_State* L) {
    CGFloat x = lua_tonumber(L, 1);
    CGFloat y = lua_tonumber(L, 2);
    CGFloat w = lua_tonumber(L, 3);
    CGFloat h = lua_tonumber(L, 4);
    
    NSRect r = NSMakeRect(x, y, w, h);
    lua_pushnumber(L, NSMidX(r));
    lua_pushnumber(L, NSMidY(r));
    return 2;
}

int geometry_rectintersection(lua_State* L) {
    CGFloat x1 = lua_tonumber(L, 1);
    CGFloat y1 = lua_tonumber(L, 2);
    CGFloat w1 = lua_tonumber(L, 3);
    CGFloat h1 = lua_tonumber(L, 4);
    
    CGFloat x2 = lua_tonumber(L, 5);
    CGFloat y2 = lua_tonumber(L, 6);
    CGFloat w2 = lua_tonumber(L, 7);
    CGFloat h2 = lua_tonumber(L, 8);
    
    NSRect r1 = NSMakeRect(x1, y1, w1, h1);
    NSRect r2 = NSMakeRect(x2, y2, w2, h2);
    NSRect r3 = NSIntersectionRect(r1, r2);
    
    lua_pushnumber(L, r3.origin.x);
    lua_pushnumber(L, r3.origin.y);
    lua_pushnumber(L, r3.size.width);
    lua_pushnumber(L, r3.size.height);
    return 4;
}
