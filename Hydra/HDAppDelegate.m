#import "HDAppDelegate.h"
#import "HDHotKey.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

@implementation HDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    hydra_hotkey_setup(L);
    
    NSString* file = [[NSBundle mainBundle] pathForResource:@"init" ofType:@"lua"];
    luaL_dofile(L, [file fileSystemRepresentation]);
}

@end
