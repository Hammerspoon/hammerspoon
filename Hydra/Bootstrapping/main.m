#import <Cocoa/Cocoa.h>
#import "helpers.h"
#import "../lua/lualib.h"

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

int luaopen_application(lua_State* L);
int luaopen_audiodevice(lua_State* L);
int luaopen_autolaunch(lua_State* L);
int luaopen_brightness(lua_State* L);
int luaopen_dockicon(lua_State* L);
//int luaopen_eventtap(lua_State* L);
int luaopen_geometry(lua_State* L);
int luaopen_hotkey(lua_State* L);
int luaopen_http(lua_State* L);
int luaopen_hydra(lua_State* L);
int luaopen_ipc(lua_State* L);
int luaopen_json(lua_State* L);
int luaopen_menu(lua_State* L);
int luaopen_mouse(lua_State* L);
int luaopen_notify(lua_State* L);
int luaopen_notify_applistener(lua_State* L);
int luaopen_pasteboard(lua_State* L);
int luaopen_pathwatcher(lua_State* L);
int luaopen_screen(lua_State* L);
int luaopen_settings(lua_State* L);
int luaopen_textgrid(lua_State* L);
int luaopen_timer(lua_State* L);
int luaopen_updates(lua_State* L);
int luaopen_utf8(lua_State* L);
int luaopen_window(lua_State* L);

@interface HydraAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation HydraAppDelegate

typedef struct _hydralib {
    const char *name;
    const char *subname;
    lua_CFunction func;
} hydralib;

static const hydralib hydralibs[] = {
    {"application",  NULL,          luaopen_application},
    {"audiodevice",  NULL,          luaopen_audiodevice},
    {"autolaunch",   NULL,          luaopen_autolaunch},
    {"brightness",   NULL,          luaopen_brightness},
    {"dockicon",     NULL,          luaopen_dockicon},
//    {"eventtap",     NULL,          luaopen_eventtap},
    {"geometry",     NULL,          luaopen_geometry},
    {"hotkey",       NULL,          luaopen_hotkey},
    {"http",         NULL,          luaopen_http},
    {"hydra",        NULL,          luaopen_hydra},
    {"ipc",          NULL,          luaopen_ipc},
    {"json",         NULL,          luaopen_json},
    {"menu",         NULL,          luaopen_menu},
    {"mouse",        NULL,          luaopen_mouse},
    {"notify",       NULL,          luaopen_notify},
    {"notify",       "applistener", luaopen_notify_applistener},
    {"pasteboard",   NULL,          luaopen_pasteboard},
    {"pathwatcher",  NULL,          luaopen_pathwatcher},
    {"screen",       NULL,          luaopen_screen},
    {"settings",     NULL,          luaopen_settings},
    {"textgrid",     NULL,          luaopen_textgrid},
    {"timer",        NULL,          luaopen_timer},
    {"updates",      NULL,          luaopen_updates},
    {"utf8",         NULL,          luaopen_utf8},
    {"window",       NULL,          luaopen_window},
    {NULL, NULL, NULL},
};

- (void) setupLua {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    hydra_setup_handler_storage(L);
    
    for (int i = 0; hydralibs[i].func; i++) {
        hydralib lib = hydralibs[i];
        
        if (lib.subname) {
            lua_getglobal(L, lib.name);
            lib.func(L);
            lua_setfield(L, -2, lib.subname);
            lua_pop(L, 1);
        }
        else {
            lib.func(L);
            lua_setglobal(L, lib.name);
        }
    }
    
    NSString* initFile = [[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"];
    luaL_dofile(L, [initFile fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupLua];
}

@end
