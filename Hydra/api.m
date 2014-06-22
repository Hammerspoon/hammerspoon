#import "lua/lauxlib.h"
void PHShowAlert(NSString* oneLineMsg, CGFloat duration);

void _hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "api"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

int api_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

int api_focushydra(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    return 0;
}

int api_alert(lua_State* L) {
    const char* str = lua_tostring(L, 1);
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    PHShowAlert([NSString stringWithUTF8String:str], duration);
    
    return 0;
}

// args: [path]
// return: [exists, isdir]
int api_fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
    
    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

static const luaL_Reg apilib[] = {
    {"showabout", api_showabout},
    {"fileexists", api_fileexists},
    {"focushydra", api_focushydra},
    {"alert", api_alert},
    {NULL, NULL}
};

static void listen_to_stdout(lua_State* L) {
    id handler = ^(NSFileHandle* standardOut) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSString* str = [[NSString alloc] initWithData:[standardOut availableData] encoding:NSUTF8StringEncoding];
            
            lua_getglobal(L, "api");
            lua_getfield(L, -1, "_receivedstdout");
            lua_pushstring(L, [str UTF8String]);
            
            if (lua_pcall(L, 1, 0, 0))
                _hydra_handle_error(L);
            
            lua_pop(L, 1);
        });
    };
    
    static NSPipe* stdoutpipe; stdoutpipe = [NSPipe pipe];
//    static NSPipe* stderrpipe; stderrpipe = [NSPipe pipe];
    
    [stdoutpipe fileHandleForReading].readabilityHandler = handler;
//    [stderrpipe fileHandleForReading].readabilityHandler = handler;
    
    dup2([[stdoutpipe fileHandleForWriting] fileDescriptor], fileno(stdout));
//    dup2([[stderrpipe fileHandleForWriting] fileDescriptor], fileno(stderr));
}

int luaopen_api(lua_State* L) {
    luaL_newlib(L, apilib);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        listen_to_stdout(L);
    });
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
