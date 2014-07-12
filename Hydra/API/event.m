#import "helpers.h"

/// event
///
/// For tapping into system events and stuff.

/// event:start()
/// Starts an event; must be in stopped state.

/// event:stop()
/// Stops an event; must be in started state.

typedef struct _tapevent {
    lua_State* L;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
    int fn;
} tapevent;

CGEventRef mousemoved_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    tapevent* e = refcon;
    lua_State* L = e->L;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->fn);
    hydra_pushpoint(L, [NSEvent mouseLocation]);
    
    if (lua_pcall(L, 1, 0, 0))
        hydra_handle_error(L);
    
    return event;
}

static int event_mousemoved_start(lua_State* L) {
    tapevent* e = luaL_checkudata(L, 1, "mousemovedevent");
    
    if (e->tap)
        return 0;
    
    lua_getuservalue(L, 1);
    lua_getfield(L, -1, "fn");
    e->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    
    e->tap = CGEventTapCreate(kCGHIDEventTap,
                                     kCGHeadInsertEventTap,
                                     kCGEventTapOptionListenOnly,
                                     CGEventMaskBit(kCGEventMouseMoved),
                                     mousemoved_callback,
                                     e);
    
    CGEventTapEnable(e->tap, true);
    e->runloopsrc = CFMachPortCreateRunLoopSource(NULL, e->tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    
    return 0;
}

static int event_mousemoved_stop(lua_State* L) {
    tapevent* e = luaL_checkudata(L, 1, "mousemovedevent");
    
    if (!e->tap)
        return 0;
    
    CGEventTapEnable(e->tap, false);
    CFMachPortInvalidate(e->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(e->runloopsrc);
    CFRelease(e->tap);
    
    luaL_unref(L, LUA_REGISTRYINDEX, e->fn);
    e->tap = NULL;
    
    return 0;
}

/// event.mousemoved(fn(point)) -> event
/// Returns a new event with the given callback for mouse-moved events; is not started automatically.
static int event_mousemoved(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    
    tapevent* e = lua_newuserdata(L, sizeof(e));
    e->L = L;
    e->tap = NULL;
    
    lua_newtable(L);
    lua_pushvalue(L, 1);
    lua_setfield(L, -2, "fn");
    lua_setuservalue(L, -2);
    
    luaL_getmetatable(L, "mousemovedevent");
    lua_setmetatable(L, -2);
    
    return 1;
}

static luaL_Reg eventlib[] = {
    {"mousemoved", event_mousemoved},
    {NULL, NULL}
};

static luaL_Reg mousemovedlib[] = {
    {"start", event_mousemoved_start},
    {"stop", event_mousemoved_stop},
    {NULL, NULL}
};

int luaopen_event(lua_State* L) {
    luaL_newmetatable(L, "mousemovedevent");
    luaL_newlib(L, mousemovedlib);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    
    luaL_newlib(L, eventlib);
    return 1;
}
