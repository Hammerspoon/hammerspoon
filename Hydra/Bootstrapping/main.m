#import <Cocoa/Cocoa.h>
#import "helpers.h"
#import "../lua/lualib.h"

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

int luaopen_application(lua_State* L);
int luaopen_audiodevice(lua_State* L);
int luaopen_brightness(lua_State* L);
int luaopen_battery(lua_State* L);
int luaopen_battery_watcher(lua_State* L);
int luaopen_eventtap(lua_State* L);
int luaopen_eventtap_event(lua_State* L);
int luaopen_geometry(lua_State* L);
int luaopen_hotkey(lua_State* L);
int luaopen_http(lua_State* L);
int luaopen_hydra(lua_State* L);
int luaopen_hydra_autolaunch(lua_State* L);
int luaopen_hydra_dockicon(lua_State* L);
int luaopen_hydra_ipc(lua_State* L);
int luaopen_hydra_license(lua_State* L);
int luaopen_hydra_menu(lua_State* L);
int luaopen_hydra_settings(lua_State* L);
int luaopen_hydra_updates(lua_State* L);
int luaopen_json(lua_State* L);
int luaopen_mouse(lua_State* L);
int luaopen_notify(lua_State* L);
int luaopen_notify_applistener(lua_State* L);
int luaopen_pasteboard(lua_State* L);
int luaopen_pathwatcher(lua_State* L);
int luaopen_screen(lua_State* L);
int luaopen_spaces(lua_State* L);
int luaopen_textgrid(lua_State* L);
int luaopen_timer(lua_State* L);
int luaopen_utf8(lua_State* L);
int luaopen_window(lua_State* L);

@interface HydraAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation HydraAppDelegate

typedef struct _hydralib hydralib;
struct _hydralib {
    const char *name;
    lua_CFunction func;
    hydralib* sublib;
};

// always end a submodule with sentinals, or bad things will happen
static const hydralib hydralibs[] = {
    {"application",  luaopen_application},
    {"audiodevice",  luaopen_audiodevice},
    {"battery",      luaopen_battery, (hydralib[]){
        {"watcher", luaopen_battery_watcher},
        {}}},
    {"brightness",   luaopen_brightness},
    {"eventtap",     luaopen_eventtap, (hydralib[]){
        {"event", luaopen_eventtap_event},
        {}}},
    {"geometry",     luaopen_geometry},
    {"hotkey",       luaopen_hotkey},
    {"http",         luaopen_http},
    {"hydra",        luaopen_hydra, (hydralib[]){
        {"autolaunch",  luaopen_hydra_autolaunch},
        {"dockicon",    luaopen_hydra_dockicon},
        {"ipc",         luaopen_hydra_ipc},
        {"license",     luaopen_hydra_license},
        {"menu",        luaopen_hydra_menu},
        {"settings",    luaopen_hydra_settings},
        {"updates",     luaopen_hydra_updates},
        {}}},
    {"json",         luaopen_json},
    {"mouse",        luaopen_mouse},
    {"notify",       luaopen_notify, (hydralib[]){
        {"applistener", luaopen_notify_applistener},
        {}}},
    {"pasteboard",   luaopen_pasteboard},
    {"pathwatcher",  luaopen_pathwatcher},
    {"screen",       luaopen_screen},
    {"spaces",       luaopen_spaces},
    {"textgrid",     luaopen_textgrid},
    {"timer",        luaopen_timer},
    {"utf8",         luaopen_utf8},
    {"window",       luaopen_window},
    {},
};

static void addmodules(lua_State* L, const hydralib* libs, bool toplevel) {
    for (int i = 0; libs[i].func; i++) {
        hydralib lib = libs[i];
        
        lib.func(L);
        
        if (lib.sublib)
            addmodules(L, lib.sublib, false);
        
        if (toplevel)
            lua_setglobal(L, lib.name);
        else
            lua_setfield(L, -2, lib.name);
    }
}

- (void) setupLua {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    hydra_setup_handler_storage(L);
    addmodules(L, hydralibs, true);
    
    NSString* initFile = [[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"];
    luaL_dofile(L, [initFile fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    AXUIElementSetMessagingTimeout(hydra_system_wide_element(), 1.0);
    [self setupLua];
}

@end
