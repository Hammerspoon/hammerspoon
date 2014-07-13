#import "helpers.h"

/// event
///
/// For tapping into system events and stuff.

/// event:start()
/// Starts an event; must be in stopped state.

/// event:stop()
/// Stops an event; must be in started state.

typedef CGEventRef(^eventtap_closure)(CGEventRef event);

typedef struct _eventtap {
    BOOL started;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
    CGEventMask mask; // TODO
    eventtap_closure fn;
    int ref;
} eventtap;

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    eventtap* e = refcon;
    return e->fn(event);
}

static int event_eventtap_start(lua_State* L) {
    eventtap* e = luaL_checkudata(L, 1, "eventtap");
    
    if (e->started)
        return 0;
    
    e->started = YES;
    
    lua_getuservalue(L, 1);
    lua_getfield(L, -1, "fn");
    e->ref = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    
    e->fn = Block_copy(^CGEventRef(CGEventRef event){
        lua_rawgeti(L, LUA_REGISTRYINDEX, e->ref);
        hydra_pushpoint(L, [NSEvent mouseLocation]);
        
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
        
        return event;
    });
    
    e->tap = CGEventTapCreate(kCGSessionEventTap,
                              kCGHeadInsertEventTap,
                              kCGEventTapOptionDefault,
                              e->mask,
                              eventtap_callback,
                              e);
    
    CGEventTapEnable(e->tap, true);
    e->runloopsrc = CFMachPortCreateRunLoopSource(NULL, e->tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    
    return 0;
}

static int event_eventtap_stop(lua_State* L) {
    eventtap* e = luaL_checkudata(L, 1, "eventtap");
    
    if (!e->started)
        return 0;
    
    CGEventTapEnable(e->tap, false);
    CFMachPortInvalidate(e->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(e->runloopsrc);
    CFRelease(e->tap);
    
    Block_release(e->fn);
    luaL_unref(L, LUA_REGISTRYINDEX, e->ref);
    e->started = NO;
    
    return 0;
}

/// event.eventtap(fn(point)) -> event
/// Returns a new event tap with the given callback for the given events; is not started automatically.
static int event_eventtap(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    
    eventtap* e = lua_newuserdata(L, sizeof(eventtap));
    e->started = NO;
    e->mask = CGEventMaskBit(kCGEventMouseMoved);
    
    lua_newtable(L);
    lua_pushvalue(L, 1);
    lua_setfield(L, -2, "fn");
    lua_setuservalue(L, -2);
    
    luaL_getmetatable(L, "eventtap");
    lua_setmetatable(L, -2);
    
    return 1;
}

static luaL_Reg eventlib[] = {
    {"eventtap", event_eventtap},
    {NULL, NULL}
};

static luaL_Reg eventtaplib[] = {
    {"start", event_eventtap_start},
    {"stop", event_eventtap_stop},
    {NULL, NULL}
};

int luaopen_event(lua_State* L) {
    luaL_newmetatable(L, "eventtap");
    luaL_newlib(L, eventtaplib);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    
    luaL_newlib(L, eventlib);
    return 1;
}
