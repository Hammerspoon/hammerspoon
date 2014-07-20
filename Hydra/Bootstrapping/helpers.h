#import "../lua/lauxlib.h"
void hydra_handle_error(lua_State* L);

NSSize hydra_tosize(lua_State* L, int idx);
NSRect hydra_torect(lua_State* L, int idx);
NSPoint hydra_topoint(lua_State* L, int idx);

void hydra_pushsize(lua_State* L, NSSize size);
void hydra_pushpoint(lua_State* L, NSPoint point);
void hydra_pushrect(lua_State* L, NSRect rect);

void hydra_setup_handler_storage(lua_State* L);
int hydra_store_handler(lua_State* L, int idx);
void hydra_remove_handler(lua_State* L, int ref);
void* hydra_get_stored_handler(lua_State* L, int ref, const char* type);
void hydra_remove_all_handlers(lua_State* L, const char* type);
void hydra_push_luavalue_for_nsobject(lua_State* L, id obj);
id hydra_nsobject_for_luavalue(lua_State* L, int idx);