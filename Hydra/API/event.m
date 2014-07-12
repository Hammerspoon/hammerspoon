#import "helpers.h"

typedef struct _mousemoved_state {
    lua_State* L;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
} mousemoved_state;

CGEventRef mousemoved_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    mousemoved_state* state = refcon;
    lua_State* L = state->L;
    return event;
}

static int event_mousemoved(lua_State* L) {
    mousemoved_state* state = malloc(sizeof(mousemoved_state));
    state->L = L;
    state->tap = CGEventTapCreate(kCGHIDEventTap,
                                  kCGHeadInsertEventTap,
                                  kCGEventTapOptionListenOnly,
                                  CGEventMaskBit(kCGEventMouseMoved),
                                  mousemoved_callback,
                                  state);
    
    CGEventTapEnable(state->tap, true);
    state->runloopsrc = CFMachPortCreateRunLoopSource(NULL, state->tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), state->runloopsrc, kCFRunLoopCommonModes);
    
    lua_pushlightuserdata(L, state);
    return 1;
    
    
    
    
//    CGEventTapEnable(tap, false);
//    CFMachPortInvalidate(tap);
//    CFRunLoopRemoveSource(CFRunLoopGetMain(), runloopsrc, kCFRunLoopCommonModes);
//    CFRelease(runloopsrc);
//    CFRelease(tap);
    
    return 0;
}

static luaL_Reg eventlib[] = {
    {"mousemoved", event_mousemoved},
    {NULL, NULL}
};

int luaopen_event(lua_State* L) {
    luaL_newlib(L, eventlib);
    
    if (luaL_newmetatable(L, "event")) {
        // ...
    }
    
    return 1;
}
