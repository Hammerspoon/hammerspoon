#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

static NSPoint hammerspoon_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}

static void hammerspoon_pushpoint(lua_State* L, NSPoint point) {
    lua_newtable(L);
    lua_pushnumber(L, point.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, point.y); lua_setfield(L, -2, "y");
}

/// hs.mouse.get() -> point
/// Function
/// Get the current location of the mouse pointer
///
/// Parameters:
///  * None
///
/// Returns:
///  * A point-table containing the x and y co-ordinates of the mouse pointer
///
/// Notes:
///  * The co-ordinates returned by this function are in relation to the full size of your desktop. If you have multiple monitors, the desktop is a large virtual rectangle that contains them all (e.g. if you have two 1920x1080 monitors and the mouse is in the middle of the second monitor, the returned table would be `{ x=2879, y=540 }`)
///  * Multiple monitors of different sizes can cause the co-ordinates of some areas of the desktop to be negative. This is perfectly normal. 0,0 in the co-ordinates of the desktop is the top left of the primary monitor
static int mouse_get(lua_State* L) {
    CGEventRef ourEvent = CGEventCreate(NULL);
    hammerspoon_pushpoint(L, CGEventGetLocation(ourEvent));
    CFRelease(ourEvent);
    return 1;
}

/// hs.mouse.set(point)
/// Function
/// Move the mouse pointer
///
/// Parameters:
///  * point - A point-table containing the x and y co-ordinates to move the mouse pointer to
///
/// Returns:
///  * None
///
/// Notes:
///  * The co-ordinates given to this function must be in relation to the full size of your desktop. See the notes for `hs.mouse.get` for more information
static int mouse_set(lua_State* L) {
    CGWarpMouseCursorPosition(hammerspoon_topoint(L, 1));
    return 0;
}

static const luaL_Reg mouseLib[] = {
    {"get", mouse_get},
    {"set", mouse_set},
    {NULL, NULL}
};

int luaopen_hs_mouse_internal(lua_State* L) {
    luaL_newlib(L, mouseLib);
    return 1;
}


