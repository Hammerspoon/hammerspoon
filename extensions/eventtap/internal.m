#import "eventtap_event.h"

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

static void remove_event(lua_State* L, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [eventtapHandlers removeIndex: x];
}

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType __unused type, CGEventRef event, void *refcon) {
    eventtap_t* e = refcon;
    lua_State* L = e->L;

    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->fn);
    new_eventtap_event(L, event);

    if (lua_pcall(L, 1, 2, -3) != 0) {
        NSLog(@"%s", lua_tostring(L, -1));
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

/// hs.eventtap.new(types, fn) -> eventtap
/// Constructor
/// Returns a new event tap with the given function as the callback for the given event types; the eventtap not started automatically. The types param is a table which may contain values from table `hs.eventtap.event.types`. The event types are specified as bit-fields and are exclusively-or'ed together (see {"all"} below for why this is done.  This means { ...keyup, ...keydown, ...keyup }  is equivalent to { ...keydown }.
///
/// The callback function takes an event object as its only parameter. It can optionally return two values: if the first one is truthy, this event is deleted from the system input event stream and not seen by any other app; if the second one is a table of events, they will each be posted along with this event.
///
///  e.g. callback(obj) -> bool[, table]
///
/// If you specify the argument `types` as the special table {"all"[, events to ignore]}, then *all* events (except those you optionally list *after* the "all" string) will trigger a callback, even events which are not defined in the [Quartz Event Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html).
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
/// Starts an event tap; must be in stopped state.
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
/// Stops an event tap; must be in started state.
static int eventtap_stop(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    if (!e->running)
        return 0;

    remove_event(L, e->self);
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
        eventtap->running = false;

        CGEventTapEnable(eventtap->tap, false);
        CFMachPortInvalidate(eventtap->tap);
        CFRunLoopRemoveSource(CFRunLoopGetMain(), eventtap->runloopsrc, kCFRunLoopCommonModes);
        CFRelease(eventtap->runloopsrc);
        CFRelease(eventtap->tap);
    }
    luaL_unref(L, LUA_REGISTRYINDEX, eventtap->fn);

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
