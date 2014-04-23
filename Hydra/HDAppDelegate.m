#import "HDAppDelegate.h"
#import "HDHotKey.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    lua_pushcfunction(L, luaopen_hotkey);
    lua_setfield(L, -2, "hotkey");
    lua_pop(L, 2);
    
    NSString* file = [[NSBundle mainBundle] pathForResource:@"init" ofType:@"lua"];
    luaL_dofile(L, [file fileSystemRepresentation]);
}

@end
