#import "lua/lauxlib.h"
#import "lua/lualib.h"

int luaopen_api(lua_State* L);

int luaopen_hotkey(lua_State* L);
int luaopen_app(lua_State* L);
int luaopen_mouse(lua_State* L);
int luaopen_autolaunch(lua_State* L);
int luaopen_menu(lua_State* L);
int luaopen_pathwatcher(lua_State* L);
int luaopen_window(lua_State* L);
int luaopen_screen(lua_State* L);
int luaopen_timer(lua_State* L);
int luaopen_geometry(lua_State* L);
int luaopen_textgrid(lua_State* L);
int luaopen_updates(lua_State* L);
int luaopen_notify(lua_State* L);
int luaopen_webview(lua_State* L);
int luaopen_settings(lua_State* L);
int luaopen_utf8(lua_State* L);

@interface PHAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PHAppDelegate

- (void) setupLua {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_newtable(L);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "doc");
    lua_newtable(L);
    lua_setfield(L, -2, "api");
    
    luaopen_api(L);
    
    static const luaL_Reg hydralibs[] = {
        {"hotkey",       luaopen_hotkey},
        {"app",          luaopen_app},
        {"mouse",        luaopen_mouse},
        {"autolaunch",   luaopen_autolaunch},
        {"menu",         luaopen_menu},
        {"pathwatcher",  luaopen_pathwatcher},
        {"window",       luaopen_window},
        {"screen",       luaopen_screen},
        {"timer",        luaopen_timer},
        {"geometry",     luaopen_geometry},
        {"textgrid",     luaopen_textgrid},
        {"updates",      luaopen_updates},
        {"notify",       luaopen_notify},
        {"webview",      luaopen_webview},
        {"settings",     luaopen_settings},
        {"utf8",         luaopen_utf8},
        {NULL, NULL},
    };
    
    for (int i = 0; hydralibs[i].name; i++) {
        luaL_Reg lib = hydralibs[i];
        lib.func(L);
        lua_setfield(L, -2, lib.name);
    }
    
    NSString* initFile = [[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"];
    luaL_dofile(L, [initFile fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupLua];
}

@end
