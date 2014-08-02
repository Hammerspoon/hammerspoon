#import "lua/lauxlib.h"

/// === core ===
///
/// Core Penknife functionality.

static int core_exit(lua_State* L) {
    if (lua_toboolean(L, 2))
        lua_close(L);
    
    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

//static AXUIElementRef hydra_system_wide_element() {
//    static AXUIElementRef element;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        element = AXUIElementCreateSystemWide();
//    });
//    return element;
//}

static luaL_Reg corelib[] = {
    {"exit", core_exit},
    {}
};

//    hydra_setup_handler_storage(L); // TODO: turn into core.addhandler(), and set it up in setup.lua etc...
//    AXUIElementSetMessagingTimeout(hydra_system_wide_element(), 1.0); // TODO: turn into core.setaccessibilitytimeout() and call with 1.0 in rawinit.lua

int luaopen_core(lua_State* L) {
    luaL_newlib(L, corelib);
    return 1;
}
