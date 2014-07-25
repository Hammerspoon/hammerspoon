#import "helpers.h"

/// === pathwatcher ===
///
/// Watch paths recursively for changes.
///
/// This simple example watches your Hydra directory for changes, and when it sees a change, reloads your configs:
///
///     pathwatcher.new(os.getenv("HOME") .. "/.hydra/", hydra.reload):start()

typedef struct _pathwatcher_t {
    lua_State* L;
    int closureref;
    FSEventStreamRef stream;
    int self;
} pathwatcher_t;

void event_callback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    
    pathwatcher_t* pw = clientCallBackInfo;
    lua_State* L = pw->L;
    
    const char** changedFiles = eventPaths;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, pw->closureref);
    
    lua_newtable(L);
    for(int i = 0 ; i < numEvents; i++) {
        lua_pushstring(L, changedFiles[i]);
        lua_rawseti(L, -2, i + 1);
    }
    
    if (lua_pcall(L, 1, 0, 0))
        hydra_handle_error(L);
}

/// pathwatcher.new(path, fn()) -> pathwatcher
/// Returns a new pathwatcher that can be started and stopped.
static int pathwatcher_new(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    pathwatcher_t* pathwatcher = lua_newuserdata(L, sizeof(pathwatcher_t));
    pathwatcher->L = L;
    pathwatcher->closureref = closureref;
    
    lua_getfield(L, LUA_REGISTRYINDEX, "pathwatcher");
    lua_setmetatable(L, -2);
    
    FSEventStreamContext context;
    context.info = pathwatcher;
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    pathwatcher->stream = FSEventStreamCreate(NULL,
                                              event_callback,
                                              &context,
                                              (__bridge CFArrayRef)@[[path stringByStandardizingPath]],
                                              kFSEventStreamEventIdSinceNow,
                                              0.4,
                                              kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents);
    
    return 1;
}

/// pathwatcher:start()
/// Registers pathwatcher's fn as a callback when pathwatcher's path or any descendent changes.
static int pathwatcher_start(lua_State* L) {
    pathwatcher_t* pathwatcher = luaL_checkudata(L, 1, "pathwatcher");
    
    pathwatcher->self = hydra_store_handler(L, 1);
    FSEventStreamScheduleWithRunLoop(pathwatcher->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(pathwatcher->stream);
    
    return 0;
}

/// pathwatcher:stop()
/// Unregisters pathwatcher's fn so it won't be called again until the pathwatcher is restarted.
static int pathwatcher_stop(lua_State* L) {
    pathwatcher_t* pathwatcher = luaL_checkudata(L, 1, "pathwatcher");
    
    hydra_remove_handler(L, pathwatcher->self);
    FSEventStreamStop(pathwatcher->stream);
    FSEventStreamInvalidate(pathwatcher->stream);
    FSEventStreamRelease(pathwatcher->stream);
    
    return 0;
}

/// pathwatcher.stopall()
/// Calls pathwatcher:stop() for all started pathwatchers; called automatically when user config reloads.
static int pathwatcher_stopall(lua_State* L) {
    lua_getglobal(L, "pathwatcher");
    lua_getfield(L, -1, "stop");
    hydra_remove_all_handlers(L, "pathwatcher");
    return 0;
}

static int pathwatcher_gc(lua_State* L) {
    pathwatcher_t* pathwatcher = luaL_checkudata(L, 1, "pathwatcher");
    luaL_unref(L, LUA_REGISTRYINDEX, pathwatcher->closureref);
    return 0;
}

static const luaL_Reg pathwatcherlib[] = {
    {"new", pathwatcher_new},
    {"stopall", pathwatcher_stopall},
    
    {"start", pathwatcher_start},
    {"stop", pathwatcher_stop},
    
    {"__gc", pathwatcher_gc},
    
    {NULL, NULL}
};

int luaopen_pathwatcher(lua_State* L) {
    luaL_newlib(L, pathwatcherlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "pathwatcher");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    return 1;
}
