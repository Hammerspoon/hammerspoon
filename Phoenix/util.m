#import "lua/lauxlib.h"

int util_do_after_delay(lua_State* L) {
    double delayInSeconds = lua_tonumber(L, 1);
    int i = luaL_ref(L, LUA_REGISTRYINDEX); // enclose fn at top of stack (arg 2)
    
    /*
     
     TODO / FIXME:
     
     My use of luaL_ref() in menu, pathwatcher, and util, is a bug.
     It must be balanced with luaL_unref() when it's done with, but
     because ObjC blocks don't have a finalizer, we never know when
     it's been destroyed. Not sure what the solution is just yet.
     It probably involves creating a wrapper object that takes a
     block and executes it, but has a finalizer. Or something.
     
     */
    
    Block_release(<#...#>)
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, i);
        lua_call(L, 0, 0);
    });
    
    return 0;
}
