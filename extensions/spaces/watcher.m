#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CGWindow.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.spaces.watcher ===
///
/// Watches for the current Space being changed
/// NOTE: This extension determines the number of a Space, using OS X APIs that have been deprecated since 10.8 and will likely be removed in a future release. You should not depend on Space numbers being around forever!

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

    lua_pushinteger(L, space);

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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([thisWindow objectForKey:(id)kCGWindowWorkspace]) {
            currentSpace = [[thisWindow objectForKey:(id)kCGWindowWorkspace] intValue];
#pragma clang diagnostic pop
            break;
        }
    }

    CFRelease(windowsInSpace);

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
/// Starts the Spaces watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The watcher object
static int space_watcher_start(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);
    lua_settop(L, 1);
    lua_pushvalue(L, 1);

    if (spaceWatcher->running)
        return 1;

    spaceWatcher->self = luaL_ref(L, LUA_REGISTRYINDEX);
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
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);
    lua_settop(L, 1);
    lua_pushvalue(L, 1);

    if (!spaceWatcher->running)
        return 1;

    spaceWatcher->running = NO;
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:(__bridge SpaceWatcher*)spaceWatcher->obj];
    return 1;
}

static int space_watcher_gc(lua_State* L) {
    spacewatcher_t* spaceWatcher = luaL_checkudata(L, 1, userdataTag);

    space_watcher_stop(L);
    luaL_unref(L, LUA_REGISTRYINDEX, spaceWatcher->fn);
    spaceWatcher->fn = LUA_NOREF;

    SpaceWatcher* object = (__bridge_transfer SpaceWatcher*)spaceWatcher->obj;
    object = nil;
    return 0;
}

static const luaL_Reg watcherlib[] = {
    {"new", space_watcher_new},
    {"start", space_watcher_start},
    {"stop", space_watcher_stop},
    {NULL, NULL}
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
