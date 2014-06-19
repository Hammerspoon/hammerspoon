#import "lua/lauxlib.h"

int phoenix_show_about_panel(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

int phoenix_quit(lua_State* L) {
    [NSApp terminate:nil];
    return 0; // lol
}
