#ifndef Application_application_h
#define Application_application_h

static void new_application(lua_State* L, pid_t pid) {
    AXUIElementRef* appptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *appptr = AXUIElementCreateApplication(pid);
    
    luaL_getmetatable(L, "mjolnir.application");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_pushnumber(L, pid);
    lua_setfield(L, -2, "pid");
    lua_setuservalue(L, -2);
}

#endif
