#ifndef Window_application_h
#define Window_application_h

#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);

static void new_window(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;

    luaL_getmetatable(L, "hs.window");
    lua_setmetatable(L, -2);

    lua_newtable(L);

    pid_t pid;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess) {
        lua_pushinteger(L, pid);
        lua_setfield(L, -2, "pid");
    }

    CGWindowID winid;
    AXError err = _AXUIElementGetWindow(win, &winid);
    if (!err) {
        lua_pushinteger(L, winid);
        lua_setfield(L, -2, "id");
    }

    lua_setuservalue(L, -2);
}

#endif
