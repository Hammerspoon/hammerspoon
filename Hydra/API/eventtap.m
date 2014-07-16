#import "helpers.h"

/// eventtap
///
/// For tapping into input events (mouse, keyboard, trackpad) for observation and possibly overriding them.

typedef struct _eventtap {
    lua_State* L;
    BOOL started;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
    CGEventMask mask;
    int ref;
} eventtap_t;

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

/// eventtap.new(type, callback) -> eventtap
/// Returns a new event tap with the given callback for the given event type; the eventtap not started automatically.
/// The type param must be one of the values from the table `eventtap.types`.
/// If the callback function returns nothing, the event is not modified; if it returns nil, the event is deleted from the OS X event system and not seen by any other apps; all other return values are reserved for future features to this API.
/// The callback usually takes no params, except for certain events:
///   flagschanged: takes a table with any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
static int eventtap_new(lua_State* L) {
    CGEventMask type = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);
    
    eventtap_t* e = lua_newuserdata(L, sizeof(eventtap_t));
    memset(e, 0, sizeof(eventtap_t));
    e->L = L;
    e->mask = type;
    
    lua_pushvalue(L, 2);
    e->ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    luaL_getmetatable(L, "eventtap");
    lua_setmetatable(L, -2);
    
    return 1;
}

/// eventtap:start()
/// Starts an event tap; must be in stopped state.
static int eventtap_start(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, "eventtap");
    
    if (e->started)
        return 0;
    
    e->started = YES;
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
    
    if (!e->started)
        return 0;
    
    CGEventTapEnable(e->tap, false);
    CFMachPortInvalidate(e->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(e->runloopsrc);
    CFRelease(e->tap);
    
    e->started = NO;
    
    return 0;
}

static int eventtap_gc(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, "eventtap");
    luaL_unref(L, LUA_REGISTRYINDEX, e->ref);
    return 0;
}

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    eventtap_t* e = refcon;
    lua_State* L = e->L;
    
    int stack = lua_gettop(L);
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->ref);
    
    int nargs = 0;
    
    if (e->mask == CGEventMaskBit(kCGEventFlagsChanged)) {
        nargs++;
        lua_newtable(L);
        CGEventFlags curAltkey = CGEventGetFlags(event);
        if (curAltkey & kCGEventFlagMaskAlternate) { lua_pushboolean(L, YES); lua_setfield(L, -2, "alt"); }
        if (curAltkey & kCGEventFlagMaskShift) { lua_pushboolean(L, YES); lua_setfield(L, -2, "shift"); }
        if (curAltkey & kCGEventFlagMaskControl) { lua_pushboolean(L, YES); lua_setfield(L, -2, "ctrl"); }
        if (curAltkey & kCGEventFlagMaskCommand) { lua_pushboolean(L, YES); lua_setfield(L, -2, "cmd"); }
        if (curAltkey & kCGEventFlagMaskSecondaryFn) { lua_pushboolean(L, YES); lua_setfield(L, -2, "fn"); } // no idea if 'fn' key counts here
    }
    
    if (lua_pcall(L, nargs, LUA_MULTRET, 0))
        hydra_handle_error(L);
    
    int nret = lua_gettop(L) - stack;
    
    if (nret == 1) {
        if (lua_isnil(L, -1)) {
            return NULL;
        }
        else {
            // TODO: allow user to modify event somehow
            return event;
        }
    }
    else {
        return event;
    }
}

static void postkeyevent(CGKeyCode virtualKey, CGEventFlags flags, bool keyDown) {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState); // UNTESTED; copied from Zephyros
    CGEventRef event = CGEventCreateKeyboardEvent(source, virtualKey, keyDown);
    CGEventSetFlags(event, flags);
    CGEventPost(kCGSessionEventTap, event);
    CFRelease(event);
}

/// eventtap.postkey(keycode, mods, dir = "pressrelease")
/// Sends a keyboard event as if you did it manually.
///   keycode is a numeric value from `hotkey.keycodes`
///   dir is either 'press', 'release', or 'pressrelease'
///   mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift'}
/// Sometimes this doesn't work inside a hotkey callback for some reason.
static int eventtap_postkey(lua_State* L) {
    CGKeyCode keycode = luaL_checknumber(L, 1);
    int dir = luaL_checknumber(L, 2);
    
    CGEventFlags flags = 0;
    if (lua_toboolean(L, 3)) flags |= kCGEventFlagMaskControl;
    if (lua_toboolean(L, 4)) flags |= kCGEventFlagMaskAlternate;
    if (lua_toboolean(L, 5)) flags |= kCGEventFlagMaskCommand;
    if (lua_toboolean(L, 6)) flags |= kCGEventFlagMaskShift;
    
    if (dir == 3) {
        postkeyevent(keycode, flags, true);
        postkeyevent(keycode, flags, false);
    }
    else {
        BOOL isdown = (dir == 2);
        postkeyevent(keycode, flags, isdown);
    }
    
    return 0;
}

static luaL_Reg inputlib[] = {
    // class methods
    {"new", eventtap_new},
    {"postkey", eventtap_postkey},
    
    // instance methods
    {"start", eventtap_start},
    {"stop", eventtap_stop},
    
    // metamethods
    {"__gc", eventtap_gc},
    
    {NULL, NULL}
};

/// eventtap.types
/// Table for use with `eventtap.new`, with the following keys:
///   leftmousedown, leftmouseup, leftmousedragged,
///   rightmousedown, rightmouseup, rightmousedragged,
///   middlemousedown, middlemouseup, middlemousedragged,
///   keydown, keyup, mousemoved, flagschanged, scrollwheel
static void addtypestable(lua_State* L) {
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
    luaL_newlib(L, inputlib);
    
    // store in registry for metatables; necessary for luaL_checkudata()
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "eventtap");
    
    // eventtap.__index = eventtap
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // eventtap.types = {...}
    addtypestable(L);
    lua_setfield(L, -2, "types");
    
    return 1;
}
