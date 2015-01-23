#import <Cocoa/Cocoa.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <lauxlib.h>

#define get_screen_arg(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, "hs.screen"))

static void geom_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

static int screen_frame(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    geom_pushrect(L, [screen frame]);
    return 1;
}

static int screen_visibleframe(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    geom_pushrect(L, [screen visibleFrame]);
    return 1;
}

/// hs.screen:id(screen) -> number
/// Method
/// Returns a screen's unique ID.
static int screen_id(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    lua_pushnumber(L, [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] doubleValue]);
    return 1;
}

/// hs.screen:name(screen) -> string
/// Method
/// Returns the preferred name for the screen set by the manufacturer.
static int screen_name(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    CFDictionaryRef deviceInfo = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(screen_id), kIODisplayOnlyPreferredName);
    NSDictionary *localizedNames = [(__bridge NSDictionary *)deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];

    if ([localizedNames count])
        lua_pushstring(L, [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] UTF8String]);
    else
        lua_pushnil(L);

    CFRelease(deviceInfo);

    return 1;
}

/// hs.screen.setTint(redarray, greenarray, bluearray)
/// Function
/// Set the tint on a screen; experimental.
static int screen_setTint(lua_State* L) {
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
    NSScreen* screen __unused = get_screen_arg(L, 1);
    return 0;
}

static int screen_eq(lua_State* L) {
    NSScreen* screenA = get_screen_arg(L, 1);
    NSScreen* screenB = get_screen_arg(L, 2);
    lua_pushboolean(L, [screenA isEqual: screenB]);
    return 1;
}

void new_screen(lua_State* L, NSScreen* screen) {
    void** screenptr = lua_newuserdata(L, sizeof(NSScreen**));
    *screenptr = (__bridge_retained void*)screen;

    luaL_getmetatable(L, "hs.screen");
    lua_setmetatable(L, -2);
}

/// hs.screen.allScreens() -> screen[]
/// Constructor
/// Returns all the screens there are.
static int screen_allScreens(lua_State* L) {
    lua_newtable(L);

    int i = 1;
    for (NSScreen* screen in [NSScreen screens]) {
        lua_pushnumber(L, i++);
        new_screen(L, screen);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.screen.mainScreen() -> screen
/// Constructor
/// Returns the 'main' screen, i.e. the one containing the currently focused window.
static int screen_mainScreen(lua_State* L) {
    new_screen(L, [NSScreen mainScreen]);
    return 1;
}

/// hs.screen:setPrimary(screen) -> nil
/// Function
/// Sets the screen to be the primary display (i.e. contain the menubar and dock)
static int screen_setPrimary(lua_State* L) {
    int deltaX, deltaY;

    CGDisplayErr dErr;
    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;
    CGDirectDisplayID  onlineDisplays[maxDisplays];
    CGDisplayConfigRef config;

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID targetDisplay = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    CGDirectDisplayID mainDisplay = CGMainDisplayID();

    if (targetDisplay == mainDisplay)
        return 0;

    dErr = CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount);
    if (dErr != kCGErrorSuccess) {
        // FIXME: Display some kind of error here
        return 0;
    }

    deltaX = -CGRectGetMinX(CGDisplayBounds(targetDisplay));
    deltaY = -CGRectGetMinY(CGDisplayBounds(targetDisplay));

    CGBeginDisplayConfiguration (&config);

    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];

        CGConfigureDisplayOrigin(config, dID,
                                 CGRectGetMinX(CGDisplayBounds(dID)) + deltaX,
                                 CGRectGetMinY(CGDisplayBounds(dID)) + deltaY
                                );
    }

    CGCompleteDisplayConfiguration (config, kCGConfigureForSession);

    return 0;
}

static const luaL_Reg screenlib[] = {
    {"allScreens", screen_allScreens},
    {"mainScreen", screen_mainScreen},
    {"setTint", screen_setTint},
    {"setPrimary", screen_setPrimary},

    {"_frame", screen_frame},
    {"_visibleframe", screen_visibleframe},
    {"id", screen_id},
    {"name", screen_name},

    {NULL, NULL}
};

int luaopen_hs_screen_internal(lua_State* L) {
    luaL_newlib(L, screenlib);

    if (luaL_newmetatable(L, "hs.screen")) {
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
