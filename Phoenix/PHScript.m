#import "PHScript.h"
#import "lua/lauxlib.h"

void phoenix_push_hotkey_lib(lua_State * L);

@implementation PHScript

+ (PHScript*) sharedScript {
    static PHScript* sharedScript;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedScript = [[PHScript alloc] init];
    });
    return sharedScript;
}

- (void) reload {
    const char* app_init_file = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"phoenix_init.lua"] fileSystemRepresentation];
    
    self.L = luaL_newstate();
    luaL_openlibs(self.L);
    
    lua_newtable(self.L);
    
    phoenix_push_hotkey_lib(self.L);
    lua_setfield(self.L, -2, "hotkey");
    
    lua_setglobal(self.L, "rawapi");
    
    int result = luaL_dofile(self.L, app_init_file);
    if (result != LUA_OK) {
        const char* err_msg = lua_tostring(self.L, -1);
        NSLog(@"ERROR HAPPENED: %s", err_msg);
    }
}

@end
