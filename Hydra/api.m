#import "lua/lauxlib.h"

void _hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "api"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

int api_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

int api_focus(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
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
    {"focus", api_focus},
    {NULL, NULL}
};

int luaopen_api(lua_State* L) {
    luaL_newlib(L, apilib);
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
