#import "lua/lauxlib.h"
#import "HDTextGridWindowController.h"

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

// args: [win, fn]
static int textgrid_resized(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    int i = luaL_ref(L, LUA_REGISTRYINDEX);
    
    wc.windowResizedHandler = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, i);
        lua_pcall(L, 0, 0, 0);
    };
    
    return 0;
}

// args: [win, fn(t)]
static int textgrid_keydown(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    int i = luaL_ref(L, LUA_REGISTRYINDEX);
    
    [wc useKeyDownHandler:^(BOOL ctrl, BOOL alt, BOOL cmd, NSString *str) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, i);
        
        lua_newtable(L);
        lua_pushboolean(L, ctrl);
        lua_setfield(L, -2, "ctrl");
        lua_pushboolean(L, alt);
        lua_setfield(L, -2, "alt");
        lua_pushboolean(L, cmd);
        lua_setfield(L, -2, "cmd");
        lua_pushstring(L, [str UTF8String]);
        lua_setfield(L, -2, "key");
        
        lua_pcall(L, 1, 0, 0);
    }];
    
    return 0;
}

// args: [win]
static int textgrid_getsize(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    lua_pushnumber(L, [wc cols]);
    lua_pushnumber(L, [wc rows]);
    return 2;
}

// args: [win, char, x, y, fg, bg]
static int textgrid_set(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    unsigned short c = lua_tonumber(L, 2);
    int x = lua_tonumber(L, 3) - 1;
    int y = lua_tonumber(L, 4) - 1;
    NSColor* fg = HDColorFromHex(lua_tostring(L, 5));
    NSColor* bg = HDColorFromHex(lua_tostring(L, 6));
    
    [wc setChar:c x:x y:y fg:fg bg:bg];
    
    return 0;
}

// args: [win, bg]
static int textgrid_clear(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    NSColor* bg = HDColorFromHex(lua_tostring(L, 2));
    [wc clear:bg];
    
    return 0;
}

// args: [win, w, h]
static int textgrid_resize(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    int w = lua_tonumber(L, 2);
    int h = lua_tonumber(L, 3);
    [wc useGridSize:NSMakeSize(w, h)];
    
    return 0;
}

// args: [win, name, size]
static int textgrid_usefont(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    NSString* name = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    double size = lua_tonumber(L, 3);
    
    NSFont* font = [NSFont fontWithName:name size:size];
    [wc useFont:font];
    
    return 0;
}

// args: [win]
// returns: [name, size]
static int textgrid_getfont(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    NSFont* font = [wc font];
    
    lua_pushstring(L, [[font fontName] UTF8String]);
    lua_pushnumber(L, [font pointSize]);
    
    return 2;
}

// args: [win, title]
static int textgrid_settitle(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

// args: [win]
static int textgrid_close(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge HDTextGridWindowController*)*(void**)lua_touserdata(L, lua_upvalueindex(1));
    
    [wc close];
    
    return 0;
}

static const luaL_Reg textgridlib_instance[] = {
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

static int textgrid_gc(lua_State *L) {
    HDTextGridWindowController* wc = (__bridge_transfer HDTextGridWindowController*)*(void**)lua_touserdata(L, 1);
    [wc close];
    return 0;
}

// args: []
// returns: [win]
static int textgrid_new(lua_State *L) {
    HDTextGridWindowController* wc = [[HDTextGridWindowController alloc] init];
    [wc showWindow: nil];
    void* ud = (__bridge_retained void*)wc;
    
    /*
     - the __gc method /automatically/ gets the userdata as its arg
     - predefined methods will share the userdata as an upvalue
     */
    
    lua_newtable(L);                                  // [win]
    lua_newtable(L);                                  // [win, {}]
    luaL_newlibtable(L, textgridlib_instance);             // [win, {}, methods]
    
    *(void**)lua_newuserdata(L, sizeof(void*)) = ud;  // [win, {}, methods, ud]
    lua_newtable(L);                                  // [win, {}, methods, ud, {}]
    lua_pushcfunction(L, textgrid_gc);                     // [win, {}, methods, ud, {}, gc]
    lua_setfield(L, -2, "__gc");                      // [win, {}, methods, ud, {...}]
    lua_setmetatable(L, -2);                          // [win, {}, methods, ud]
    
    luaL_setfuncs(L, textgridlib_instance, 1);             // [win, {}, methods]
    
    lua_setfield(L, -2, "__index");                   // [win, {...}]
    lua_setmetatable(L, -2);                          // [win]
    
    return 1;
}

static const luaL_Reg winlib[] = {
    {"new", textgrid_new},
    {NULL, NULL}
};

int luaopen_textgrid(lua_State* L) {
    luaL_newlib(L, winlib);
    return 1;
}
