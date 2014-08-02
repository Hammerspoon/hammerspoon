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

static AXUIElementRef hydra_system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

/// core.setaccessibilitytimeout(sec)
/// Change the timeout of accessibility operations; may reduce sluggishness.
/// NOTE: this may be a dumb idea and might be removed before 1.0 is released.
static int core_setaccessibilitytimeout(lua_State* L) {
    float sec = luaL_checknumber(L, 1);
    AXUIElementSetMessagingTimeout(hydra_system_wide_element(), sec);
    return 0;
}

static luaL_Reg corelib[] = {
    {"exit", core_exit},
    {"setaccessibilitytimeout", core_setaccessibilitytimeout},
    {}
};

//    hydra_setup_handler_storage(L); // TODO: turn into core.addhandler(), and set it up in setup.lua etc...

int luaopen_core(lua_State* L) {
    luaL_newlib(L, corelib);
    return 1;
}
