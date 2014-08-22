#import "MJLua.h"
#import "MJUserNotificationManager.h"
#import "MJMainWindowController.h"

static lua_State* MJLuaState;

/// === core ===
///
/// Core functionality.

static void(^loghandler)(NSString* str);
void MJLuaSetupLogHandler(void(^blk)(NSString* str)) {
    loghandler = blk;
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
        [[MJMainWindowController sharedMainWindowController] showREPL];
    }];
    return 0;
}

static luaL_Reg corelib[] = {
    {"exit", core_exit},
    {"_logmessage", core__logmessage},
    {"_notify", core__notify},
    {}
};

void MJLuaSetup(void) {
    lua_State* L = MJLuaState = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, corelib);
    lua_setglobal(L, "core");
    
    luaL_dofile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
}

void MJLuaLoadModule(NSString* fullname) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "_loadmodule");
    lua_remove(L, -2);
    lua_pushstring(L, [fullname UTF8String]);
    lua_call(L, 1, 0);
}

void MJLuaUnloadModule(NSString* fullname) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "_unloadmodule");
    lua_remove(L, -2);
    lua_pushstring(L, [fullname UTF8String]);
    lua_call(L, 1, 0);
}

void MJLuaReloadConfig(void) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "reload");
    lua_call(L, 0, 0);
    lua_pop(L, 1);
}

NSString* MJLuaRunString(NSString* command) {
    lua_State* L = MJLuaState;
    
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "runstring");
    lua_pushstring(L, [command UTF8String]);
    lua_pcall(L, 1, 1, 0);
    
    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    lua_pop(L, 2);
    
    return str;
}
