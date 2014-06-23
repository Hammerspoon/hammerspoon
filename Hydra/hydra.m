#import "hydra.h"

void _hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "api"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

void _hydra_add_doc_group(lua_State* L, char* name, char* docstring) {
    lua_getglobal(L, "api");
    lua_getfield(L, -1, "doc");
    
    lua_newtable(L);
    lua_pushstring(L, docstring);
    lua_setfield(L, -2, "__doc");
    
    lua_setfield(L, -2, name);
    lua_pop(L, 2); // api, doc
}

void _hydra_add_doc_item(lua_State* L, hydradoc* doc) {
    lua_getglobal(L, "api");
    lua_getfield(L, -1, "doc");
    lua_getfield(L, -1, doc->group);
    
    lua_newtable(L);
    lua_pushstring(L, doc->definition);
    lua_rawseti(L, -2, 1);
    lua_pushstring(L, doc->docstring);
    lua_rawseti(L, -2, 2);
    
    lua_setfield(L, -2, doc->name);
    
    lua_pop(L, 3); // api, doc, group
}
