#import "MJLua.h"
#import "MJConsoleWindowController.h"
#import "MJUserNotificationManager.h"

static lua_State* MJLuaState;

/// === mj ===
///
/// Core Mjolnir functionality.

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
}

/// mj.openconsole()
/// Function
/// Opens the Mjolnir Console window and focuses it.
static int core_openconsole(lua_State* L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
    return 0;
}

/// mj.reload()
/// Function
/// Reloads your init-file in a fresh Lua environment.
static int core_reload(lua_State* L) {
    dispatch_async(dispatch_get_main_queue(), ^{
        MJLuaSetup();
    });
    return 0;
}

static int core_exit(lua_State* L) {
    if (lua_toboolean(L, 2))
        lua_close(L);
    
    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static int core__logmessage(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    loghandler(str);
    return 0;
}

static int core__notify(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    [[MJUserNotificationManager sharedManager] sendNotification:str handler:^{
        [[MJConsoleWindowController singleton] showWindow: nil];
    }];
    return 0;
}

static luaL_Reg corelib[] = {
    {"openconsole", core_openconsole},
    {"reload", core_reload},
    {"_exit", core_exit},
    {"_logmessage", core__logmessage},
    {"_notify", core__notify},
    {}
};

void MJLuaSetup(void) {
    if (MJLuaState)
        lua_close(MJLuaState);
    
    lua_State* L = MJLuaState = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, corelib);
    lua_setglobal(L, "mj");
    
    luaL_dofile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
}

NSString* MJLuaRunString(NSString* command) {
    lua_State* L = MJLuaState;
    
    lua_getglobal(L, "mj");
    lua_getfield(L, -1, "runstring");
    lua_pushstring(L, [command UTF8String]);
    lua_pcall(L, 1, 1, 0);
    
    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    lua_pop(L, 2);
    
    return str;
}

int mjolnir_pcall(lua_State *L, int nargs, int nresults) {
    // push debug.traceback
    lua_pushliteral(L, "__mj_debug_traceback");
    lua_rawget(L, LUA_REGISTRYINDEX);
    
    // move it to below the function
    int msgh = lua_gettop(L) - (nargs + 2);
    lua_insert(L, msgh);
    
    // call and store result
    int r = lua_pcall(L, nargs, nresults, msgh);
    if (r) {
        // push mj.showerror
        lua_pushliteral(L, "__mj_showerror");
        lua_rawget(L, LUA_REGISTRYINDEX);
        
        // push error and call
        lua_pushvalue(L, -2);
        lua_call(L, 1, 0);
    }
    
    // remove debug.traceback
    lua_remove(L, msgh);
    
    // return as if nothing happened
    return r;
}
