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

static const luaL_Reg hydralib[] = {
    {"showabout", hydra_show_about_panel},
    {"quit", hydra_quit},
    {NULL, NULL}
};

int luaopen_hydra(lua_State* L) {
    luaL_newlib(L, hydralib);
    return 1;
}
