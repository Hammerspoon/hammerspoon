#import "lua/lauxlib.h"
void _hydra_handle_error(lua_State* L);
void _hydra_add_doc_item(lua_State* L, char* name, char* definition, char* docstring);
void _hydra_add_doc_group(lua_State* L, char* name, char* docstring);
