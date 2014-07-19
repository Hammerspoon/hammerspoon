#import "helpers.h"

// stack in:  [..., error]
// stack out: [...]
void hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "hydra"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

NSSize hydra_tosize(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakeSize(w, h);
}

NSRect hydra_torect(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 4);
    return NSMakeRect(x, y, w, h);
}

NSPoint hydra_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}

void hydra_pushsize(lua_State* L, NSSize size) {
    lua_newtable(L);
    lua_pushnumber(L, size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, size.height); lua_setfield(L, -2, "h");
}

void hydra_pushpoint(lua_State* L, NSPoint point) {
    lua_newtable(L);
    lua_pushnumber(L, point.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, point.y); lua_setfield(L, -2, "y");
}

void hydra_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

void hydra_setup_handler_storage(lua_State* L) {
    lua_newtable(L);
    lua_setglobal(L, "_registry");
}

int hydra_store_handler(lua_State* L, int idx) {
    idx = lua_absindex(L, idx);
    lua_getglobal(L, "_registry");
    lua_pushvalue(L, idx);
    int next = luaL_ref(L, -2);
    lua_pop(L, 1);
    return next;
}

void hydra_remove_handler(lua_State* L, int idx, int ref) {
    idx = lua_absindex(L, idx);
    lua_getglobal(L, "_registry");
    luaL_unref(L, -1, ref);
    lua_pop(L, 1);
}

void* hydra_get_stored_handler(lua_State* L, int ref, const char* type) {
    lua_getglobal(L, "_registry");
    lua_rawgeti(L, -1, ref);
    if (!luaL_testudata(L, -1, type))
        luaL_error(L, "expected event handler to be of type %s, but wasn't.", type);
    void* handler = lua_touserdata(L, -1);
    lua_pop(L, 2);
    return handler;
}
