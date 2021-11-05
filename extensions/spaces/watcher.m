#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CGWindow.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.spaces.watcher ===
///
/// Watches for the current Space being changed
/// NOTE: This extension determines the number of a Space, using OS X APIs that have been deprecated since 10.8 and will likely be removed in a future release. You should not depend on Space numbers being around forever!

#define USERDATA_TAG "hs.spaces.watcher"
static LSRefTable refTable;

typedef struct _spacewatcher_t {
    int self;
    bool running;
    int fn;
    void* obj;
} spacewatcher_t;

@interface SpaceWatcher : NSObject
@property spacewatcher_t* object;
- (id)initWithObject:(spacewatcher_t*)object;
@end

@implementation SpaceWatcher
- (id)initWithObject:(spacewatcher_t*)object {
    if (self = [super init]) {
        self.object = object;
    }
    return self;
}

// Call the lua callback function.
- (void)callback:(NSDictionary* __unused)dict withSpace:(int)space {
    if (self.object->fn != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L = skin.L;
        _lua_stackguard_entry(L);

        [skin pushLuaRef:refTable ref:self.object->fn];
        lua_pushinteger(L, space);
        [skin protectedCallAndError:@"hs.spaces.watcher callback" nargs:1 nresults:0];
        _lua_stackguard_exit(L);
    }
}

- (void)spaceChanged:(NSNotification*)notification {
    int currentSpace = -1;
    // Get an array of all the windows in the current space.
    NSArray *windowsInSpace = (__bridge_transfer NSArray *)CGWindowListCopyWindowInfo(kCGWindowListOptionAll | kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    // Now loop over the array looking for a window with the kCGWindowWorkspace key.
    for (NSMutableDictionary *thisWindow in windowsInSpace) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([thisWindow objectForKey:(id)kCGWindowWorkspace]) {
            currentSpace = [[thisWindow objectForKey:(id)kCGWindowWorkspace] intValue];
#pragma clang diagnostic pop
            break;
        }
    }

    [self callback:[notification userInfo] withSpace:currentSpace];
}
@end

/// hs.spaces.watcher.new(handler) -> watcher
/// Constructor
/// Creates a new watcher for Space change events
///
/// Parameters:
///  * handler - A function to be called when the active Space changes. It should accept one argument, which will be the number of the new Space (or -1 if the number cannot be determined)
///
/// Returns:
///  * An `hs.spaces.watcher` object
static int space_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    spacewatcher_t* spaceWatcher = lua_newuserdata(L, sizeof(spacewatcher_t));

    lua_pushvalue(L, 1);
    spaceWatcher->fn = [skin luaRef:refTable];
    spaceWatcher->running = NO;
    spaceWatcher->obj = (__bridge_retained void*) [[SpaceWatcher alloc] initWithObject:spaceWatcher];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.spaces.watcher:start()
/// Method
/// Starts the Spaces watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The watcher object
static int space_watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushvalue(L, 1);

    if (spaceWatcher->running)
        return 1;

    spaceWatcher->self = [skin luaRef:refTable];
    spaceWatcher->running = YES;

    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    SpaceWatcher* observer = (__bridge SpaceWatcher*)spaceWatcher->obj;
    [center addObserver:observer
               selector:@selector(spaceChanged:)
                   name:NSWorkspaceActiveSpaceDidChangeNotification
                 object:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.spaces.watcher:stop()
/// Method
/// Stops the Spaces watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The watcher object
static int space_watcher_stop(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushvalue(L, 1);

    if (!spaceWatcher->running)
        return 1;

    spaceWatcher->running = NO;
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:(__bridge SpaceWatcher*)spaceWatcher->obj];
    return 1;
}

static int space_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    space_watcher_stop(L);

    spaceWatcher->fn = [skin luaUnref:refTable ref:spaceWatcher->fn];

    SpaceWatcher* object = (__bridge_transfer SpaceWatcher*)spaceWatcher->obj;
    object = nil;
    return 0;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg watcherlib[] = {
    {"new", space_watcher_new},
    {NULL, NULL}
};

static const luaL_Reg watcher_objectlib[] = {
    {"start", space_watcher_start},
    {"stop", space_watcher_stop},
    {"__tostring", userdata_tostring},
    {"__gc", space_watcher_gc},
    {NULL, NULL}
};

int luaopen_hs_libspaceswatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:watcherlib metaFunctions:nil objectFunctions:watcher_objectlib];

    return 1;
}
