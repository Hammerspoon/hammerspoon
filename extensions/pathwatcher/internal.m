#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

// Common Code

#define USERDATA_TAG    "hs.pathwatcher"
static LSRefTable refTable;

// Not so common code

typedef struct _watcher_path_t {
    int closureref;
    FSEventStreamRef stream;
    bool started;
    LSGCCanary lsCanary;
} watcher_path_t;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
static const FSEventStreamEventFlags kFSEventStreamEventFlagOwnEvent           = 0x00080000;
#endif
#if MAC_OS_X_VERSION_MAX_ALLOWED < 101000
static const FSEventStreamEventFlags kFSEventStreamEventFlagItemIsHardlink     = 0x00100000;
static const FSEventStreamEventFlags kFSEventStreamEventFlagItemIsLastHardlink = 0x00200000;
#endif

static void pusheventflagstable(lua_State* L, FSEventStreamEventFlags flags) {
    lua_newtable(L);
    if ((flags & kFSEventStreamEventFlagMustScanSubDirs)    != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "mustScanSubDirs");    }
    if ((flags & kFSEventStreamEventFlagUserDropped)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "userDropped");        }
    if ((flags & kFSEventStreamEventFlagKernelDropped)      != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "kernelDropped");      }
    if ((flags & kFSEventStreamEventFlagEventIdsWrapped)    != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "eventIdsWrapped");    }
    if ((flags & kFSEventStreamEventFlagHistoryDone)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "historyDone");        }
    if ((flags & kFSEventStreamEventFlagRootChanged)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "rootChanged");        }
    if ((flags & kFSEventStreamEventFlagMount)              != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "mount");              }
    if ((flags & kFSEventStreamEventFlagUnmount)            != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "unmount");            }
    if ((flags & kFSEventStreamEventFlagOwnEvent)           != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "ownEvent");           }
    if ((flags & kFSEventStreamEventFlagItemCreated)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemCreated");        }
    if ((flags & kFSEventStreamEventFlagItemRemoved)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemRemoved");        }
    if ((flags & kFSEventStreamEventFlagItemInodeMetaMod)   != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemInodeMetaMod");   }
    if ((flags & kFSEventStreamEventFlagItemRenamed)        != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemRenamed");        }
    if ((flags & kFSEventStreamEventFlagItemModified)       != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemModified");       }
    if ((flags & kFSEventStreamEventFlagItemFinderInfoMod)  != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemFinderInfoMod");  }
    if ((flags & kFSEventStreamEventFlagItemChangeOwner)    != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemChangeOwner");    }
    if ((flags & kFSEventStreamEventFlagItemXattrMod)       != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemXattrMod");       }
    if ((flags & kFSEventStreamEventFlagItemIsFile)         != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemIsFile");         }
    if ((flags & kFSEventStreamEventFlagItemIsDir)          != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemIsDir");          }
    if ((flags & kFSEventStreamEventFlagItemIsSymlink)      != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemIsSymlink");      }
    if ((flags & kFSEventStreamEventFlagItemIsHardlink)     != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemIsHardlink");     }
    if ((flags & kFSEventStreamEventFlagItemIsLastHardlink) != 0) { lua_pushboolean(L, YES); lua_setfield(L, -2, "itemIsLastHardlink"); }
}

void event_callback(ConstFSEventStreamRef __unused streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId __unused eventIds[]) {
    watcher_path_t* pw = clientCallBackInfo;

    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;

    if (![skin checkGCCanary:pw->lsCanary]) {
        return;
    }

    _lua_stackguard_entry(skin.L);

    const char** changedFiles = eventPaths;

    [skin pushLuaRef:refTable ref:pw->closureref];

    lua_newtable(L);
    for(size_t i = 0 ; i < numEvents; i++) {
        lua_pushstring(L, changedFiles[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_newtable(L);
    for(size_t i = 0 ; i < numEvents; i++) {
        pusheventflagstable(L, eventFlags[i]);
        lua_rawseti(L, -2, i + 1);
    }

    [skin protectedCallAndError:@"hs.pathwatcher callback" nargs:2 nresults:0];
    _lua_stackguard_exit(skin.L);
}

/// hs.pathwatcher.new(path, fn) -> watcher
/// Constructor
/// Creates a new path watcher object
///
/// Parameters:
///  * path - A string containing the path to be watched
///  * fn - A function to be called when changes are detected. It should accept two arguments:
///    * `paths`: a table containing a list of file paths that have changed
///    * `flagTables`: a table containing a list of tables denoting how each corresponding file in `paths` has changed, each containing boolean values indicating which types of events occurred; The possible keys are:
///      * mustScanSubDirs
///      * userDropped
///      * kernelDropped
///      * eventIdsWrapped
///      * historyDone
///      * rootChanged
///      * mount
///      * unmount
///      * itemCreated
///      * itemRemoved
///      * itemInodeMetaMod
///      * itemRenamed
///      * itemModified
///      * itemFinderInfoMod
///      * itemChangeOwner
///      * itemXattrMod
///      * itemIsFile
///      * itemIsDir
///      * itemIsSymlink
///      * ownEvent (OS X 10.9+)
///      * itemIsHardlink (OS X 10.10+)
///      * itemIsLastHardlink (OS X 10.10+)
///
/// Returns:
///  * An `hs.pathwatcher` object
///
/// Notes:
///  * For more information about the event flags, see [the official documentation](https://developer.apple.com/reference/coreservices/1455361-fseventstreameventflags/)
static int watcher_path_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK];

    NSString* path = [NSString stringWithUTF8String: lua_tostring(L, 1)];

    watcher_path_t* watcher_path = lua_newuserdata(L, sizeof(watcher_path_t));
    watcher_path->started = NO;
    watcher_path->lsCanary = [skin createGCCanary];

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
                                              (__bridge CFArrayRef)@[[[path stringByStandardizingPath] stringByResolvingSymlinksInPath]],
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    watcher_path_t* watcher_path = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, watcher_path_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    FSEventStreamInvalidate(watcher_path->stream);
    FSEventStreamRelease(watcher_path->stream);

    watcher_path->closureref = [skin luaUnref:refTable ref:watcher_path->closureref];
    [skin destroyGCCanary:&(watcher_path->lsCanary)];

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

int luaopen_hs_libpathwatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:pathLib metaFunctions:meta_gcLib objectFunctions:path_metalib];

    return 1;
}
