#import "lua/lauxlib.h"
void hydra_handle_error(lua_State* L);
void hydra_add_doc_group(lua_State* L, char* name, char* docstring);

typedef struct _hydradoc {
    char* group;
    char* name;
    char* definition;
    char* docstring;
} hydradoc;

void hydra_add_doc_item(lua_State* L, hydradoc* doc);

NSSize hydra_tosize(lua_State* L, int idx);
NSRect hydra_torect(lua_State* L, int idx);
NSPoint hydra_topoint(lua_State* L, int idx);
