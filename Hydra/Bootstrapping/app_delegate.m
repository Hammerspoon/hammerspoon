#import "../lua/lauxlib.h"
#import "../lua/lualib.h"

int luaopen_hydra(lua_State* L);
int luaopen_hotkey(lua_State* L);
int luaopen_application(lua_State* L);
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
int luaopen_settings(lua_State* L);
int luaopen_utf8(lua_State* L);
int luaopen_json(lua_State* L);
int luaopen_brightness(lua_State* L);
int luaopen_ipc(lua_State* L);
int luaopen_event(lua_State* L);

@interface PHAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PHAppDelegate

static const luaL_Reg hydralibs[] = {
    {"hydra",        luaopen_hydra},
    {"hotkey",       luaopen_hotkey},
    {"application",  luaopen_application},
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
    {"settings",     luaopen_settings},
    {"utf8",         luaopen_utf8},
    {"json",         luaopen_json},
    {"brightness",   luaopen_brightness},
    {"ipc",          luaopen_ipc},
    {"event",        luaopen_event},
    {NULL, NULL},
};

- (void) setupLua {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_newtable(L);
    for (int i = 0; hydralibs[i].name; i++) {
        luaL_Reg lib = hydralibs[i];
        lib.func(L);
        lua_setglobal(L, lib.name);
    }
    
    NSString* initFile = [[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"];
    luaL_dofile(L, [initFile fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupLua];
}

@end
