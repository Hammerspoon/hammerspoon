#import "lua/lauxlib.h"

int hydra_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

// args: [path]
// return: [exists, isdir]
int hydra_fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
    
    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

static const luaL_Reg hydralib[] = {
    {"showabout", hydra_showabout},
    {"fileexists", hydra_fileexists},
    {NULL, NULL}
};

int luaopen_hydra(lua_State* L) {
    luaL_newlib(L, hydralib);
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
