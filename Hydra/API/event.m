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
    CGEventMask mask;
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

/// event.eventtap(type, callback) -> event
/// Returns a new event tap with the given callback for the given events; is not started automatically.
/// The type param must be one of the values from the table `event.eventtaptypes`.
/// If the callback function returns nothing, the event is not modified; if it returns nil, the event is deleted from the OS X event system and not seen by any other apps; all other return values are reserved for future features to this API.
/// The callback usually takes no params, except for certain events:
///   flagschanged: takes a table with any of the strings {"cmd", "alt", "shift", "ctrl", "fn"} as keys pointing to the value `true`
static int event_eventtap(lua_State* L) {
    CGEventMask type = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    
    eventtap* e = lua_newuserdata(L, sizeof(eventtap));
    e->started = NO;
    e->mask = type;
    
    lua_newtable(L);
    lua_pushvalue(L, 2);
    lua_setfield(L, -2, "fn");
    lua_setuservalue(L, -2);
    
    luaL_getmetatable(L, "eventtap");
    lua_setmetatable(L, -2);
    
    return 1;
}

static void postkeyevent(CGKeyCode virtualKey, CGEventFlags flags, bool keyDown) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, virtualKey, keyDown);
    CGEventSetFlags(event, flags);
    CGEventPost(kCGSessionEventTap, event);
    CFRelease(event);
}

/// event.postkey(keycode, mods, dir)
/// Posts a keyboard event. Keycode is a numeric value from `hotkey.keycodes`; dir is either 'down', 'up', or 'both'; mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift'}
/// Doesn't usually work inside a hotkey callback for some reason.
static int event_postkey(lua_State* L) {
    CGKeyCode keycode = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    const char* dir = luaL_checkstring(L, 3);
    
    CGEventFlags flags = 0;
    
    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        const char* key = lua_tostring(L, -1);
        if (strcmp(key, "ctrl") == 0) flags |= kCGEventFlagMaskControl;
        else if (strcmp(key, "alt") == 0) flags |= kCGEventFlagMaskAlternate;
        else if (strcmp(key, "cmd") == 0) flags |= kCGEventFlagMaskCommand;
        else if (strcmp(key, "shift") == 0) flags |= kCGEventFlagMaskShift;
        lua_pop(L, 1);
    }
    
    if (strcmp(dir, "both") == 0) {
        postkeyevent(keycode, flags, true);
        postkeyevent(keycode, flags, false);
    }
    else {
        BOOL down = (strcmp(dir, "down") == 0);
        postkeyevent(keycode, flags, down);
    }

    return 0;
}

static luaL_Reg eventlib[] = {
    {"eventtap", event_eventtap},
    {"postkey", event_postkey},
    {NULL, NULL}
};

static luaL_Reg eventtaplib[] = {
    {"start", event_eventtap_start},
    {"stop", event_eventtap_stop},
    {NULL, NULL}
};

/// event.eventtaptypes
/// Table for use with `event.eventtap`, with the following keys:
///   leftmousedown, leftmouseup, leftmousedragged,
///   rightmousedown, rightmouseup, rightmousedragged,
///   middlemousedown, middlemouseup, middlemousedragged,
///   keydown, keyup, mousemoved, flagschanged, scrollwheel

int luaopen_event(lua_State* L) {
    luaL_newmetatable(L, "eventtap");
    luaL_newlib(L, eventtaplib);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    
    luaL_newlib(L, eventlib);
    
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
    lua_setfield(L, -2, "eventtaptypes");
    
    return 1;
}
