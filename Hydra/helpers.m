#import "helpers.h"

void hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "hydra"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

void hydra_add_doc_group(lua_State* L, char* name, char* docstring) {
    lua_getglobal(L, "doc");
    lua_newtable(L);
    
    lua_pushstring(L, docstring);
    lua_setfield(L, -2, "__doc");
    
    lua_setfield(L, -2, name);
    lua_pop(L, 1); // doc
}

void hydra_add_doc_item(lua_State* L, hydradoc* doc) {
    lua_getglobal(L, "doc");
    lua_getfield(L, -1, doc->group);
    
    lua_newtable(L);
    lua_pushstring(L, doc->definition);
    lua_rawseti(L, -2, 1);
    lua_pushstring(L, doc->docstring);
    lua_rawseti(L, -2, 2);
    
    lua_setfield(L, -2, doc->name);
    
    lua_pop(L, 2); // api, group
}


// TODO: use this pattern for all types; use them everywhere!
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
