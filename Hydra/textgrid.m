#import "hydra.h"
#import "HDTextGridController.h"
void new_window_for_nswindow(lua_State* L, NSWindow* win);

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
    "textgrid", "getsize", "api.textgrid:getsize() -> size",
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

static hydradoc doc_textgrid_set = {
    "textgrid", "set", "api.textgrid:set(char, x, y, fg, bg)",
    "Sets the given character in the given position, where char is a UTF8 character thingy, x and y are grid spaces, fg and bg are CSS-like strings."
};

static int textgrid_set(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    unsigned short c = lua_tonumber(L, 2);
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    NSColor* fg = HDColorFromHex(lua_tostring(L, 5));
    NSColor* bg = HDColorFromHex(lua_tostring(L, 6));
    
    [wc setChar:c x:x y:y fg:fg bg:bg];
    
    return 0;
}

static hydradoc doc_textgrid_clear = {
    "textgrid", "clear", "api.textgrid:clear(bg)",
    "Clears the textgrid and sets its background color to bg, a CSS-like string."
};

static int textgrid_clear(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSColor* bg = HDColorFromHex(lua_tostring(L, 2));
    [wc clear:bg];
    
    return 0;
}

static hydradoc doc_textgrid_resize = {
    "textgrid", "resize", "api.textgrid:resize(size)",
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
    "textgrid", "usefont", "api.textgrid:usefont(name, pointsize)",
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
    "textgrid", "getfont", "api.textgrid:getfont() -> name, pointsize",
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
    "textgrid", "settitle", "api.textgrid:settitle(title)",
    "Changes the title of the textgrid window."
};

// args: [textgrid, title]
static int textgrid_settitle(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

static hydradoc doc_textgrid_window = {
    "textgrid", "window", "api.textgrid:window() -> window",
    "Returns the api.window that represents this textgrid."
};

static int textgrid_window(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    new_window_for_nswindow(L, [wc window]);
    return 1;
}

static hydradoc doc_textgrid_focus = {
    "textgrid", "focus", "api.textgrid:focus()",
    "Brings the textgrid to front and focuses it; implicitly focuses Hydra."
};

static int textgrid_focus(lua_State *L) {
    HDTextGridController* wc = get_textgrid_wc(L, 1);
    [NSApp activateIgnoringOtherApps:YES];
    [[wc window] makeKeyAndOrderFront:nil];
    return 0;
}

static int textgrid_gc(lua_State *L) {
    lua_getfield(L, 1, "__wc");
    HDTextGridController* wc = (__bridge_transfer HDTextGridController*)lua_touserdata(L, -1);
    [wc close];
    
    return 0;
}

static hydradoc doc_textgrid_resized = {
    "textgrid", "resized", "api.textgrid:resized = function()",
    "Calls the given function when the textgrid is resized. Defaults to nil."
};

static hydradoc doc_textgrid_closed = {
    "textgrid", "closed", "api.textgrid:closed = function()",
    "Calls the given function when the textgrid is closed. Defaults to nil."
};

static hydradoc doc_textgrid_keydown = {
    "textgrid", "keydown", "api.textgrid:keydown = function(t)",
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
    
    if (luaL_newmetatable(L, "textgrid")) {
        lua_pushcfunction(L, textgrid_gc);
        lua_setfield(L, -2, "__gc");
        
        lua_getglobal(L, "api");
        lua_getfield(L, -1, "textgrid");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1); // api-global
    }
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
    {"set", textgrid_set},
    {"usefont", textgrid_usefont},
    {"getfont", textgrid_getfont},
    {"settitle", textgrid_settitle},
    {"focus", textgrid_focus},
    {"window", textgrid_window},
    
    {NULL, NULL}
};

int luaopen_textgrid(lua_State* L) {
    hydra_add_doc_group(L, "textgrid", "Super easy in-Hydra GUI windows.");
    hydra_add_doc_item(L, &doc_textgrid_resized);
    hydra_add_doc_item(L, &doc_textgrid_closed);
    hydra_add_doc_item(L, &doc_textgrid_keydown);
    hydra_add_doc_item(L, &doc_textgrid_getsize);
    hydra_add_doc_item(L, &doc_textgrid_set);
    hydra_add_doc_item(L, &doc_textgrid_clear);
    hydra_add_doc_item(L, &doc_textgrid_resize);
    hydra_add_doc_item(L, &doc_textgrid_usefont);
    hydra_add_doc_item(L, &doc_textgrid_getfont);
    hydra_add_doc_item(L, &doc_textgrid_settitle);
    hydra_add_doc_item(L, &doc_textgrid_focus);
    hydra_add_doc_item(L, &doc_textgrid_window);
    
    luaL_newlib(L, textgridlib);
    return 1;
}
