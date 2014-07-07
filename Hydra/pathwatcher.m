#import "helpers.h"

void event_callback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    dispatch_block_t block = (__bridge dispatch_block_t)clientCallBackInfo;
    block();
}

// args: [path, fn]
// returns: [stream, ref]
static int pathwatcher_start(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_block_t block = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
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
    lua_pushnumber(L, closureref);
    return 2;
}

// args: [stream, ref]
// returns: []
static int pathwatcher_stop(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    FSEventStreamRef stream = lua_touserdata(L, 1);
    int closureref = luaL_checknumber(L, 2);
    
    luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
    
    return 0;
}

static const luaL_Reg pathwatcherlib[] = {
    {"_start", pathwatcher_start},
    {"_stop", pathwatcher_stop},
    {NULL, NULL}
};

int luaopen_pathwatcher(lua_State* L) {
    hydra_add_doc_group(L, "pathwatcher", "(overwritten in pathwatcher.lua)");
    
    luaL_newlib(L, pathwatcherlib);
    return 1;
}
