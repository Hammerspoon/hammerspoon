#import "helpers.h"
#import "HDTextGridController.h"

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

static HDTextGridController* get_textgrid_wc(lua_State* L, int idx) {
    lua_getfield(L, idx, "__wc");
    HDTextGridController* wc = (__bridge HDTextGridController*)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return wc;
}

static hydradoc doc_textgrid_getsize = {
    "textgrid", "getsize", "textgrid:getsize() -> size",
    "Returns the size (nubmer of rows and columns) as a size-table with keys {x,y}."
};

// args: [textgrid]
// ret: [size]
static int textgrid_getsize(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    lua_newtable(L);
    lua_pushnumber(L, [wc cols]); lua_setfield(L, -2, "w");
    lua_pushnumber(L, [wc rows]); lua_setfield(L, -2, "h");
    
    return 1;
}

static hydradoc doc_textgrid_setchar = {
    "textgrid", "set", "textgrid:setchar(str, x, y)",
    "Sets the given 1-character UTF-8 encoded string at the given grid coordinates."
};

static int textgrid_setchar(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    size_t len;
    const char* s = lua_tolstring(L, 2, &len);
    NSString* str = [[NSString alloc] initWithBytes:s length:len encoding:NSUTF8StringEncoding];
    
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    
    [wc setChar:str x:x y:y];
    
    return 0;
}

static hydradoc doc_textgrid_setcharfg = {
    "textgrid", "setcharfg", "textgrid:setcharfg(str, x, y)",
    "Sets the textgrid's foreground color to the given 6-digit hex string at the given coordinate."
};

static int textgrid_setcharfg(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSColor* fg = HDColorFromHex(lua_tostring(L, 2));
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    
    [wc setForeground:fg x:x y:y];
    
    return 0;
}

static hydradoc doc_textgrid_setcharbg = {
    "textgrid", "setcharbg", "textgrid:setcharbg(str, x, y)",
    "Sets the textgrid's background color to the given 6-digit hex string at the given coordinate."
};

static int textgrid_setcharbg(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSColor* bg = HDColorFromHex(lua_tostring(L, 2));
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    
    [wc setBackground:bg x:x y:y];
    
    return 0;
}

static hydradoc doc_textgrid_clear = {
    "textgrid", "clear", "textgrid:clear()",
    "Replaces all the textgrid's text with space characters."
};

static int textgrid_clear(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    [wc clear];
    return 0;
}

static hydradoc doc_textgrid_setbg = {
    "textgrid", "setbg", "textgrid:setbg(str)",
    "Sets the textgrid's background color to the given 6-digit hex string."
};

static int textgrid_setbg(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    NSColor* bg = HDColorFromHex(lua_tostring(L, 2));
    [wc setBackground:bg];
    return 0;
}

static hydradoc doc_textgrid_setfg = {
    "textgrid", "setfg", "textgrid:setfg(str)",
    "Sets the textgrid's foreground color to the given 6-digit hex string."
};

static int textgrid_setfg(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    NSColor* fg = HDColorFromHex(lua_tostring(L, 2));
    [wc setForeground:fg];
    return 0;
}

static hydradoc doc_textgrid_resize = {
    "textgrid", "resize", "textgrid:resize(size)",
    "Resizes the textgrid to the number of rows and columns given in the size-table with keys {x,y}."
};

static int textgrid_resize(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    lua_getfield(L, 2, "w");
    int w = lua_tonumber(L, -1);
    
    lua_getfield(L, 2, "h");
    int h = lua_tonumber(L, -1);
    
    [wc useGridSize:NSMakeSize(w, h)];
    
    return 0;
}

static hydradoc doc_textgrid_usefont = {
    "textgrid", "usefont", "textgrid:usefont(name, pointsize)",
    "Sets the new font of the textgrid, potentially changing its visible size (no resize event is fired)."
};

static int textgrid_usefont(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSString* name = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    double size = lua_tonumber(L, 3);
    
    NSFont* font = [NSFont fontWithName:name size:size];
    [wc useFont:font];
    
    return 0;
}

static hydradoc doc_textgrid_getfont = {
    "textgrid", "getfont", "textgrid:getfont() -> name, pointsize",
    "Gets the name and pointsize currently used in the textgrid."
};

static int textgrid_getfont(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
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
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

static hydradoc doc_textgrid_id = {
    "textgrid", "id", "textgrid:id() -> number",
    "Returns a unique identifier for the textgrid's window."
};

static int textgrid_id(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    lua_pushnumber(L, [[wc window] windowNumber]);
    return 1;
}

static hydradoc doc_textgrid_focus = {
    "textgrid", "focus", "textgrid:focus()",
    "Brings the textgrid to front and focuses it; implicitly focuses Hydra."
};

static int textgrid_focus(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    [NSApp activateIgnoringOtherApps:YES];
    [[wc window] makeKeyAndOrderFront:nil];
    return 0;
}

static hydradoc doc_textgrid_sethasborder = {
    "textgrid", "sethasborder", "textgrid:sethasborder(bool)",
    "Set whether a textgrid window has a border."
};

static int textgrid_sethasborder(lua_State* L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
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
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    BOOL hasshadow = lua_toboolean(L, 2);
    
    [[wc window] setHasShadow:hasshadow];
    
    return 0;
}

static int textgrid_gc(lua_State *L) {
    lua_getfield(L, 1, "__wc");
    HDTextGridController* wc = (__bridge_transfer HDTextGridController*)lua_touserdata(L, -1);
    [wc close];
    
    return 0;
}

static hydradoc doc_textgrid_resized = {
    "textgrid", "resized", "textgrid:resized = function()",
    "Calls the given function when the textgrid is resized. Defaults to nil."
};

static hydradoc doc_textgrid_closed = {
    "textgrid", "closed", "textgrid:closed = function()",
    "Calls the given function when the textgrid is closed. Defaults to nil."
};

static hydradoc doc_textgrid_keydown = {
    "textgrid", "keydown", "textgrid:keydown = function(t)",
    "Calls the given function when a key is pressed in the focused textgrid. The table t contains keys {ctrl, alt, cmd, key}. Defaults to nil."
};

// args: []
// returns: [textgrid]
static int textgrid_open(lua_State *L) {
    HDTextGridController* windowController = [[HDTextGridController alloc] init];
    [windowController showWindow: nil];
    
    lua_newtable(L);
    
    // save it for later
    lua_pushvalue(L, -1);
    int tableref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    windowController.windowResizedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
        lua_getfield(L, -1, "resized");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0))
                hydra_handle_error(L);
            lua_pop(L, 1);
        }
        else {
            lua_pop(L, 2);
        }
    };
    
    windowController.windowClosedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
        lua_getfield(L, -1, "closed");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0))
                hydra_handle_error(L);
            lua_pop(L, 1);
        }
        else {
            lua_pop(L, 2);
        }
        
        luaL_unref(L, LUA_REGISTRYINDEX, tableref);
    };
    
    [windowController useKeyDownHandler:^(BOOL ctrl, BOOL alt, BOOL cmd, NSString *str) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
        lua_getfield(L, -1, "keydown");
        if (lua_isfunction(L, -1)) {
            lua_newtable(L);
            lua_pushboolean(L, ctrl);            lua_setfield(L, -2, "ctrl");
            lua_pushboolean(L, alt);             lua_setfield(L, -2, "alt");
            lua_pushboolean(L, cmd);             lua_setfield(L, -2, "cmd");
            lua_pushstring(L, [str UTF8String]); lua_setfield(L, -2, "key");
            
            if (lua_pcall(L, 1, 0, 0))
                hydra_handle_error(L);
            
            lua_pop(L, 1);
        }
        else {
            lua_pop(L, 2);
        }
    }];
    
    lua_pushlightuserdata(L, (__bridge_retained void*)windowController);
    lua_setfield(L, -2, "__wc");
    
    luaL_getmetatable(L, "textgrid");
    lua_setmetatable(L, -2);
    
    return 1;
}

// args: [textgrid]
static int textgrid_close(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    [wc close];
    return 0;
}

static const luaL_Reg textgridlib[] = {
    {"_open", textgrid_open},
    
    // methods
    {"_close", textgrid_close},
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
    hydra_add_doc_item(L, &doc_textgrid_resized);
    hydra_add_doc_item(L, &doc_textgrid_closed);
    hydra_add_doc_item(L, &doc_textgrid_keydown);
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
