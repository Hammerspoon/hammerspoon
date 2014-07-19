#import <Cocoa/Cocoa.h>
#import "helpers.h"
#import "../lua/lualib.h"

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

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
int luaopen_eventtap(lua_State* L);
int luaopen_applistener(lua_State* L);
int luaopen_pasteboard(lua_State* L);
int luaopen_http(lua_State* L);
int luaopen_dockicon(lua_State* L);
int luaopen_audio(lua_State* L);

@interface HydraAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation HydraAppDelegate

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
    {"eventtap",     luaopen_eventtap},
    {"applistener",  luaopen_applistener},
    {"pasteboard",   luaopen_pasteboard},
    {"http",         luaopen_http},
    {"dockicon",     luaopen_dockicon},
    {"audio",        luaopen_audio},
    {NULL, NULL},
};

- (void) setupLua {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    hydra_setup_handler_storage(L);
    
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
