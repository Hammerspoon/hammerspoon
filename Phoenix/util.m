#import "lua/lauxlib.h"

int util_do_after_delay(lua_State* L) {
    double delayInSeconds = lua_tonumber(L, 1);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        lua_call(L, 0, 0);
        luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    });
    
    return 0;
}
