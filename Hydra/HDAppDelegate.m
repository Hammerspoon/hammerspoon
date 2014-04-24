#import "HDAppDelegate.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

int luaopen_app(lua_State * L);
int luaopen_hotkey(lua_State * L);

static const luaL_Reg builtinlibs[] = {
    {"hotkey", luaopen_hotkey},
    {"app", luaopen_app},
    {NULL, NULL}
};

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    const char* core_dir = [[resourcePath stringByAppendingPathComponent:@"?.lua"] fileSystemRepresentation];
    const char* user_dir = [[@"~/.hydra/?.lua" stringByStandardizingPath] fileSystemRepresentation];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_getfield(L, LUA_REGISTRYINDEX, "_PRELOAD"); // [preload]
    luaL_setfuncs(L, builtinlibs, 0);               // [preload]
    lua_pop(L, 1);                                  // []
    
    lua_getglobal(L, "package");          // [package]
    lua_getfield(L, -1, "path");          // [package, path]
    lua_pushliteral(L, ";");              // [package, path, ";"]
    lua_pushstring(L, core_dir);          // [package, path, ";", coredir]
    lua_pushliteral(L, ";");              // [package, path, ";", coredir, ";"]
    lua_pushstring(L, user_dir);          // [package, path, ";", coredir, ";", userdir]
    lua_concat(L, 5);                     // [package, newpath]
    lua_setfield(L, -2, "path");          // [package]
    
    lua_pop(L, 1);                        // []
    
    luaL_dostring(L, "require('hydra_init')");
}

@end
