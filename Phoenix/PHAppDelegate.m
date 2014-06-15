#import "PHAppDelegate.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

int hotkey_setup(lua_State *L);
int hotkey_register(lua_State *L);
int hotkey_unregister(lua_State *L);

static const luaL_Reg phoenix_lib[] = {
    {"hotkey_setup", hotkey_setup},
    {"hotkey_register", hotkey_register},
    {"hotkey_unregister", hotkey_unregister},
    {NULL, NULL}
};


@implementation PHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, phoenix_lib);
    lua_setglobal(L, "__api");
    
    const char* app_init_file = [[[NSBundle mainBundle] URLForResource:@"phoenix_init" withExtension:@"lua"] fileSystemRepresentation];
    luaL_dofile(L, app_init_file);
}

@end
