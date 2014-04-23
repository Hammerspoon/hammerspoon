#import "HDAppDelegate.h"
#import "HDHotKey.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_getglobal(L, "package");
    
    lua_getfield(L, -1, "preload"); // push preload
    lua_pushcfunction(L, luaopen_hotkey); // push c function
    lua_setfield(L, -2, "hotkey"); // pop off c function, leaving preload
    lua_pop(L, 1); // pop off preload, leaving package
    
    lua_getfield(L, -1, "path"); // push path
    lua_pushliteral(L, ";"); // push separator
    lua_pushstring(L, [[resourcePath stringByAppendingPathComponent:@"?.lua"] fileSystemRepresentation]); // push string
    lua_pushliteral(L, ";"); // push separator
    lua_pushstring(L, [[@"~/.hydra/?.lua" stringByStandardizingPath] fileSystemRepresentation]); // push string
    lua_concat(L, 5); // concat all 5 strings, leaving 1 string on top of package
    lua_setfield(L, -2, "path"); // push string onto package, leaving only package
    
    lua_pop(L, 1); // pop package
    
    NSString* file = [resourcePath stringByAppendingPathComponent:@"hydra_init.lua"];
    luaL_dofile(L, [file fileSystemRepresentation]);
}

@end
