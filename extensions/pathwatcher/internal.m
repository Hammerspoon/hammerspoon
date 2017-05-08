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

void event_callback(ConstFSEventStreamRef __unused streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId __unused eventIds[]) {
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
    lua_newtable(L);
    for(size_t i = 0 ; i < numEvents; i++) {
        lua_pushinteger(L, eventFlags[i]);
        lua_rawseti(L, -2, i + 1);
    }

    if (![skin protectedCallAndTraceback:2 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        [skin logError:[NSString stringWithFormat:@"hs.pathwatcher callback error: %s", errorMsg]];
        lua_pop(L, 1) ; // remove error message
    }
}

/// hs.pathwatcher.eventFlags -> table
/// Constant
/// A table containing event flags for use in a callback function.
///
/// The constants defined in this table are as follows:
///
///   * none
///   * mustScanSubDirs
///   * userDropped
///   * kernelDropped
///   * eventIdsWrapped
///   * historyDone
///   * rootChanged
///   * mount
///   * unmount
///   * itemCreated
///   * itemRemoved
///   * itemInodeMetaMod
///   * itemRenamed
///   * itemModified
///   * itemFinderInfoMod
///   * itemChangeOwner
///   * itemXattrMod
///   * itemIsFile
///   * itemIsDir
///   * itemIsSymlink
///   * ownEvent (OS X 10.9+)
///   * itemIsHardlink (OS X 10.10+)
///   * itemIsLastHardlink (OS X 10.10+)

static void pusheventflags(lua_State* L) {
    const double OSV = NSAppKitVersionNumber;

#ifndef NSAppKitVersionNumber10_9
#define NSAppKitVersionNumber10_9 1265
#endif

#ifndef NSAppKitVersionNumber10_10
#define NSAppKitVersionNumber10_10 1343
#endif

    lua_newtable(L);
    lua_pushinteger(L, kFSEventStreamEventFlagNone);                lua_setfield(L, -2, "none");
    lua_pushinteger(L, kFSEventStreamEventFlagMustScanSubDirs);     lua_setfield(L, -2, "mustScanSubDirs");
    lua_pushinteger(L, kFSEventStreamEventFlagUserDropped);         lua_setfield(L, -2, "userDropped");
    lua_pushinteger(L, kFSEventStreamEventFlagKernelDropped);       lua_setfield(L, -2, "kernelDropped");
    lua_pushinteger(L, kFSEventStreamEventFlagEventIdsWrapped);     lua_setfield(L, -2, "eventIdsWrapped");
    lua_pushinteger(L, kFSEventStreamEventFlagHistoryDone);         lua_setfield(L, -2, "historyDone");
    lua_pushinteger(L, kFSEventStreamEventFlagRootChanged);         lua_setfield(L, -2, "rootChanged");
    lua_pushinteger(L, kFSEventStreamEventFlagMount);               lua_setfield(L, -2, "mount");
    lua_pushinteger(L, kFSEventStreamEventFlagUnmount);             lua_setfield(L, -2, "unmount");
    lua_pushinteger(L, kFSEventStreamEventFlagItemCreated);         lua_setfield(L, -2, "itemCreated");
    lua_pushinteger(L, kFSEventStreamEventFlagItemRemoved);         lua_setfield(L, -2, "itemRemoved");
    lua_pushinteger(L, kFSEventStreamEventFlagItemInodeMetaMod);    lua_setfield(L, -2, "itemInodeMetaMod");
    lua_pushinteger(L, kFSEventStreamEventFlagItemRenamed);         lua_setfield(L, -2, "itemRenamed");
    lua_pushinteger(L, kFSEventStreamEventFlagItemModified);        lua_setfield(L, -2, "itemModified");
    lua_pushinteger(L, kFSEventStreamEventFlagItemFinderInfoMod);   lua_setfield(L, -2, "itemFinderInfoMod");
    lua_pushinteger(L, kFSEventStreamEventFlagItemChangeOwner);     lua_setfield(L, -2, "itemChangeOwner");
    lua_pushinteger(L, kFSEventStreamEventFlagItemXattrMod);        lua_setfield(L, -2, "itemXattrMod");
    lua_pushinteger(L, kFSEventStreamEventFlagItemIsFile);          lua_setfield(L, -2, "itemIsFile");
    lua_pushinteger(L, kFSEventStreamEventFlagItemIsDir);           lua_setfield(L, -2, "itemIsDir");
    lua_pushinteger(L, kFSEventStreamEventFlagItemIsSymlink);       lua_setfield(L, -2, "itemIsSymlink");
    if (OSV >= NSAppKitVersionNumber10_9) {
        lua_pushinteger(L, kFSEventStreamEventFlagOwnEvent);            lua_setfield(L, -2, "ownEvent");
    }
    if (OSV >= NSAppKitVersionNumber10_10) {
        lua_pushinteger(L, kFSEventStreamEventFlagItemIsHardlink);      lua_setfield(L, -2, "itemIsHardlink");
        lua_pushinteger(L, kFSEventStreamEventFlagItemIsLastHardlink);  lua_setfield(L, -2, "itemIsLastHardlink");
    }
}

/// hs.pathwatcher.new(path, fn) -> watcher
/// Constructor
/// Creates a new path watcher object
///
/// Parameters:
///  * path - A string containing the path to be watched
///  * fn - A function to be called when changes are detected. It should accept two arguments, a table containing a list of files that have changed and a table containing a list of flags denoting how each corresponding file has changed
///
/// Returns:
///  * An `hs.pathwatcher` object
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
/// Starts a path watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.pathwatcher` object
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
/// Stops a path watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
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

    pusheventflags(L);
    lua_setfield(L, -2, "eventFlags");

    return 1;
}
