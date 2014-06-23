#import "hydra.h"

static void listen_to_stdout(lua_State* L) {
    id handler = ^(NSFileHandle* standardOut) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSString* str = [[NSString alloc] initWithData:[standardOut availableData] encoding:NSUTF8StringEncoding];
            
            NSLog(@"stdout: %@", str);
            
            lua_getglobal(L, "api");
            lua_getfield(L, -1, "log");
            lua_getfield(L, -1, "_gotline");
            lua_pushstring(L, [str UTF8String]);
            
            if (lua_pcall(L, 1, 0, 0))
                hydra_handle_error(L);
            
            lua_pop(L, 2);
        });
    };
    
    static NSPipe* stdoutpipe; stdoutpipe = [NSPipe pipe];
    [stdoutpipe fileHandleForReading].readabilityHandler = handler;
    dup2([[stdoutpipe fileHandleForWriting] fileDescriptor], fileno(stdout));
}

int luaopen_log(lua_State* L) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        listen_to_stdout(L);
    });
    
    hydra_add_doc_group(L, "log", "Functionality to assist with debugging and experimentation.");
    
    lua_newtable(L);
    return 1;
}
