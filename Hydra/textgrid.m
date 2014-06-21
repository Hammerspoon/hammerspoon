#import "lua/lauxlib.h"
#import "HDTextGridWindowController.h"
void _hydra_handle_error(lua_State* L);

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

static HDTextGridWindowController* get_textgrid_wc(lua_State* L, int idx) {
    lua_getfield(L, idx, "__wc");
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return wc;
}

// args: [textgrid, fn]
static int textgrid_resized(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_pushnumber(L, closureref);
    lua_setfield(L, 1, "__resizedclosureref");
    
    wc.windowResizedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            _hydra_handle_error(L);
    };
    
    return 0;
}

// args: [textgrid, fn(t)]
// ret: []
static int textgrid_keydown(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_pushnumber(L, closureref);
    lua_setfield(L, 1, "__keydownclosureref");
    
    [wc useKeyDownHandler:^(BOOL ctrl, BOOL alt, BOOL cmd, NSString *str) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        
        lua_newtable(L);
        lua_pushboolean(L, ctrl);            lua_setfield(L, -2, "ctrl");
        lua_pushboolean(L, alt);             lua_setfield(L, -2, "alt");
        lua_pushboolean(L, cmd);             lua_setfield(L, -2, "cmd");
        lua_pushstring(L, [str UTF8String]); lua_setfield(L, -2, "key");
        
        if (lua_pcall(L, 1, 0, 0))
            _hydra_handle_error(L);
    }];
    
    return 0;
}

// args: [textgrid]
// ret: [size]
static int textgrid_getsize(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    lua_newtable(L);
    lua_pushnumber(L, [wc cols]); lua_setfield(L, -2, "w");
    lua_pushnumber(L, [wc rows]); lua_setfield(L, -2, "h");
    
    return 1;
}

// args: [textgrid, char, x, y, fg, bg]
// ret: []
static int textgrid_set(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    unsigned short c = lua_tonumber(L, 2);
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    NSColor* fg = HDColorFromHex(lua_tostring(L, 5));
    NSColor* bg = HDColorFromHex(lua_tostring(L, 6));
    
    [wc setChar:c x:x y:y fg:fg bg:bg];
    
    return 0;
}

// args: [textgrid, bg]
// ret: []
static int textgrid_clear(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    NSColor* bg = HDColorFromHex(lua_tostring(L, 2));
    [wc clear:bg];
    
    return 0;
}

// args: [textgrid, size]
// ret: []
static int textgrid_resize(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    lua_getfield(L, 2, "w");
    int w = lua_tonumber(L, -1);
    
    lua_getfield(L, 2, "h");
    int h = lua_tonumber(L, -1);
    
    [wc useGridSize:NSMakeSize(w, h)];
    
    return 0;
}

// args: [textgrid, name, pointsize]
// ret: []
static int textgrid_usefont(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    NSString* name = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    double size = lua_tonumber(L, 3);
    
    NSFont* font = [NSFont fontWithName:name size:size];
    [wc useFont:font];
    
    return 0;
}

// args: [textgrid]
// returns: [name, pointsize]
static int textgrid_getfont(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    NSFont* font = [wc font];
    
    lua_pushstring(L, [[font fontName] UTF8String]);
    lua_pushnumber(L, [font pointSize]);
    
    return 2;
}

// args: [textgrid, title]
static int textgrid_settitle(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

// args: [textgrid]
static int textgrid_close(lua_State *L) {
    HDTextGridWindowController* wc = get_textgrid_wc(L, 1);
    [wc close];
    return 0;
}

static int textgrid_gc(lua_State *L) {
    lua_getfield(L, 1, "__wc");
    HDTextGridWindowController* wc = (__bridge_transfer HDTextGridWindowController*)lua_touserdata(L, -1);
    [wc close];
    
    lua_getfield(L, 1, "__resizedclosureref");
    if (lua_isnumber(L, -1))
        luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, -1));
    
    lua_getfield(L, 1, "__keydownclosureref");
    if (lua_isnumber(L, -1))
        luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, -1));
    
    return 0;
}

// args: []
// returns: [textgrid]
static int textgrid_open(lua_State *L) {
    HDTextGridWindowController* windowController = [[HDTextGridWindowController alloc] init];
    [windowController showWindow: nil];
    
    lua_newtable(L);
    
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

static const luaL_Reg textgridlib[] = {
    {"open", textgrid_open},
    
    // event handlers
    {"resized", textgrid_resized},
    {"keydown", textgrid_keydown},
    
    // methods
    {"close", textgrid_close},
    {"getsize", textgrid_getsize},
    {"resize", textgrid_resize},
    {"clear", textgrid_clear},
    {"set", textgrid_set},
    {"usefont", textgrid_usefont},
    {"getfont", textgrid_getfont},
    {"settitle", textgrid_settitle},
    
    {NULL, NULL}
};

int luaopen_textgrid(lua_State* L) {
    luaL_newlib(L, textgridlib);
    return 1;
}
