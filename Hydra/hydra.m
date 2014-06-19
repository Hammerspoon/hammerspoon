#import "lua/lauxlib.h"

int hydra_show_about_panel(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

int hydra_quit(lua_State* L) {
    [NSApp terminate:nil];
    return 0; // lol
}

int luaopen_hydra(lua_State* L) { return 0; }
