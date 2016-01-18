#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

// Common Code

#define USERDATA_TAG    "hs.pathwatcher"
int refTable;

// Not so common code

typedef struct _watcher_path_t {
    int closureref;
    FSEventStreamRef stream;
    bool started;
} watcher_path_t;

void event_callback(ConstFSEventStreamRef __unused streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags __unused eventFlags[], const FSEventStreamEventId __unused eventIds[]) {
    LuaSkin *skin = [LuaSkin shared];

    watcher_path_t* pw = clientCallBackInfo;

    lua_State *L = skin.L;

    const char** changedFiles = eventPaths;

    [skin pushLuaRef:refTable ref:pw->closureref];

    lua_newtable(L);
    for(size_t i = 0 ; i < numEvents; i++) {
        lua_pushstring(L, changedFiles[i]);
        lua_rawseti(L, -2, i + 1);
    }

    if (![skin protectedCallAndTraceback:1 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        [skin logError:[NSString stringWithFormat:@"hs.pathwatcher callback error: %s", errorMsg]];
    }
}

/// hs.pathwatcher.new(path, fn) -> watcher
/// Constructor
/// Returns a new watcher.path that can be started and stopped.  The function registered receives as it's argument, a table containing a list of the files which have changed since it was last invoked.
static int watcher_path_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK];

    NSString* path = [NSString stringWithUTF8String: lua_tostring(L, 1)];

    watcher_path_t* watcher_path = lua_newuserdata(L, sizeof(watcher_path_t));
    watcher_path->started = NO;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    lua_pushvalue(L, 2);
    watcher_path->closureref = [skin luaRef:refTable];

    FSEventStreamContext context;
    context.info = watcher_path;
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    watcher_path->stream = FSEventStreamCreate(NULL,
                                              event_callback,
                                              &context,
                                              (__bridge CFArrayRef)@[[path stringByStandardizingPath]],
                                              kFSEventStreamEventIdSinceNow,
                                              0.4,
                                              kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents);

    return 1;
}

/// hs.pathwatcher:start()
/// Method
/// Registers watcher's fn as a callback for when watcher's path or any descendent changes.
static int watcher_path_start(lua_State* L) {
    watcher_path_t* watcher_path = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (watcher_path->started) return 1;
    watcher_path->started = YES;

    FSEventStreamScheduleWithRunLoop(watcher_path->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(watcher_path->stream);

    return 1;
}

/// hs.pathwatcher:stop()
/// Method
/// Unregisters watcher's fn so it won't be called again until the watcher is restarted.
static int watcher_path_stop(lua_State* L) {
    watcher_path_t* watcher_path = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);

    if (!watcher_path->started) return 1;

    watcher_path->started = NO;
    FSEventStreamStop(watcher_path->stream);
    FSEventStreamUnscheduleFromRunLoop(watcher_path->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    return 1;
}

static int watcher_path_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];

    watcher_path_t* watcher_path = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, watcher_path_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    FSEventStreamInvalidate(watcher_path->stream);
    FSEventStreamRelease(watcher_path->stream);

    watcher_path->closureref = [skin luaUnref:refTable ref:watcher_path->closureref];

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    watcher_path_t* watcher_path = luaL_checkudata(L, 1, USERDATA_TAG);
    NSArray *thePaths = (__bridge_transfer NSArray *) FSEventStreamCopyPathsBeingWatched (watcher_path->stream);
    NSString *thePath = [thePaths objectAtIndex:0] ;
    if (!thePath) thePath = @"(unknown path)" ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, thePath, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg path_metalib[] = {
    {"start",   watcher_path_start},
    {"stop",    watcher_path_stop},
    {"__gc",    watcher_path_gc},
    {"__tostring", userdata_tostring},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg pathLib[] = {
    {"new",    watcher_path_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_pathwatcher_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:pathLib metaFunctions:meta_gcLib objectFunctions:path_metalib];

    return 1;
}
