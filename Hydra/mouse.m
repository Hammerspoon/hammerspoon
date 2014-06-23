#import "hydra.h"

static hydradoc doc_mouse_get = {
    "mouse", "get", "api.mouse.get() -> point",
    "Returns the current location of the mouse on the current screen as a point."
};

int mouse_get(lua_State* L) {
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ourEvent);
    
    lua_newtable(L);
    lua_pushnumber(L, p.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, p.y); lua_setfield(L, -2, "y");
    return 1;
}

static hydradoc doc_mouse_set = {
    "mouse", "set", "api.mouse.set(point)",
    "Moves the mouse to the given location on the current screen."
};

int mouse_set(lua_State* L) {
    CGFloat x = (lua_getfield(L, 1, "x"), lua_tonumber(L, -1));
    CGFloat y = (lua_getfield(L, 1, "y"), lua_tonumber(L, -1));
    
    CGPoint p = CGPointMake(x, y);
    CGWarpMouseCursorPosition(p);
    return 0;
}

static const luaL_Reg mouselib[] = {
    {"get", mouse_get},
    {"set", mouse_set},
    {NULL, NULL}
};

int luaopen_mouse(lua_State* L) {
    hydra_add_doc_group(L, "mouse", "Functions for manipulating the mouse cursor.");
    hydra_add_doc_item(L, &doc_mouse_get);
    hydra_add_doc_item(L, &doc_mouse_set);
    
    luaL_newlib(L, mouselib);
    return 1;
}
