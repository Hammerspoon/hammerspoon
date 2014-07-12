#import "helpers.h"

static luaL_Reg eventlib[] = {
    {NULL, NULL}
};

int luaopen_event(lua_State* L) {
    luaL_newlib(L, eventlib);
    return 1;
}
