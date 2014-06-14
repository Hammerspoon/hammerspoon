#import "PHAppDelegate.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

int luaopen_app(lua_State * L);
int luaopen_hotkey(lua_State * L);

static const luaL_Reg builtinlibs[] = {
    {"hotkey", luaopen_hotkey},
    {"app", luaopen_app},
    {NULL, NULL}
};

@implementation PHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    const char* app_init_file = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"phoenix_init.lua"] fileSystemRepresentation];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, builtinlibs);
    lua_setglobal(L, "rawapi");
    
    int result = luaL_dofile(L, app_init_file);
    if (result != LUA_OK) {
        const char* err_msg = lua_tostring(L, -1);
        NSLog(@"ERR: %s", err_msg);
    }
}

@end
