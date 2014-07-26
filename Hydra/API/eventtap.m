#import "helpers.h"
void new_eventtap_event(lua_State* L, CGEventRef event);
CGEventRef hydra_to_eventtap_event(lua_State* L, int idx);

/// === eventtap ===
///
/// For tapping into input events (mouse, keyboard, trackpad) for observation and possibly overriding them.


typedef struct _eventtap_t {
    lua_State* L;
    bool running;
    int fn;
    int self;
    CGEventMask mask;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
} eventtap_t;


CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    eventtap_t* e = refcon;
    lua_State* L = e->L;
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->fn);
    new_eventtap_event(L, event);
    
    if (lua_pcall(L, 1, 2, 0))
        hydra_handle_error(L);
    
    bool ignoreevent = lua_toboolean(L, -2);
    
    if (lua_istable(L, -1)) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            CGEventRef event = hydra_to_eventtap_event(L, -1);
            CGEventTapPostEvent(proxy, event);
            lua_pop(L, 1);
        }
    }
    
    lua_pop(L, 2);
    
    if (ignoreevent)
        return NULL;
    else
        return event;
}

/// eventtap.new(eventmask, callback(event) -> ignoreevent, moreevents) -> eventtap
/// Returns a new event tap with the given callback for the given event type; the eventtap not started automatically.
/// The eventmask param must be one of the values from the table `eventtap.types`, or multiple bitwise-OR'd together.
/// The callback takes an event object as its only parameter. It can optionally return two values: if the first one is truthy, this event is deleted from the system input event stream and not seen by any other app; if the second one is a table of events, they will each be posted along with this event.
static int eventtap_new(lua_State* L) {
    int mask = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    
    eventtap_t* eventtap = lua_newuserdata(L, sizeof(eventtap_t));
    memset(eventtap, 0, sizeof(eventtap_t));
    
    eventtap->L = L;
    eventtap->mask = mask;
    
    lua_pushvalue(L, 2);
    eventtap->fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    luaL_getmetatable(L, "eventtap");
    lua_setmetatable(L, -2);
    
    return 1;
}

/// eventtap:start()
/// Starts an event tap; must be in stopped state.
static int eventtap_start(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, "eventtap");
    
    if (e->running)
        return 0;
    
    e->self = hydra_store_handler(L, 1);
    e->running = true;
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

/// eventtap:stop()
/// Stops an event tap; must be in started state.
static int eventtap_stop(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, "eventtap");
    
    if (!e->running)
        return 0;
    
    hydra_remove_handler(L, e->self);
    e->running = false;
    
    CGEventTapEnable(e->tap, false);
    CFMachPortInvalidate(e->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(e->runloopsrc);
    CFRelease(e->tap);
    
    return 0;
}

/// eventtap.stopall()
/// Stops all event taps; called automatically when the user's config reloads.
static int eventtap_stopall(lua_State* L) {
    lua_getglobal(L, "eventtap");
    lua_getfield(L, -1, "stop");
    hydra_remove_all_handlers(L, "eventtap");
    return 0;
}

static int eventtap_gc(lua_State* L) {
    eventtap_t* eventtap = luaL_checkudata(L, 1, "eventtap");
    luaL_unref(L, LUA_REGISTRYINDEX, eventtap->fn);
    return 0;
}

/// eventtap.types
/// Table for use with `eventtap.new`, with the following keys:
///   leftmousedown, leftmouseup, leftmousedragged,
///   rightmousedown, rightmouseup, rightmousedragged,
///   middlemousedown, middlemouseup, middlemousedragged,
///   keydown, keyup, mousemoved, flagschanged, scrollwheel
static void pushtypestable(lua_State* L) {
    lua_newtable(L);
    lua_pushnumber(L, CGEventMaskBit(kCGEventLeftMouseDown));     lua_setfield(L, -2, "leftmousedown");
    lua_pushnumber(L, CGEventMaskBit(kCGEventLeftMouseUp));       lua_setfield(L, -2, "leftmouseup");
    lua_pushnumber(L, CGEventMaskBit(kCGEventLeftMouseDragged));  lua_setfield(L, -2, "leftmousedragged");
    lua_pushnumber(L, CGEventMaskBit(kCGEventRightMouseDown));    lua_setfield(L, -2, "rightmousedown");
    lua_pushnumber(L, CGEventMaskBit(kCGEventRightMouseUp));      lua_setfield(L, -2, "rightmouseup");
    lua_pushnumber(L, CGEventMaskBit(kCGEventRightMouseDragged)); lua_setfield(L, -2, "rightmousedragged");
    lua_pushnumber(L, CGEventMaskBit(kCGEventOtherMouseDown));    lua_setfield(L, -2, "middlemousedown");
    lua_pushnumber(L, CGEventMaskBit(kCGEventOtherMouseUp));      lua_setfield(L, -2, "middlemouseup");
    lua_pushnumber(L, CGEventMaskBit(kCGEventOtherMouseDragged)); lua_setfield(L, -2, "middlemousedragged");
    lua_pushnumber(L, CGEventMaskBit(kCGEventMouseMoved));        lua_setfield(L, -2, "mousemoved");
    lua_pushnumber(L, CGEventMaskBit(kCGEventFlagsChanged));      lua_setfield(L, -2, "flagschanged");
    lua_pushnumber(L, CGEventMaskBit(kCGEventScrollWheel));       lua_setfield(L, -2, "scrollwheel");
    lua_pushnumber(L, CGEventMaskBit(kCGEventKeyDown));           lua_setfield(L, -2, "keydown");
    lua_pushnumber(L, CGEventMaskBit(kCGEventKeyUp));             lua_setfield(L, -2, "keyup");
}

static luaL_Reg eventtaplib[] = {
    // module methods
    {"new", eventtap_new},
    {"stopall", eventtap_stopall},
    
    // instance methods
    {"start", eventtap_start},
    {"stop", eventtap_stop},
    
    // metamethods
    {"__gc", eventtap_gc},
    
    // sentinel
    {}
};

int luaopen_eventtap(lua_State* L) {
    luaL_newlib(L, eventtaplib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "eventtap");
    
    pushtypestable(L);
    lua_setfield(L, -2, "types");
    
    return 1;
}
