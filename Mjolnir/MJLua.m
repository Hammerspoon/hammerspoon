#import "MJLua.h"
#import "MJConsoleWindowController.h"
#import "MJUserNotificationManager.h"
#import "MJConfigUtils.h"
#import "variables.h"

static lua_State* MJLuaState;
static int evalfn;

/// === mjolnir ===
///
/// Core Mjolnir functionality.

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
}

/// mjolnir.openconsole()
/// Function
/// Opens the Mjolnir Console window and focuses it.
static int core_openconsole(lua_State* L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
    return 0;
}

/// mjolnir.reload()
/// Function
/// Reloads your init-file in a fresh Lua environment.
static int core_reload(lua_State* L) {
    dispatch_async(dispatch_get_main_queue(), ^{
        MJLuaSetup();
    });
    return 0;
}

/// mjolnir.focus()
/// Function
/// Makes Mjolnir the foreground app.
static int core_focus(lua_State* L) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    return 0;
}

static int core_exit(lua_State* L) {
    if (lua_toboolean(L, 2))
        lua_close(L);
    
    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static int core_logmessage(lua_State* L) {
    size_t len;
    const char* s = lua_tolstring(L, 1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    loghandler(str);
    return 0;
}

static int core_notify(lua_State* L) {
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
    {"focus", core_focus},
    {"_exit", core_exit},
    {"_logmessage", core_logmessage},
    {"_notify", core_notify},
    {}
};

void MJLuaSetup(void) {
    if (MJLuaState)
        lua_close(MJLuaState);
    
    lua_State* L = MJLuaState = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, corelib);
    lua_setglobal(L, "mjolnir");
    
    luaL_loadfile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
    
    lua_pushstring(L, [MJConfigFile UTF8String]);
    lua_pushstring(L, [MJConfigFileFullPath() UTF8String]);
    lua_pushstring(L, [MJConfigDir() UTF8String]);
    lua_pushboolean(L, [[NSFileManager defaultManager] fileExistsAtPath: MJConfigFileFullPath()]);
    
    lua_pcall(L, 4, 1, 0);
    
    evalfn = luaL_ref(L, LUA_REGISTRYINDEX);
}

NSString* MJLuaRunString(NSString* command) {
    lua_State* L = MJLuaState;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, evalfn);
    lua_pushstring(L, [command UTF8String]);
    lua_call(L, 1, 1);
    
    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    lua_pop(L, 1);
    
    return str;
}
