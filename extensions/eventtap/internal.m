#import "eventtap_event.h"
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs.eventtap"

typedef struct _eventtap_t {
    lua_State* L;
    bool running;
    int fn;
    int self;
    CGEventMask mask;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
} eventtap_t;

static NSMutableIndexSet* eventtapHandlers;

static int store_event(lua_State* L, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [eventtapHandlers addIndex: x];
    return x;
}

static int remove_event(lua_State* L, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [eventtapHandlers removeIndex: x];
    return LUA_NOREF;
}

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType __unused type, CGEventRef event, void *refcon) {
    eventtap_t* e = refcon;
    lua_State* L = e->L;

    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->fn);
    new_eventtap_event(L, event);

    if (lua_pcall(L, 1, 2, -3) != LUA_OK) {
        CLS_NSLOG(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }

    bool ignoreevent = lua_toboolean(L, -2);

    if (lua_istable(L, -1)) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            CGEventRef event = hs_to_eventtap_event(L, -1);
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

/// hs.eventtap.keyStrokes(text)
/// Function
/// Generates and emits keystroke events for the supplied text
///
/// Parameters:
///  * text - A string containing the text to be typed
///
/// Returns:
///  * None
///
/// Notes:
///  * If you want to send a single keystroke with keyboard modifiers (e.g. sending ⌘-v to paste), see `hs.eventtap.keyStroke()`
static int eventtap_keyStrokes(lua_State* L) {
    luaL_checktype(L, 1, LUA_TSTRING);
    NSString *theString = [NSString stringWithUTF8String:lua_tostring(L, 1)];

    CGEventRef keyDownEvent = CGEventCreateKeyboardEvent(nil, 0, true);
    CGEventRef keyUpEvent = CGEventCreateKeyboardEvent(nil, 0, false);

    // This superb implementation was lifted shamelessly from http://www.mail-archive.com/cocoa-dev@lists.apple.com/msg23343.html
    UniChar buffer;
    for (int i = 0; i < (int)[theString length]; i++) {
        [theString getCharacters:&buffer range:NSMakeRange(i, 1)];

        // Send the keydown
        CGEventSetFlags(keyDownEvent, 0);
        CGEventKeyboardSetUnicodeString(keyDownEvent, 1, &buffer);
        CGEventPost(kCGHIDEventTap, keyDownEvent);

        // Send the keyup
        CGEventSetFlags(keyUpEvent, 0);
        CGEventKeyboardSetUnicodeString(keyUpEvent, 1, &buffer);
        CGEventPost(kCGHIDEventTap, keyUpEvent);
    }
    CFRelease(keyDownEvent);
    CFRelease(keyUpEvent);

    return 0;
}

/// hs.eventtap.new(types, fn) -> eventtap
/// Constructor
/// Create a new event tap object
///
/// Parameters:
///  * types - A table that should contain values from `hs.eventtap.event.types`
///  * fn - A function that will be called when the specified event types occur. The function should take a single parameter, which will be an event object. It can optionally return two values. Firstly, a boolean, true if the event should be deleted, false if it should propagate to any other applications watching for that event. Secondly, a table of events to post.
///
/// Returns:
///  * An event tap object
///
/// Notes:
///  * If you specify the argument `types` as the special table {"all"[, events to ignore]}, then *all* events (except those you optionally list *after* the "all" string) will trigger a callback, even events which are not defined in the [Quartz Event Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html).
static int eventtap_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    eventtap_t* eventtap = lua_newuserdata(L, sizeof(eventtap_t));
    memset(eventtap, 0, sizeof(eventtap_t));

    eventtap->L = L;

    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        if (lua_isnumber(L, -1)) {
            CGEventType type = lua_tonumber(L, -1);
            eventtap->mask ^= CGEventMaskBit(type);
        } else if (lua_isstring(L, -1)) {
            const char *label = lua_tostring(L, -1);
            if (strcmp(label, "all") == 0)
                eventtap->mask = kCGEventMaskForAllEvents ;
            else
                return luaL_error(L, "Invalid event type specified. Must be a table of numbers or {\"all\"}.") ;
        } else
            return luaL_error(L, "Invalid event types specified. Must be a table of numbers.") ;
        lua_pop(L, 1);
    }

    lua_pushvalue(L, 2);
    eventtap->fn = luaL_ref(L, LUA_REGISTRYINDEX);

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.eventtap:start()
/// Method
/// Starts an event tap
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int eventtap_start(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    if (e->running)
        return 0;

    e->self = store_event(L, 1);
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

    lua_settop(L,1);
    return 1;
}

/// hs.eventtap:stop()
/// Method
/// Stops an event tap
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int eventtap_stop(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    if (!e->running)
        return 0;

    remove_event(L, e->self);
    e->self = LUA_NOREF;
    e->running = false;

    CGEventTapEnable(e->tap, false);
    CFMachPortInvalidate(e->tap);
    CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
    CFRelease(e->runloopsrc);
    CFRelease(e->tap);

    lua_settop(L,1);
    return 1;
}

static int eventtap_gc(lua_State* L) {
    eventtap_t* eventtap = luaL_checkudata(L, 1, USERDATA_TAG);
    if (eventtap->running) {
        remove_event(L, eventtap->self);
        eventtap->self = LUA_NOREF;
        eventtap->running = false;

        CGEventTapEnable(eventtap->tap, false);
        CFMachPortInvalidate(eventtap->tap);
        CFRunLoopRemoveSource(CFRunLoopGetMain(), eventtap->runloopsrc, kCFRunLoopCommonModes);
        CFRelease(eventtap->runloopsrc);
        CFRelease(eventtap->tap);
    }
    luaL_unref(L, LUA_REGISTRYINDEX, eventtap->fn);
    eventtap->fn = LUA_NOREF;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [eventtapHandlers removeAllIndexes];
    eventtapHandlers = nil;
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg eventtap_metalib[] = {
    {"start",   eventtap_start},
    {"stop",    eventtap_stop},
    {"__gc",    eventtap_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static luaL_Reg eventtaplib[] = {
    {"new",     eventtap_new},
    {"keyStrokes", eventtap_keyStrokes},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_eventtap_internal(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, eventtap_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

    luaL_newlib(L, eventtaplib);
        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
