#import "helpers.h"
#import "HDTextGridController.h"

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

static hydradoc doc_textgrid_getsize = {
    "textgrid", "getsize", "textgrid:getsize() -> size",
    "Returns the size (nubmer of rows and columns) as a size-table with keys {x,y}."
};

// args: [textgrid]
// ret: [size]
static int textgrid_getsize(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    
    hydra_pushsize(L, NSMakeSize([wc cols], [wc rows]));
    return 1;
}

static hydradoc doc_textgrid_setchar = {
    "textgrid", "set", "textgrid:setchar(str, x, y)",
    "Sets the given 1-character UTF-8 encoded string at the given grid coordinates."
};

static int textgrid_setchar(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* str = [[NSString alloc] initWithUTF8String:luaL_checkstring(L, 2)];
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setChar:str x:x y:y];
    return 0;
}

static hydradoc doc_textgrid_setcharfg = {
    "textgrid", "setcharfg", "textgrid:setcharfg(str, x, y)",
    "Sets the textgrid's foreground color to the given 6-digit hex string at the given coordinate."
};

static int textgrid_setcharfg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* fg = HDColorFromHex(luaL_checkstring(L, 2));
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setForeground:fg x:x y:y];
    return 0;
}

static hydradoc doc_textgrid_setcharbg = {
    "textgrid", "setcharbg", "textgrid:setcharbg(str, x, y)",
    "Sets the textgrid's background color to the given 6-digit hex string at the given coordinate."
};

static int textgrid_setcharbg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* bg = HDColorFromHex(luaL_checkstring(L, 2));
    int x = luaL_checknumber(L, 3) - 1;
    int y = luaL_checknumber(L, 4) - 1;
    [wc setBackground:bg x:x y:y];
    return 0;
}

static hydradoc doc_textgrid_clear = {
    "textgrid", "clear", "textgrid:clear()",
    "Replaces all the textgrid's text with space characters."
};

static int textgrid_clear(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [wc clear];
    return 0;
}

static hydradoc doc_textgrid_setbg = {
    "textgrid", "setbg", "textgrid:setbg(str)",
    "Sets the textgrid's background color to the given 6-digit hex string."
};

static int textgrid_setbg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* bg = HDColorFromHex(luaL_checkstring(L, 2));
    [wc setBackground:bg];
    return 0;
}

static hydradoc doc_textgrid_setfg = {
    "textgrid", "setfg", "textgrid:setfg(str)",
    "Sets the textgrid's foreground color to the given 6-digit hex string."
};

static int textgrid_setfg(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSColor* fg = HDColorFromHex(luaL_checkstring(L, 2));
    [wc setForeground:fg];
    return 0;
}

static hydradoc doc_textgrid_resize = {
    "textgrid", "resize", "textgrid:resize(size)",
    "Resizes the textgrid to the number of rows and columns given in the size-table with keys {x,y}."
};

static int textgrid_resize(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [wc useGridSize: hydra_tosize(L, 2)];
    return 0;
}

static hydradoc doc_textgrid_usefont = {
    "textgrid", "usefont", "textgrid:usefont(name, pointsize)",
    "Sets the new font of the textgrid, potentially changing its visible size (no resize event is fired)."
};

static int textgrid_usefont(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* name = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    double size = luaL_checknumber(L, 3);
    NSFont* font = [NSFont fontWithName:name size:size];
    [wc useFont:font];
    return 0;
}

static hydradoc doc_textgrid_getfont = {
    "textgrid", "getfont", "textgrid:getfont() -> name, pointsize",
    "Gets the name and pointsize currently used in the textgrid."
};

static int textgrid_getfont(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSFont* font = [wc font];
    lua_pushstring(L, [[font fontName] UTF8String]);
    lua_pushnumber(L, [font pointSize]);
    return 2;
}

static hydradoc doc_textgrid_settitle = {
    "textgrid", "settitle", "textgrid:settitle(title)",
    "Changes the title of the textgrid window."
};

// args: [textgrid, title]
static int textgrid_settitle(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    NSString* title = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    [[wc window] setTitle:title];
    return 0;
}

static hydradoc doc_textgrid_id = {
    "textgrid", "id", "textgrid:id() -> number",
    "Returns a unique identifier for the textgrid's window."
};

static int textgrid_id(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    lua_pushnumber(L, [[wc window] windowNumber]);
    return 1;
}

static hydradoc doc_textgrid_focus = {
    "textgrid", "focus", "textgrid:focus()",
    "Brings the textgrid to front and focuses it; implicitly focuses Hydra."
};

static int textgrid_focus(lua_State *L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [NSApp activateIgnoringOtherApps:YES];
    [[wc window] makeKeyAndOrderFront:nil];
    return 0;
}

static hydradoc doc_textgrid_sethasborder = {
    "textgrid", "sethasborder", "textgrid:sethasborder(bool)",
    "Set whether a textgrid window has a border."
};

static int textgrid_sethasborder(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    BOOL hasborder = lua_toboolean(L, 2);
    
    NSUInteger mask = [[wc window] styleMask];
    
    if (hasborder) mask = mask & NSBorderlessWindowMask;
    else mask = mask ^ NSBorderlessWindowMask;
    
    [[wc window] setStyleMask:mask];
    
    return 0;
}

static hydradoc doc_textgrid_sethasshadow = {
    "textgrid", "sethasshadow", "textgrid:sethasshadow(bool)",
    "Set whether a textgrid window has a shadow."
};

static int textgrid_sethasshadow(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    BOOL hasshadow = lua_toboolean(L, 2);
    
    [[wc window] setHasShadow:hasshadow];
    
    return 0;
}

static int textgrid_gc(lua_State *L) {
    HDTextGridController* wc = (__bridge_transfer HDTextGridController*)*((void**)luaL_checkudata(L, 1, "textgrid"));
    [wc close];
    wc = nil;
    
    return 0;
}

static hydradoc doc_textgrid_show = {
    "textgrid", "show", "textgrid:show()",
    "Shows the textgrid; does not focus it, use tg:window():focus() for that."
};

static int textgrid_show(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [[wc window] orderFront: nil];
    return 0;
}

static hydradoc doc_textgrid_hide = {
    "textgrid", "hide", "textgrid:hide()",
    "Hides the textgrid; if shown again, will appear in same place."
};

static int textgrid_hide(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    [[wc window] close];
    return 0;
}

static hydradoc doc_textgrid_resized = {
    "textgrid", "resized", "textgrid:resized(fn())",
    "Calls the given function when the textgrid is resized."
};

static int textgrid_resized(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // TODO: unref old one if set
    
    wc.windowResizedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

static hydradoc doc_textgrid_keydown = {
    "textgrid", "keydown", "textgrid:keydown(fn(t))",
    "Calls the given function when a key is pressed in the focused textgrid. The table t contains keys {ctrl, alt, cmd, key}."
};

static int textgrid_keydown(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // TODO: unref old one if set
    
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

static hydradoc doc_textgrid_closed = {
    "textgrid", "closed", "textgrid:closed(fn())",
    "Calls the given function when the textgrid is closed."
};

static int textgrid_closed(lua_State* L) {
    HDTextGridController* wc = hydra_textgrid(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // TODO: unref old one if set
    
    wc.windowClosedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        
//        luaL_unref(L, LUA_REGISTRYINDEX, tableref);
    };
    return 0;
}

// args: []
// returns: [textgrid]
static int textgrid_new(lua_State *L) {
    HDTextGridController* windowController = [[HDTextGridController alloc] init];
    
    void** ptr = lua_newuserdata(L, sizeof(void*));
    *ptr = (__bridge_retained void*)windowController;
    
    luaL_getmetatable(L, "textgrid");
    lua_setmetatable(L, -2);
    
    return 1;
}

static const luaL_Reg textgridlib[] = {
    {"_new", textgrid_new},
    
    // callbacks
    {"resized", textgrid_resized},
    {"keydown", textgrid_keydown},
    {"closed", textgrid_closed},
    
    // methods
    {"show", textgrid_show},
    {"hide", textgrid_hide},
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
    
    {NULL, NULL}
};

int luaopen_textgrid(lua_State* L) {
    hydra_add_doc_group(L, "textgrid", "Super easy in-Hydra GUI windows.");
    hydra_add_doc_item(L, &doc_textgrid_show);
    hydra_add_doc_item(L, &doc_textgrid_hide);
    hydra_add_doc_item(L, &doc_textgrid_getsize);
    hydra_add_doc_item(L, &doc_textgrid_setchar);
    hydra_add_doc_item(L, &doc_textgrid_setcharfg);
    hydra_add_doc_item(L, &doc_textgrid_setcharbg);
    hydra_add_doc_item(L, &doc_textgrid_clear);
    hydra_add_doc_item(L, &doc_textgrid_setfg);
    hydra_add_doc_item(L, &doc_textgrid_setbg);
    hydra_add_doc_item(L, &doc_textgrid_resize);
    hydra_add_doc_item(L, &doc_textgrid_usefont);
    hydra_add_doc_item(L, &doc_textgrid_getfont);
    hydra_add_doc_item(L, &doc_textgrid_settitle);
    hydra_add_doc_item(L, &doc_textgrid_focus);
    hydra_add_doc_item(L, &doc_textgrid_id);
    hydra_add_doc_item(L, &doc_textgrid_sethasshadow);
    hydra_add_doc_item(L, &doc_textgrid_sethasborder);
    hydra_add_doc_item(L, &doc_textgrid_resized);
    hydra_add_doc_item(L, &doc_textgrid_closed);
    hydra_add_doc_item(L, &doc_textgrid_keydown);
    
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
