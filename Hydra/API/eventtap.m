#import "helpers.h"
void new_eventtap_event(lua_State* L, CGEventRef event);

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
    
    int stackbefore = lua_gettop(L);
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->fn);
    
    new_eventtap_event(L, event);
    
    lua_pcall(L, 1, 0, 0);
    
    
//    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;
//    CFRetain(event);
    
//    lua_getfield(L, LUA_REGISTRYINDEX, "eventtap.event");
//    lua_setmetatable(L, -2);
    
//    if (lua_pcall(L, 1, LUA_MULTRET, 0))
//        hydra_handle_error(L);
//    
//    int nret = lua_gettop(L) - stack;
//    if (nret == 1 && lua_isnil(L, -1))
//        event = NULL;
//    
//    if (nret > 0)
//        lua_pop(L, nret);
    
    return event;
}

/// eventtap.new(eventmask, callback(event)) -> eventtap
/// Returns a new event tap with the given callback for the given event type; the eventtap not started automatically.
/// The eventmask param must be one of the values from the table `eventtap.types`, or multiple bitwise-OR'd together.
/// The callback takes an event object as its only parameter.
/// If the callback function returns no values, the event is not modified; if it returns nil as its first value, the event is deleted from the OS X event system and not seen by any other apps; all other return values are reserved for future changes to this API.
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





//static void postkeyevent(CGKeyCode virtualKey, CGEventFlags flags, bool keyDown) {
//    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
//    CGEventRef event = CGEventCreateKeyboardEvent(source, virtualKey, keyDown);
//    CGEventSetFlags(event, flags);
//    CGEventPost(kCGSessionEventTap, event);
//    CFRelease(event);
//}
//
///// eventtap.postkey(mods, key, dir = "pressrelease")
///// Sends a keyboard event as if you did it manually.
/////   - key has the same meaning as in the `hotkey` module
/////   - dir is either 'press', 'release', or 'pressrelease'
/////   - mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift', 'fn'}
///// Sometimes this doesn't work inside a hotkey callback for some reason.
//static int eventtap_postkey(lua_State* L) {
//    luaL_checktype(L, 1, LUA_TTABLE);
//    const char* key = luaL_checkstring(L, 2);
//    const char* dir = luaL_checkstring(L, 3);
//    
//    lua_getglobal(L, "hotkey");
//    lua_getfield(L, -1, "keycodes");
//    lua_pushstring(L, key);
//    lua_gettable(L, -2);
//    CGKeyCode keycode = lua_tonumber(L, -1);
//    lua_pop(L, 2);
//    
//    CGEventFlags flags = 0;
//    lua_pushnil(L);
//    while (lua_next(L, 1) != 0) {
//        if (strcmp(lua_tostring(L, -1), "cmd") == 0) flags |= kCGEventFlagMaskCommand;
//        else if (strcmp(lua_tostring(L, -1), "ctrl") == 0) flags |= kCGEventFlagMaskControl;
//        else if (strcmp(lua_tostring(L, -1), "alt") == 0) flags |= kCGEventFlagMaskAlternate;
//        else if (strcmp(lua_tostring(L, -1), "shift") == 0) flags |= kCGEventFlagMaskShift;
//        else if (strcmp(lua_tostring(L, -1), "fn") == 0) flags |= kCGEventFlagMaskSecondaryFn;
//        lua_pop(L, 1);
//    }
//    
//    if (dir == NULL || strcmp(dir, "pressrelease") == 0) {
//        postkeyevent(keycode, flags, true);
//        postkeyevent(keycode, flags, false);
//    }
//    else {
//        BOOL isdown = (strcmp(dir, "press") == 0);
//        postkeyevent(keycode, flags, isdown);
//    }
//    
//    return 0;
//}
//
///// eventtap.getflags(event) -> table
///// Returns a table with any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
//static int eventtap_event_getflags(lua_State* L) {
//    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap.event");
//    
//    lua_newtable(L);
//    CGEventFlags curAltkey = CGEventGetFlags(event);
//    if (curAltkey & kCGEventFlagMaskAlternate) { lua_pushboolean(L, YES); lua_setfield(L, -2, "alt"); }
//    if (curAltkey & kCGEventFlagMaskShift) { lua_pushboolean(L, YES); lua_setfield(L, -2, "shift"); }
//    if (curAltkey & kCGEventFlagMaskControl) { lua_pushboolean(L, YES); lua_setfield(L, -2, "ctrl"); }
//    if (curAltkey & kCGEventFlagMaskCommand) { lua_pushboolean(L, YES); lua_setfield(L, -2, "cmd"); }
//    if (curAltkey & kCGEventFlagMaskSecondaryFn) { lua_pushboolean(L, YES); lua_setfield(L, -2, "fn"); }
//    return 1;
//}
//
///// eventtap.setflags(event, table)
///// The table may have any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
//static int eventtap_event_setflags(lua_State* L) {
//    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap.event");
//    luaL_checktype(L, 2, LUA_TTABLE);
//    
//    CGEventFlags flags = 0;
//    
//    if (lua_getfield(L, 2, "cmd"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskCommand;
//    if (lua_getfield(L, 2, "alt"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskAlternate;
//    if (lua_getfield(L, 2, "ctrl"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskControl;
//    if (lua_getfield(L, 2, "shift"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskShift;
//    if (lua_getfield(L, 2, "fn"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskSecondaryFn;
//    
//    CGEventSetFlags(event, flags);
//    
//    return 0;
//}
//
///// eventtap.getkeycode(event) -> keycode
///// Gets the keycode for the given event; only applicable for key-related events.
///// The keycode is a numeric value from the `hotkey.keycodes` table.
//static int eventtap_event_getkeycode(lua_State* L) {
//    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap.event");
//    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
//    lua_pushnumber(L, keycode);
//    return 1;
//}
//
///// eventtap.setkeycode(event, keycode)
///// Sets the keycode for the given event; only applicable for key-related events.
///// The keycode is a numeric value from the `hotkey.keycodes` table.
//static int eventtap_event_setkeycode(lua_State* L) {
//    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap.event");
//    CGKeyCode keycode = luaL_checknumber(L, 2);
//    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, (int64_t)keycode);
//    return 0;
//}
//
//static int eventtap_event_gc(lua_State* L) {
//    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap.event");
//    NSLog(@"bye");
//    CFRelease(event);
//    return 0;
//}
//
///// === eventtap.event ===
/////
///// For inspecting, modifying, and creating events for the `eventtap` module
//
//static luaL_Reg eventtap_eventlib[] = {
//    {"getflags", eventtap_event_getflags},
//    {"setflags", eventtap_event_setflags},
//    {"getkeycode", eventtap_event_getkeycode},
//    {"setkeycode", eventtap_event_setkeycode},
//    {"__gc", eventtap_event_gc},
//    {NULL, NULL}
//};
