#import "helpers.h"

/// === eventtap.event ===
///
/// Functionality to inspect, modify, and create events; for use with the `eventtap` module

CGEventRef hydra_to_eventtap_event(lua_State* L, int idx) {
    return *(CGEventRef*)luaL_checkudata(L, idx, "eventtap_event");
}

void new_eventtap_event(lua_State* L, CGEventRef event) {
    CFRetain(event);
    *(CGEventRef*)lua_newuserdata(L, sizeof(CGEventRef*)) = event;
    
    luaL_getmetatable(L, "eventtap_event");
    lua_setmetatable(L, -2);
}

static int eventtap_event_gc(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CFRelease(event);
    return 0;
}

static int eventtap_event_copy(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    
    CGEventRef copy = CGEventCreateCopy(event);
    new_eventtap_event(L, copy);
    CFRelease(copy);
    
    return 1;
}

/// eventtap.event:getflags() -> table
/// Returns a table with any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
static int eventtap_event_getflags(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    
    lua_newtable(L);
    CGEventFlags curAltkey = CGEventGetFlags(event);
    if (curAltkey & kCGEventFlagMaskAlternate) { lua_pushboolean(L, YES); lua_setfield(L, -2, "alt"); }
    if (curAltkey & kCGEventFlagMaskShift) { lua_pushboolean(L, YES); lua_setfield(L, -2, "shift"); }
    if (curAltkey & kCGEventFlagMaskControl) { lua_pushboolean(L, YES); lua_setfield(L, -2, "ctrl"); }
    if (curAltkey & kCGEventFlagMaskCommand) { lua_pushboolean(L, YES); lua_setfield(L, -2, "cmd"); }
    if (curAltkey & kCGEventFlagMaskSecondaryFn) { lua_pushboolean(L, YES); lua_setfield(L, -2, "fn"); }
    return 1;
}

/// eventtap.event:setflags(table)
/// The table may have any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
static int eventtap_event_setflags(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    luaL_checktype(L, 2, LUA_TTABLE);
    
    CGEventFlags flags = 0;
    
    if (lua_getfield(L, 2, "cmd"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskCommand;
    if (lua_getfield(L, 2, "alt"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskAlternate;
    if (lua_getfield(L, 2, "ctrl"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskControl;
    if (lua_getfield(L, 2, "shift"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskShift;
    if (lua_getfield(L, 2, "fn"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskSecondaryFn;
    
    CGEventSetFlags(event, flags);
    
    return 0;
}

/// eventtap.event:getkeycode() -> keycode
/// Gets the keycode for the given event; only applicable for key-related events.
/// The keycode is a numeric value from the `hotkey.keycodes` table.
static int eventtap_event_getkeycode(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    lua_pushnumber(L, keycode);
    return 1;
}

/// eventtap.event:setkeycode(keycode)
/// Sets the keycode for the given event; only applicable for key-related events.
/// The keycode is a numeric value from the `hotkey.keycodes` table.
static int eventtap_event_setkeycode(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CGKeyCode keycode = luaL_checknumber(L, 2);
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, (int64_t)keycode);
    return 0;
}

/// eventtap.event:post()
/// Posts the event to the system as if the user did it manually.
static int eventtap_event_post(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CGEventPost(kCGSessionEventTap, event);
    return 0;
}

// TODO: turn this into eventtap.event.newkeyevent()

//static void eventtap_event_setkeycode(CGKeyCode virtualKey, CGEventFlags flags, bool keyDown) {
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
//
//
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

static luaL_Reg eventtapeventlib[] = {
    // module methods
    
    // instance methods
    {"copy", eventtap_event_copy},
    {"getflags", eventtap_event_getflags},
    {"setflags", eventtap_event_setflags},
    {"getkeycode", eventtap_event_getkeycode},
    {"setkeycode", eventtap_event_setkeycode},
    {"post", eventtap_event_post},
    
    // metamethods
    {"__gc", eventtap_event_gc},
    
    {}
};

int luaopen_eventtap_event(lua_State* L) {
    luaL_newlib(L, eventtapeventlib);
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "eventtap_event");
    
    return 1;
}
