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







//int misc_set_tint(lua_State* L) {
//    // args: NSArray *red, NSArray *green, NSArray *blue
//
//    CGGammaValue cred[red.count];
//    for (int i = 0; i < red.count; ++i) {
//        cred[i] = [[red objectAtIndex:i] floatValue];
//    }
//    CGGammaValue cgreen[green.count];
//    for (int i = 0; i < green.count; ++i) {
//        cgreen[i] = [[green objectAtIndex:i] floatValue];
//    }
//    CGGammaValue cblue[blue.count];
//    for (int i = 0; i < blue.count; ++i) {
//        cblue[i] = [[blue objectAtIndex:i] floatValue];
//    }
//    CGSetDisplayTransferByTable(CGMainDisplayID(), (int)sizeof(cred) / sizeof(cred[0]), cred, cgreen, cblue);
//
//    return 0;
//}
