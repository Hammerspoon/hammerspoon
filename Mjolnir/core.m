#import "core.h"

lua_State* MJLuaState;

/// === core ===
///
/// Core functionality.

static void(^loghandler)(NSString* str);
void MJSetupLogHandler(void(^blk)(NSString* str)) {
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

static luaL_Reg corelib[] = {
    {"exit", core_exit},
    {"_logmessage", core__logmessage},
    {}
};

//    mjolnir_setup_handler_storage(L); // TODO: turn into core.addhandler(), and set it up in setup.lua etc...

void MJSetupLua(void) {
    lua_State* L = MJLuaState = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, corelib);
    lua_setglobal(L, "core");
    
    luaL_dofile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
}

void MJLoadModule(NSString* fullname) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "_loadmodule");
    lua_remove(L, -2);
    lua_pushstring(L, [fullname UTF8String]);
    lua_call(L, 1, 0);
}

void MJUnloadModule(NSString* fullname) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "_unloadmodule");
    lua_remove(L, -2);
    lua_pushstring(L, [fullname UTF8String]);
    lua_call(L, 1, 0);
}

void MJReloadConfig(void) {
    lua_State* L = MJLuaState;
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "reload");
    lua_call(L, 0, 0);
    lua_pop(L, 1);
}
