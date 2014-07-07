#import "../lua/lauxlib.h"
void hydra_handle_error(lua_State* L);

NSSize hydra_tosize(lua_State* L, int idx);
NSRect hydra_torect(lua_State* L, int idx);
NSPoint hydra_topoint(lua_State* L, int idx);

void hydra_pushsize(lua_State* L, NSSize size);
void hydra_pushpoint(lua_State* L, NSPoint point);
void hydra_pushrect(lua_State* L, NSRect rect);
