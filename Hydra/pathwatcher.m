#import <Foundation/Foundation.h>
#import "lua/lauxlib.h"

void event_callback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    dispatch_block_t block = (__bridge dispatch_block_t)clientCallBackInfo;
    block();
}

int pathwatcher_stop(lua_State* L) {
    FSEventStreamRef stream = lua_touserdata(L, 1);
    int closureref = lua_tonumber(L, 2);
    
    luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
    
    return 0;
}

int pathwatcher_start(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String: lua_tostring(L, 1)];
    
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    dispatch_block_t block = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        lua_call(L, 0, 0);
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
