#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CGWindow.h>
#import <lauxlib.h>

/// === hs.spaces.watcher ===
///
/// Watches for space change events.

static const char* userdataTag = "hs.spaces.watcher";

typedef struct _spacewatcher_t {
    int self;
    bool running;
    int fn;
    void* obj;
    lua_State* L;
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
    lua_State* L = self.object->L;
    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.object->fn);

    lua_pushnumber(L, space);

    if (lua_pcall(L, 1, 0, -3) != 0) {
        // Show a traceback on error.
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs");
        lua_getfield(L, -1, "showError");
        lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}

- (void)spaceChanged:(NSNotification*)notification {
    int currentSpace = -1;
    // Get an array of all the windows in the current space.
    CFArrayRef windowsInSpace = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    // Now loop over the array looking for a window with the kCGWindowWorkspace key.
    for (NSMutableDictionary *thisWindow in (__bridge NSArray*)windowsInSpace) {
        if ([thisWindow objectForKey:(id)kCGWindowWorkspace]) {
            currentSpace = [[thisWindow objectForKey:(id)kCGWindowWorkspace] intValue];
            break;
        }
    }

    [self callback:[notification userInfo] withSpace:currentSpace];
}
@end

/// hs.spaces.watcher.new(handler) -> spacewatcher
/// Constructor
///
/// handler is a function that takes one argument, the space index, and is called when the current
/// space changes. The space index may be removed in future OSX versions.
static int space_watcher_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);

    spacewatcher_t* spaceWatcher = lua_newuserdata(L, sizeof(spacewatcher_t));

    lua_pushvalue(L, 1);
    spaceWatcher->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    spaceWatcher->running = NO;
    spaceWatcher->L = L;
    spaceWatcher->obj = (__bridge_retained void*) [[SpaceWatcher alloc] initWithObject:spaceWatcher];

    luaL_getmetatable(L, userdataTag);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.spaces.watcher:start()
/// Method
/// Tells the watcher to start watching for space change events.
static int space_watcher_start(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);
    lua_settop(L, 1);

    if (spaceWatcher->running)
        return 0;

    lua_pushvalue(L, 1);
    spaceWatcher->self = luaL_ref(L, LUA_REGISTRYINDEX);
    spaceWatcher->running = YES;

    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
    SpaceWatcher* observer = (__bridge SpaceWatcher*)spaceWatcher->obj;
    [center addObserver:observer
               selector:@selector(spaceChanged:)
                   name:NSWorkspaceActiveSpaceDidChangeNotification
                 object:nil];

    return 0;
}

/// hs.spaces.watcher:stop()
/// Method
/// Tells the watcher to stop watching for space change events.
static int space_watcher_stop(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);
    lua_settop(L, 1);

    if (!spaceWatcher->running)
        return 0;

    spaceWatcher->running = NO;
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:(__bridge SpaceWatcher*)spaceWatcher->obj];
    return 0;
}

static int space_watcher_gc(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);

    space_watcher_stop(L);
    luaL_unref(L, LUA_REGISTRYINDEX, spaceWatcher->fn);

    SpaceWatcher* object = (__bridge_transfer SpaceWatcher*)spaceWatcher->obj;
    object = nil;
    return 0;
}

static const luaL_Reg watcherlib[] = {
    {"new", space_watcher_new},
    {"start", space_watcher_start},
    {"stop", space_watcher_stop},
    {}
};

int luaopen_hs_spaces_watcher(lua_State* L) {
    luaL_newlib(L, watcherlib);

    if (luaL_newmetatable(L, userdataTag)) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, space_watcher_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);

    return 1;
}
