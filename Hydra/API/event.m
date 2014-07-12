#import "helpers.h"

/// event
///
/// For tapping into system events and stuff.

typedef struct _tapevent {
    lua_State* L;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
    int fn;
} tapevent;

CGEventRef mousemoved_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    tapevent* tapevent = refcon;
    lua_State* L = tapevent->L;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, tapevent->fn);
    hydra_pushpoint(L, [NSEvent mouseLocation]);
    
    if (lua_pcall(L, 1, 0, 0))
        hydra_handle_error(L);
    
    return event;
}

static int event__mousemoved_start(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    
    lua_getfield(L, 1, "callback");
    int fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    tapevent* tapevent = malloc(sizeof(tapevent));
    tapevent->L = L;
    tapevent->fn = fn;
    tapevent->tap = CGEventTapCreate(kCGHIDEventTap,
                                     kCGHeadInsertEventTap,
                                     kCGEventTapOptionListenOnly,
                                     CGEventMaskBit(kCGEventMouseMoved),
                                     mousemoved_callback,
                                     tapevent);
    
    CGEventTapEnable(tapevent->tap, true);
    tapevent->runloopsrc = CFMachPortCreateRunLoopSource(NULL, tapevent->tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), tapevent->runloopsrc, kCFRunLoopCommonModes);
    
    lua_pushlightuserdata(L, tapevent);
    lua_setfield(L, 1, "__tapevent");
    
    return 0;
}

static int event__mousemoved_stop(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    
    lua_getfield(L, 1, "__tapevent");
    tapevent* tapevent = lua_touserdata(L, -1);
    
    CGEventTapEnable(tapevent->tap, false);
    CFMachPortInvalidate(tapevent->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), tapevent->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(tapevent->runloopsrc);
    CFRelease(tapevent->tap);
    
    luaL_unref(L, LUA_REGISTRYINDEX, tapevent->fn);
    
    return 0;
}

static int event__mousemoved_gc(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    
    lua_getfield(L, 1, "__tapevent");
    tapevent* tapevent = lua_touserdata(L, -1);
    free(tapevent);
    
    return 0;
}

static luaL_Reg eventlib[] = {
    {"_mousemoved_start", event__mousemoved_start},
    {"_mousemoved_stop", event__mousemoved_stop},
    {"_mousemoved_gc", event__mousemoved_gc},
    {NULL, NULL}
};

int luaopen_event(lua_State* L) {
    luaL_newlib(L, eventlib);
    return 1;
}
