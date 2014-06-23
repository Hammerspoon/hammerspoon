#import "api.h"
void PHShowAlert(NSString* oneLineMsg, CGFloat duration);

void _hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "api"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

void _hydra_add_doc_item(lua_State* L, char* name, char* definition, char* docstring) {
    
}

void _hydra_add_doc_group(lua_State* L, char* name, char* docstring) {
    lua_getglobal(L, "api");
    lua_getfield(L, -1, "doc");
    
    lua_newtable(L);
    lua_pushstring(L, docstring);
    lua_setfield(L, -2, "__doc");
    
    lua_setfield(L, -2, name);
    lua_pop(L, 2); // api and doc
}

int api_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

int api_focushydra(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    return 0;
}

int api_alert(lua_State* L) {
    const char* str = lua_tostring(L, 1);
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    PHShowAlert([NSString stringWithUTF8String:str], duration);
    
    return 0;
}

// args: [path]
// return: [exists, isdir]
int api_fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
    
    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

static const luaL_Reg apilib[] = {
    {"showabout", api_showabout},
    {"fileexists", api_fileexists},
    {"focushydra", api_focushydra},
    {"alert", api_alert},
    {NULL, NULL}
};

int luaopen_api(lua_State* L) {
    luaL_newlib(L, apilib);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "api");
    
    lua_newtable(L);
    lua_setfield(L, -2, "doc");
    
    _hydra_add_doc_group(L, "api", "Top level API functions.");
    _hydra_add_doc_item(L, "alert", "api.alert(str, seconds = 2)",
                        "Shows a message in large words briefly in the middle of the screen.");
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
