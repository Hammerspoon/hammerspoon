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

/// eventtap.event:gettype() -> number
/// Gets the type of the given event; return value will be one of the values in the eventtap.event.types table.
static int eventtap_event_gettype(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    lua_pushnumber(L, CGEventGetType(event));
    return 1;
}

/// eventtap.event.newkeyevent(mods, key, isdown)
/// Creates a keyboard event.
///   - mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift', 'fn'}
///   - key has the same meaning as in the `hotkey` module
///   - isdown is a boolean, representing whether the key event would be a press or release
static int eventtap_event_newkeyevent(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    const char* key = luaL_checkstring(L, 2);
    bool isdown = lua_toboolean(L, 3);
    
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "keycodes");
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    CGKeyCode keycode = lua_tonumber(L, -1);
    lua_pop(L, 2);
    
    CGEventFlags flags = 0;
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        if (strcmp(lua_tostring(L, -1), "cmd") == 0) flags |= kCGEventFlagMaskCommand;
        else if (strcmp(lua_tostring(L, -1), "ctrl") == 0) flags |= kCGEventFlagMaskControl;
        else if (strcmp(lua_tostring(L, -1), "alt") == 0) flags |= kCGEventFlagMaskAlternate;
        else if (strcmp(lua_tostring(L, -1), "shift") == 0) flags |= kCGEventFlagMaskShift;
        else if (strcmp(lua_tostring(L, -1), "fn") == 0) flags |= kCGEventFlagMaskSecondaryFn;
        lua_pop(L, 1);
    }
    
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef keyevent = CGEventCreateKeyboardEvent(source, keycode, isdown);
    CGEventSetFlags(keyevent, flags);
    new_eventtap_event(L, keyevent);
    CFRelease(keyevent);
    
    return 1;
}

/// eventtap.event.types -> table
/// Table for use with `eventtap.new`, with the following keys:
///   leftmousedown, leftmouseup, leftmousedragged,
///   rightmousedown, rightmouseup, rightmousedragged,
///   middlemousedown, middlemouseup, middlemousedragged,
///   keydown, keyup, mousemoved, flagschanged, scrollwheel
static void pushtypestable(lua_State* L) {
    lua_newtable(L);
    lua_pushnumber(L, kCGEventLeftMouseDown);     lua_setfield(L, -2, "leftmousedown");
    lua_pushnumber(L, kCGEventLeftMouseUp);       lua_setfield(L, -2, "leftmouseup");
    lua_pushnumber(L, kCGEventLeftMouseDragged);  lua_setfield(L, -2, "leftmousedragged");
    lua_pushnumber(L, kCGEventRightMouseDown);    lua_setfield(L, -2, "rightmousedown");
    lua_pushnumber(L, kCGEventRightMouseUp);      lua_setfield(L, -2, "rightmouseup");
    lua_pushnumber(L, kCGEventRightMouseDragged); lua_setfield(L, -2, "rightmousedragged");
    lua_pushnumber(L, kCGEventOtherMouseDown);    lua_setfield(L, -2, "middlemousedown");
    lua_pushnumber(L, kCGEventOtherMouseUp);      lua_setfield(L, -2, "middlemouseup");
    lua_pushnumber(L, kCGEventOtherMouseDragged); lua_setfield(L, -2, "middlemousedragged");
    lua_pushnumber(L, kCGEventMouseMoved);        lua_setfield(L, -2, "mousemoved");
    lua_pushnumber(L, kCGEventFlagsChanged);      lua_setfield(L, -2, "flagschanged");
    lua_pushnumber(L, kCGEventScrollWheel);       lua_setfield(L, -2, "scrollwheel");
    lua_pushnumber(L, kCGEventKeyDown);           lua_setfield(L, -2, "keydown");
    lua_pushnumber(L, kCGEventKeyUp);             lua_setfield(L, -2, "keyup");
}

static luaL_Reg eventtapeventlib[] = {
    // module methods
    {"newkeyevent", eventtap_event_newkeyevent},
    
    // instance methods
    {"copy", eventtap_event_copy},
    {"getflags", eventtap_event_getflags},
    {"setflags", eventtap_event_setflags},
    {"getkeycode", eventtap_event_getkeycode},
    {"setkeycode", eventtap_event_setkeycode},
    {"gettype", eventtap_event_gettype},
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
    
    pushtypestable(L);
    lua_setfield(L, -2, "types");
    
    return 1;
}
