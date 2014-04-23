#import "HDAppDelegate.h"

#include "lua/lauxlib.h"
#include "lua/lualib.h"

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    lua_State* L = luaL_newstate();
    
    luaL_openlibs(L);
    
    luaL_dostring(L, "print(2 + 3)");
    
}

@end
