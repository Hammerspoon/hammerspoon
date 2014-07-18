#import "helpers.h"
#import "HDTextGridController.h"

/// === textgrid ===
///
/// Super easy in-Hydra GUI windows.



#define hydra_textgrid(L, idx) (__bridge HDTextGridController*)*((void**)luaL_checkudata(L, idx, "textgrid"))

// TODO: make this accept an optional 2 more digits for alpha <3
static NSColor* HDColorFromHex(const char* hex) {
    static NSMutableDictionary* colors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = [NSMutableDictionary dictionary];
    });
    
    NSString* hexString = [[NSString stringWithUTF8String: hex] uppercaseString];
    NSColor* color = [colors objectForKey:hexString];
    
    if (!color) {
        NSScanner* scanner = [NSScanner scannerWithString: hexString];
        unsigned colorCode = 0;
        [scanner scanHexInt:&colorCode];
        color = [NSColor colorWithCalibratedRed:(CGFloat)(unsigned char)(colorCode >> 16) / 0xff
                                          green:(CGFloat)(unsigned char)(colorCode >> 8) / 0xff
                                           blue:(CGFloat)(unsigned char)(colorCode) / 0xff
                                          alpha: 1.0];
        [colors setObject:color forKey:hexString];
    }
    
    return color;
}

/// textgrid:getsize() -> size
/// Returns the size (nubmer of rows and columns) as a size-table with keys {x,y}.
static int textgrid_getsize(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    
    hydra_pushsize(L, NSMakeSize([wc cols], [wc rows]));
    return 1;
}

/// textgrid:setchar(str, x, y)
/// Sets the given 1-character UTF-8 encoded string at the given grid coordinates.
static int textgrid_setchar(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* str = [[NSString alloc] initWithUTF8String:luaL_checkstring(L, 2)];
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setChar:str x:x y:y];
    return 0;
}

/// textgrid:setcharfg(str, x, y)
/// Sets the textgrid's foreground color to the given 6-digit hex string at the given coordinate.
static int textgrid_setcharfg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* fg = HDColorFromHex(luaL_checkstring(L, 2));
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setForeground:fg x:x y:y];
    return 0;
}

/// textgrid:setcharbg(str, x, y)
/// Sets the textgrid's background color to the given 6-digit hex string at the given coordinate.
static int textgrid_setcharbg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* bg = HDColorFromHex(luaL_checkstring(L, 2));
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setBackground:bg x:x y:y];
    return 0;
}

/// textgrid:clear()
/// Replaces all the textgrid's text with space characters.
static int textgrid_clear(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [wc clear];
    return 0;
}

/// textgrid:setbg(str)
/// Sets the textgrid's background color to the given 6-digit hex string.
static int textgrid_setbg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* bg = HDColorFromHex(luaL_checkstring(L, 2));
    [wc setBackground:bg];
    return 0;
}

/// textgrid:setfg(str)
/// Sets the textgrid's foreground color to the given 6-digit hex string.
static int textgrid_setfg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* fg = HDColorFromHex(luaL_checkstring(L, 2));
    [wc setForeground:fg];
    return 0;
}

/// textgrid:resize(size)
/// Resizes the textgrid to the number of rows and columns given in the size-table with keys {w,h}.
static int textgrid_resize(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [wc useGridSize: hydra_tosize(L, 2)];
    return 0;
}

/// textgrid:usefont(name, pointsize)
/// Sets the new font of the textgrid, potentially changing its visible size (no resize event is fired).
static int textgrid_usefont(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* name = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    double size = luaL_checknumber(L, 3);
    NSFont* font = [NSFont fontWithName:name size:size];
    [wc useFont:font];
    return 0;
}

/// textgrid:getfont() -> name, pointsize
/// Gets the name and pointsize currently used in the textgrid.
static int textgrid_getfont(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSFont* font = [wc font];
    lua_pushstring(L, [[font fontName] UTF8String]);
    lua_pushnumber(L, [font pointSize]);
    return 2;
}

/// textgrid:settitle(title)
/// Changes the title of the textgrid window.
static int textgrid_settitle(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* title = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    [[wc window] setTitle:title];
    return 0;
}

/// textgrid:id() -> number
/// Returns a unique identifier for the textgrid's window.
static int textgrid_id(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    lua_pushnumber(L, [[wc window] windowNumber]);
    return 1;
}

/// textgrid:focus()
/// Brings the textgrid to front and focuses it; implicitly focuses Hydra.
static int textgrid_focus(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [NSApp activateIgnoringOtherApps:YES];
    [[wc window] makeKeyAndOrderFront:nil];
    return 0;
}

/// textgrid:sethasborder(bool)
/// Set whether a textgrid window has a border.
static int textgrid_sethasborder(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    BOOL hasborder = lua_toboolean(L, 2);
    
    NSUInteger mask = [[wc window] styleMask];
    
    if (hasborder)
        mask &= ~NSBorderlessWindowMask;
    else
        mask |= NSBorderlessWindowMask;
    
    [[wc window] setStyleMask:mask];
    
    return 0;
}

/// textgrid:sethastitlebar(bool)
/// Set whether a textgrid window has a title bar.
static int textgrid_sethastitlebar(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    bool hastitlebar = lua_toboolean(L, 2);
    
    NSUInteger mask = [[wc window] styleMask];
    
    if (hastitlebar)
        mask |= NSTitledWindowMask;
    else
        mask &= ~NSTitledWindowMask;
    
    [[wc window] setStyleMask:mask];
    return 0;
}

/// textgrid:sethasshadow(bool)
/// Set whether a textgrid window has a shadow.
static int textgrid_sethasshadow(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    BOOL hasshadow = lua_toboolean(L, 2);
    
    [[wc window] setHasShadow:hasshadow];
    
    return 0;
}

/// textgrid:show()
/// Shows the textgrid; does not focus it, use tg:window():focus() for that.
static int textgrid_show(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [[wc window] orderFront: nil];
    return 0;
}

static void replace_textgrid_callback(lua_State* L, const char* key, int ref) {
    lua_getfield(L, -1, key);
    if (lua_isnumber(L, -1))
        luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, -1));
    lua_pop(L, 1);
    
    lua_pushnumber(L, ref);
    lua_setfield(L, -2, key);
}

/// textgrid:hide()
/// Hides the textgrid; if shown again, will appear in same place.
static int textgrid_hide(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [[wc window] close];
    return 0;
}

/// textgrid:center()
/// Centers the textgrid on the screen it's on.
static int textgrid_center(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [[wc window] center];
    return 0;
}

/// textgrid:resized(fn())
/// Calls the given function when the textgrid is resized.
static int textgrid_resized(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_getuservalue(L, 1);
    replace_textgrid_callback(L, "resized_ref", ref);
    
    wc.windowResizedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

/// textgrid:keydown(fn(t))
/// Calls the given function when a key is pressed in the focused textgrid. The table t contains keys {ctrl, alt, cmd, key}.
static int textgrid_keydown(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_getuservalue(L, 1);
    replace_textgrid_callback(L, "keydown_ref", ref);
    
    [wc useKeyDownHandler:^(BOOL ctrl, BOOL alt, BOOL cmd, NSString *str) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        
        const char *cstr = [str UTF8String];
        
        lua_newtable(L);
        lua_pushboolean(L, ctrl); lua_setfield(L, -2, "ctrl");
        lua_pushboolean(L, alt);  lua_setfield(L, -2, "alt");
        lua_pushboolean(L, cmd);  lua_setfield(L, -2, "cmd");
        lua_pushstring(L, cstr);  lua_setfield(L, -2, "key");
        
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
    }];
    
    return 0;
}

/// textgrid:hidden(fn())
/// Calls the given function when the textgrid is hidden, whether by the user or through the API.
static int textgrid_hidden(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_getuservalue(L, 1);
    replace_textgrid_callback(L, "hidden_ref", ref);
    
    wc.windowClosedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

static int textgrid_create(lua_State *L) {
    HDTextGridController* wc = [[HDTextGridController alloc] init];
    
    void** ptr = lua_newuserdata(L, sizeof(void*));
    *ptr = (__bridge_retained void*)wc;
    
    luaL_getmetatable(L, "textgrid");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_setuservalue(L, -2);
    
    return 1;
}

static int textgrid_gc(lua_State *L) {
    HDTextGridController* wc = (__bridge_transfer HDTextGridController*)*((void**)luaL_checkudata(L, 1, "textgrid"));
    [wc close]; // just in case
    wc = nil;
    
    lua_getuservalue(L, 1);
    
    replace_textgrid_callback(L, "hidden_ref", 0);
    replace_textgrid_callback(L, "resized_ref", 0);
    replace_textgrid_callback(L, "keydown_ref", 0);
    
    return 0;
}

static const luaL_Reg textgridlib[] = {
    {"_create", textgrid_create},
    
    // callbacks
    {"resized", textgrid_resized},
    {"keydown", textgrid_keydown},
    {"hidden", textgrid_hidden},
    
    // methods
    {"show", textgrid_show},
    {"hide", textgrid_hide},
    {"center", textgrid_center},
    {"getsize", textgrid_getsize},
    {"resize", textgrid_resize},
    {"clear", textgrid_clear},
    {"setfg", textgrid_setfg},
    {"setbg", textgrid_setbg},
    {"setchar", textgrid_setchar},
    {"setcharfg", textgrid_setcharfg},
    {"setcharbg", textgrid_setcharbg},
    {"usefont", textgrid_usefont},
    {"getfont", textgrid_getfont},
    {"settitle", textgrid_settitle},
    {"focus", textgrid_focus},
    {"id", textgrid_id},
    {"sethasshadow", textgrid_sethasshadow},
    {"sethasborder", textgrid_sethasborder},
    {"sethastitlebar", textgrid_sethastitlebar},
    
    {NULL, NULL}
};

int luaopen_textgrid(lua_State* L) {
    luaL_newlib(L, textgridlib);
    
    if (luaL_newmetatable(L, "textgrid")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, textgrid_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);
    
    return 1;
}
