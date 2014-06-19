#import "lua/lauxlib.h"

int screen_gc(lua_State* L) {
    void** screenptr = lua_touserdata(L, 1);
    NSScreen* screen = (__bridge_transfer NSScreen*)*screenptr;
    screen = nil;
    return 0;
}

void screen_push_screen_as_userdata(lua_State* L, NSScreen* screen) {
    void** screenptr = lua_newuserdata(L, sizeof(void*));
    *screenptr = (__bridge_retained void*)screen;
    // [ud]

    if (luaL_newmetatable(L, "screen"))
        // [ud, md]
    {
        lua_pushcfunction(L, screen_gc); // [ud, md, gc]
        lua_setfield(L, -2, "__gc");     // [ud, md]
    }
    // [ud, md]
    
    lua_setmetatable(L, -2);
    // [ud]
}

int screen_get_screens(lua_State* L) {
    lua_newtable(L); // [{}]
    
    int i = 1;
    for (NSScreen* screen in [NSScreen screens]) {
        lua_pushnumber(L, i++);                    // [{}, i]
        screen_push_screen_as_userdata(L, screen); // [{}, i, ud]
        lua_settable(L, -3);                       // [{}]
    }
    
    return 1;
}

int screen_get_main_screen(lua_State* L) {
    screen_push_screen_as_userdata(L, [NSScreen mainScreen]);
    return 1;
}

int screen_frame(lua_State* L) {
    NSScreen* screen = (__bridge NSScreen*)*((void**)lua_touserdata(L, 1));
    
    NSRect r = [screen frame];
    lua_pushnumber(L, r.origin.x);
    lua_pushnumber(L, r.origin.y);
    lua_pushnumber(L, r.size.width);
    lua_pushnumber(L, r.size.height);
    return 4;
}

int screen_visible_frame(lua_State* L) {
    NSScreen* screen = (__bridge NSScreen*)*((void**)lua_touserdata(L, 1));
    
    NSRect r = [screen visibleFrame];
    lua_pushnumber(L, r.origin.x);
    lua_pushnumber(L, r.origin.y);
    lua_pushnumber(L, r.size.width);
    lua_pushnumber(L, r.size.height);
    return 4;
}

int screen_equals(lua_State* L) {
    NSScreen* screenA = (__bridge NSScreen*)*((void**)lua_touserdata(L, 1));
    NSScreen* screenB = (__bridge NSScreen*)*((void**)lua_touserdata(L, 2));
    return [screenA isEqual: screenB];
}

int screen_set_tint(lua_State* L) {
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

int luaopen_screen(lua_State* L) { return 0; }
