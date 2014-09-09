#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

static int foobar_addnumbers(lua_State* L) {
    int a = luaL_checknumber(L, 1);
    int b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

static const luaL_Reg foobarlib[] = {
    {"addnumbers", foobar_addnumbers},
    
    {} // necessary sentinel
};


/* NOTE: The substring "mjolnir_yourid_foobar_internal" in the following function's name
         must match the require-path of this file, i.e. "mjolnir.yourid.foobar.internal". */

int luaopen_mjolnir_yourid_foobar_internal(lua_State* L) {
    luaL_newlib(L, foobarlib);
    return 1;
}
