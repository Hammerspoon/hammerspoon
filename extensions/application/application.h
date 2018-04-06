#ifndef Application_application_h
#define Application_application_h

static BOOL new_application(lua_State* L, pid_t pid) {
    luaL_checkstack(L, 4, "new_application");
    AXUIElementRef* appptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    *appptr = app;

    if (!app) return false;

    luaL_getmetatable(L, "hs.application");
    lua_setmetatable(L, -2);

    lua_newtable(L);
    lua_pushinteger(L, pid);
    lua_setfield(L, -2, "pid");
    lua_setuservalue(L, -2);

    return true;
}

#endif
