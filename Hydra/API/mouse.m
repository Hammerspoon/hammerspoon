#import "helpers.h"

/// === mouse ===
///
/// Functions for manipulating the mouse cursor.



/// mouse.get() -> point
/// Returns the current location of the mouse on the current screen as a point.
static int mouse_get(lua_State* L) {
    CGEventRef ourEvent = CGEventCreate(NULL);
    hydra_pushpoint(L, CGEventGetLocation(ourEvent));
    CFRelease(ourEvent);
    return 1;
}

/// mouse.set(point)
/// Moves the mouse to the given location on the current screen.
static int mouse_set(lua_State* L) {
    CGWarpMouseCursorPosition(hydra_topoint(L, 1));
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
