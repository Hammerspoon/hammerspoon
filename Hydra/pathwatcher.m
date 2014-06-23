#import "api.h"

void event_callback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    dispatch_block_t block = (__bridge dispatch_block_t)clientCallBackInfo;
    block();
}

// args: [patchwatcher]
// returns: []
int pathwatcher_start(lua_State* L) {
    lua_getfield(L, 1, "path");
    NSString* path = [NSString stringWithUTF8String: lua_tostring(L, -1)];
    
    lua_getfield(L, 1, "fn");
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_block_t block = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            _hydra_handle_error(L);
    };
    
    FSEventStreamContext context;
    context.info = (__bridge_retained void*)[block copy];
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    FSEventStreamRef stream = FSEventStreamCreate(NULL,
                                                  event_callback,
                                                  &context,
                                                  (__bridge CFArrayRef)@[[path stringByStandardizingPath]],
                                                  kFSEventStreamEventIdSinceNow,
                                                  0.4,
                                                  kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents);
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    
    lua_pushlightuserdata(L, stream);
    lua_setfield(L, 1, "__stream");
    
    lua_pushnumber(L, closureref);
    lua_setfield(L, 1, "__closureref");
    
    return 0;
}

// args: [patchwatcher]
// returns: []
int pathwatcher_stop(lua_State* L) {
    lua_getfield(L, 1, "__stream");
    FSEventStreamRef stream = lua_touserdata(L, -1);
    
    lua_getfield(L, 1, "__closureref");
    int closureref = lua_tonumber(L, 2);
    
    luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
    
    return 0;
}

// args: [(self), path, fn]
// returns: [pathwatcher]
int pathwatcher_new(lua_State* L) {
    lua_newtable(L);
    
    lua_pushvalue(L, 2);
    lua_setfield(L, -2, "path");
    
    lua_pushvalue(L, 3);
    lua_setfield(L, -2, "fn");
    
    if (luaL_newmetatable(L, "pathwatcher")) {
        lua_getglobal(L, "api");
        lua_getfield(L, -1, "pathwatcher");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1); // hydra-global
    }
    lua_setmetatable(L, -2);
    
    return 1;
}

static const luaL_Reg pathwatcherlib[] = {
    {"_start", pathwatcher_start},
    {"_stop", pathwatcher_stop},
    {NULL, NULL}
};

static const luaL_Reg pathwatcherlib_meta[] = {
    {"__call", pathwatcher_new},
    {NULL, NULL}
};

int luaopen_pathwatcher(lua_State* L) {
    luaL_newlib(L, pathwatcherlib);
    
    luaL_newlib(L, pathwatcherlib_meta);
    lua_setmetatable(L, -2);
    
    return 1;
}
