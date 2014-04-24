#import "HDAppDelegate.h"
#import "HDHotKey.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    const char* core_dir = [[resourcePath stringByAppendingPathComponent:@"?.lua"] fileSystemRepresentation];
    const char* user_dir = [[@"~/.hydra/?.lua" stringByStandardizingPath] fileSystemRepresentation];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_getglobal(L, "package");          // [package]
    
    lua_getfield(L, -1, "preload");       // [package, preload]
    lua_pushcfunction(L, luaopen_hotkey); // [package, preload, luaopen_hotkey]
    lua_setfield(L, -2, "hotkey");        // [package, preload]
    lua_pop(L, 1);                        // [package]
    
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
