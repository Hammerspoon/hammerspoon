#import "lua/lauxlib.h"

static AXUIElementRef hydra_system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

//    hydra_setup_handler_storage(L); // TODO: turn into core.addhandler(), and set it up in setup.lua etc...

int luaopen_core(lua_State* L) {
    AXUIElementSetMessagingTimeout(hydra_system_wide_element(), 1.0); // TODO: turn into core.setaccessibilitytimeout() and call with 1.0 in rawinit.lua
    
    lua_newtable(L);
    return 1;
}
