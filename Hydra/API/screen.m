#import "helpers.h"

/// screen
///
/// Manipulate screens (i.e. monitors).
///
/// You usually get a screen through a window (see `window.screen`). But you can get screens by themselves through this module, albeit not in any defined/useful order.
///
/// Hydra's coordinate system assumes a grid that is the union of every screen's rect (see `screen.frame_including_dock_and_menu`).
///
/// Every window's position (i.e. `topleft`) and size are relative to this grid, and they're usually within the grid. A window that's semi-offscreen only intersects the grid.


#define hydra_screen(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, "screen"))


/// screen:frame(screen) -> rect
/// Returns a screen's frame in its own coordinate space.
///
/// NOTE: you probably want to use screen:frame_including_dock_and_menu() instead.
static int screen_frame(lua_State* L) {
    NSScreen* screen = hydra_screen(L, 1);
    hydra_pushrect(L, [screen frame]);
    return 1;
}

/// screen:visibleframe(screen) -> rect
/// Returns a screen's frame in its own coordinate space, without the dock or menu.
///
/// NOTE: you probably want to use screen:frame_without_dock_or_menu() instead.
static int screen_visibleframe(lua_State* L) {
    NSScreen* screen = hydra_screen(L, 1);
    hydra_pushrect(L, [screen visibleFrame]);
    return 1;
}

/// screen.settint(redarray, greenarray, bluearray)
/// Set the tint on a screen; experimental.
static int screen_settint(lua_State* L) {
    lua_len(L, 1); int red_len = lua_tonumber(L, -1);
    lua_len(L, 2); int green_len = lua_tonumber(L, -1);
    lua_len(L, 3); int blue_len = lua_tonumber(L, -1);
    
    CGGammaValue c_red[red_len];
    CGGammaValue c_green[green_len];
    CGGammaValue c_blue[blue_len];
    
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        int i = lua_tonumber(L, -2) - 1;
        c_red[i] = lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        int i = lua_tonumber(L, -2) - 1;
        c_green[i] = lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        int i = lua_tonumber(L, -2) - 1;
        c_blue[i] = lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    
    CGSetDisplayTransferByTable(CGMainDisplayID(), red_len, c_red, c_green, c_blue);
    
    return 0;
}

static int screen_gc(lua_State* L) {
    NSScreen* screen = (__bridge_transfer NSScreen*)*((void**)luaL_checkudata(L, 1, "screen"));
    screen = nil;
    return 0;
}

static int screen_eq(lua_State* L) {
    NSScreen* screenA = hydra_screen(L, 1);
    NSScreen* screenB = hydra_screen(L, 2);
    lua_pushboolean(L, [screenA isEqual: screenB]);
    return 1;
}

void new_screen(lua_State* L, NSScreen* screen) {
    void** screenptr = lua_newuserdata(L, sizeof(void*));
    *screenptr = (__bridge_retained void*)screen;
    
    luaL_getmetatable(L, "screen");
    lua_setmetatable(L, -2);
}

/// screen.allscreens() -> screen[]
/// Returns all the screens there are.
static int screen_allscreens(lua_State* L) {
    lua_newtable(L);
    
    int i = 1;
    for (NSScreen* screen in [NSScreen screens]) {
        lua_pushnumber(L, i++);
        new_screen(L, screen);
        lua_settable(L, -3);
    }
    
    return 1;
}

/// screen.mainscreen() -> screen
/// Returns the 'main' screen, i.e. the one containing the currently focused window.
static int screen_mainscreen(lua_State* L) {
    new_screen(L, [NSScreen mainScreen]);
    return 1;
}

static const luaL_Reg screenlib[] = {
    {"allscreens", screen_allscreens},
    {"mainscreen", screen_mainscreen},
    {"settint", screen_settint},
    
    {"frame", screen_frame},
    {"visibleframe", screen_visibleframe},
    
    {NULL, NULL}
};

int luaopen_screen(lua_State* L) {
    luaL_newlib(L, screenlib);
    
    if (luaL_newmetatable(L, "screen")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, screen_gc);
        lua_setfield(L, -2, "__gc");
        
        lua_pushcfunction(L, screen_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
