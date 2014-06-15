#import "lua/lauxlib.h"

int mouse_get(lua_State* L) {
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ourEvent);
    
    lua_pushnumber(L, p.x);
    lua_pushnumber(L, p.y);
    return 2;
}

int mouse_set(lua_State* L) {
    CGFloat x = lua_tonumber(L, 1);
    CGFloat y = lua_tonumber(L, 2);
    CGPoint p = CGPointMake(x, y);
    CGWarpMouseCursorPosition(p);
    return 0;
}
