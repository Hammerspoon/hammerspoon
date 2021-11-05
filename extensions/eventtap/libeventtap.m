#import "eventtap_event.h"
#import "HSuicore.h"

#define USERDATA_TAG        "hs.eventtap"
static LSRefTable refTable;

typedef struct _eventtap_t {
    int fn;
    CGEventMask mask;
    CFMachPortRef tap;
    CFRunLoopSourceRef runloopsrc;
    LSGCCanary lsCanary;
} eventtap_t;

CGEventRef eventtap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;

    eventtap_t* e = refcon;

    // Guard against this callback being delivered at a point where LuaSkin has been reset and our references wouldn't make sense anymore
    if (![skin checkGCCanary:e->lsCanary]) {
        return event; // Allow the event to pass through unmodified
    }

    _lua_stackguard_entry(L);

    // Guard against a crash where e->fn is a LUA_NOREF/LUA_REFNIL, which shouldn't be possible (maybe a subtle race condition?)
    if (e->fn == LUA_NOREF || e->fn == LUA_REFNIL) {
        [skin logBreadcrumb:@"eventtap_callback called with LUA_NOREF/LUA_REFNIL"];
        _lua_stackguard_exit(L);
        return event;
    }

//  apparently OS X disables eventtaps if it thinks they are slow or odd or just because the moon
//  is wrong in some way... but at least it's nice enough to tell us.
    if ((type == kCGEventTapDisabledByTimeout) || (type == kCGEventTapDisabledByUserInput)) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"eventtap restarted: (%d)", type]] ;
        CGEventTapEnable(e->tap, true);
        _lua_stackguard_exit(L);
        return event ;
    }

    [skin pushLuaRef:refTable ref:e->fn];
    new_eventtap_event(L, event);

    if (![skin protectedCallAndTraceback:1 nresults:2]) {
        const char *errorMsg = lua_tostring(L, -1);
        if (!errorMsg) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"ERROR: eventtap_callback callback returned something that isn't a string: %d", lua_type(L, -1)]];
        } else {
            [skin logError:[NSString stringWithFormat:@"hs.eventtap callback error: %s", errorMsg]];
        }
        lua_pop(L, 1) ; // remove error message
        _lua_stackguard_exit(L);
        return NULL;
    }

    bool ignoreevent = lua_toboolean(L, -2);

    if (lua_istable(L, -1)) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            if (lua_type(L, -1) == LUA_TUSERDATA && luaL_testudata(L, -1, EVENT_USERDATA_TAG)) {
                CGEventRef newEvent = hs_to_eventtap_event(L, -1);
                CGEventTapPostEvent(proxy, newEvent);
            }
            lua_pop(L, 1);
        }
    }

    lua_pop(L, 2);
    _lua_stackguard_exit(L);

    if (ignoreevent)
        return NULL;
    else
        return event;
}

/// hs.eventtap.keyStrokes(text[, application])
/// Function
/// Generates and emits keystroke events for the supplied text
///
/// Parameters:
///  * text - A string containing the text to be typed
///  * application - An optional hs.application object to send the keystrokes to
///
/// Returns:
///  * None
///
/// Notes:
///  * If you want to send a single keystroke with keyboard modifiers (e.g. sending ⌘-v to paste), see `hs.eventtap.keyStroke()`
static int eventtap_keyStrokes(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TANY|LS_TOPTIONAL, LS_TBREAK];

    NSString *theString = [skin toNSObjectAtIndex:1];
    HSapplication *app = nil;
    ProcessSerialNumber psn;

    if (lua_type(L, 2) == LUA_TUSERDATA && luaL_checkudata(L, 2, "hs.application")) {
        app = [skin toNSObjectAtIndex:2];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSStatus err = GetProcessForPID(app.pid, &psn);
#pragma clang diagnostic pop
        if (err != noErr) {
            [skin logError:[NSString stringWithFormat:@"Unable to get PSN for: %@", app]];
            return 0;
        }
    }

    CGEventRef keyDownEvent = CGEventCreateKeyboardEvent(nil, 0, true);
    CGEventRef keyUpEvent = CGEventCreateKeyboardEvent(nil, 0, false);

    // This superb implementation was lifted shamelessly from http://www.mail-archive.com/cocoa-dev@lists.apple.com/msg23343.html
    UniChar buffer;
    for (NSUInteger i = 0; i < [theString length]; i++) {
        [theString getCharacters:&buffer range:NSMakeRange(i, 1)];

        // Send the keydown
        CGEventSetFlags(keyDownEvent, (CGEventFlags)0);
        CGEventKeyboardSetUnicodeString(keyDownEvent, 1, &buffer);
        if (app) {
            CGEventPostToPSN(&psn, keyDownEvent);
        } else {
            CGEventPost(kCGHIDEventTap, keyDownEvent);
        }

        // Send the keyup
        CGEventSetFlags(keyUpEvent, (CGEventFlags)0);
        CGEventKeyboardSetUnicodeString(keyUpEvent, 1, &buffer);
        if (app) {
            CGEventPostToPSN(&psn, keyUpEvent);
        } else {
            CGEventPost(kCGHIDEventTap, keyUpEvent);
        }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    eventtap_t* eventtap = lua_newuserdata(L, sizeof(eventtap_t));
    memset(eventtap, 0, sizeof(eventtap_t));

    eventtap->tap = NULL ;
    eventtap->lsCanary = [skin createGCCanary];

    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        if (lua_isinteger(L, -1)) {
            CGEventType type = (CGEventType)(lua_tointeger(L, -1));
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
    eventtap->fn = [skin luaRef:refTable];

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
///  * The event tap object
static int eventtap_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    if (!(e->tap && CGEventTapIsEnabled(e->tap))) {
        // Just in case; don't want dangling ports and loops and such lying around.
        if (e->tap && !CGEventTapIsEnabled(e->tap)) {
            CFMachPortInvalidate(e->tap);
            CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
            CFRelease(e->runloopsrc);
            CFRelease(e->tap);
        }
        e->tap = CGEventTapCreate(kCGSessionEventTap,
                                  kCGHeadInsertEventTap,
                                  kCGEventTapOptionDefault,
                                  e->mask,
                                  eventtap_callback,
                                  e);

        if (e->tap) {
            CGEventTapEnable(e->tap, true);
            e->runloopsrc = CFMachPortCreateRunLoopSource(NULL, e->tap, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
        } else {
            [skin logError:@"hs.eventtap:start() Unable to create eventtap. Is Accessibility enabled?"];
        }
    }
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
///  * The event tap object
static int eventtap_stop(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    if (e->tap) {
        if (CGEventTapIsEnabled(e->tap)) CGEventTapEnable(e->tap, false);

        CFMachPortInvalidate(e->tap);
        CFRunLoopRemoveSource(CFRunLoopGetMain(), e->runloopsrc, kCFRunLoopCommonModes);
        CFRelease(e->runloopsrc);
        CFRelease(e->tap);
        e->tap = NULL ;
    }
    lua_settop(L,1);
    return 1;
}

/// hs.eventtap:isEnabled() -> bool
/// Method
/// Determine whether or not an event tap object is enabled.
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the event tap is enabled or false if it is not.
static int eventtap_isEnabled(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, (e->tap && CGEventTapIsEnabled(e->tap))) ;
    return 1;
}

/// hs.eventtap.checkKeyboardModifiers([raw]) -> table
/// Function
/// Returns a table containing the current key modifiers being pressed or in effect *at this instant* for the keyboard most recently used.
///
/// Parameters:
///  * raw - an optional boolean value which, if true, includes the _raw key containing the numeric representation of all of the keyboard/modifier flags.
///
/// Returns:
///  * Returns a table containing boolean values indicating which keyboard modifiers were held down when the function was invoked; The possible keys are:
///     * cmd (or ⌘)
///     * alt (or ⌥)
///     * shift (or ⇧)
///     * ctrl (or ⌃)
///     * capslock
///     * fn
///   and optionally
///     * _raw - a numeric representation of the numeric representation of all of the keyboard/modifier flags.
///
/// Notes:
///  * This is an instantaneous poll of the current keyboard modifiers for the most recently used keyboard, not a callback.  This is useful primarily in conjuction with other modules, such as `hs.menubar`, when a callback is already in progress or waiting for an event callback is not practical or possible.
///  * the numeric value returned is useful if you need to detect device dependent flags or flags which we normally ignore because they are not present (or are accessible another way) on most keyboards.

static int checkKeyboardModifiers(lua_State* L) {

    NSUInteger theFlags = [NSEvent modifierFlags] ;

    lua_newtable(L);

    if (lua_isboolean(L, 1) && lua_toboolean(L, 1)) {
        lua_pushinteger(L, (lua_Integer)theFlags); lua_setfield(L, -2, "_raw");
    }

    if (theFlags & NSEventModifierFlagCommand) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "cmd"); lua_pushboolean(L, YES); lua_setfield(L, -2, "⌘");
    }
    if (theFlags & NSEventModifierFlagShift) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "shift"); lua_pushboolean(L, YES); lua_setfield(L, -2, "⇧");
    }
    if (theFlags & NSEventModifierFlagOption) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "alt"); lua_pushboolean(L, YES); lua_setfield(L, -2, "⌥");
    }
    if (theFlags & NSEventModifierFlagControl) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "ctrl"); lua_pushboolean(L, YES); lua_setfield(L, -2, "⌃");
    }
    if (theFlags & NSEventModifierFlagFunction) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "fn");
    }
    if (theFlags & NSEventModifierFlagCapsLock) {
        lua_pushboolean(L, YES); lua_setfield(L, -2, "capslock");
    }

    return 1;
}

/// hs.eventtap.isSecureInputEnabled() -> boolean
/// Function
/// Checks if macOS is preventing keyboard events from being sent to event taps
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if secure input is enabled, otherwise false
///
/// Notes:
///  * If secure input is enabled, Hammerspoon is not able to intercept keyboard events
///  * Secure input is enabled generally only in situations where an password field is focused in a web browser, system dialog or terminal
static int secureInputEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    BOOL isSecure = (BOOL)(IsSecureEventInputEnabled());

    lua_pushboolean(L, isSecure);
    return 1;
}

/// hs.eventtap.checkMouseButtons() -> table
/// Function
/// Returns a table containing the current mouse buttons being pressed *at this instant*.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns an array containing indicies starting from 1 up to the highest numbered button currently being pressed where the index is `true` if the button is currently pressed or `false` if it is not.
///  * Special hash tag synonyms for `left` (button 1), `right` (button 2), and `middle` (button 3) are also set to true if these buttons are currently being pressed.
///
/// Notes:
///  * This is an instantaneous poll of the current mouse buttons, not a callback.  This is useful primarily in conjuction with other modules, such as `hs.menubar`, when a callback is already in progress or waiting for an event callback is not practical or possible.
static int checkMouseButtons(lua_State* L) {
    NSUInteger theButtons = [NSEvent pressedMouseButtons] ;
    NSInteger i = 0 ;

    lua_newtable(L);

    while (theButtons != 0) {
        if (theButtons & 0x1) {
            if (i == 0) {
                lua_pushboolean(L, TRUE) ;
                lua_setfield(L, -2, "left") ;
            } else if (i == 1) {
                lua_pushboolean(L, TRUE) ;
                lua_setfield(L, -2, "right") ;
            } else if (i == 2) {
                lua_pushboolean(L, TRUE) ;
                lua_setfield(L, -2, "middle") ;
            }
        }
        lua_pushinteger(L, i + 1) ;
        lua_pushboolean(L, theButtons & 0x1) ;
        lua_settable(L, -3) ;
        i++ ;
        theButtons = theButtons >> 1 ;
    }
    return 1;
}

/// hs.eventtap.keyRepeatInterval() -> number
/// Function
/// Returns the system-wide setting for the interval between repeated keyboard events
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of seconds between keyboard events, if a key is held down
static int eventtap_keyRepeatInterval(lua_State* L) {
    lua_pushnumber(L, [NSEvent keyRepeatInterval]);
    return 1;
}

/// hs.eventtap.keyRepeatDelay() -> number
/// Function
/// Returns the system-wide setting for the delay before keyboard repeat events begin
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the number of seconds before repeat events begin, after a key is held down
static int eventtap_keyRepeatDelay(lua_State* L) {
    lua_pushnumber(L, [NSEvent keyRepeatDelay]);
    return 1;
}

/// hs.eventtap.doubleClickInterval() -> number
/// Function
/// Returns the system-wide setting for the delay between two clicks, to register a double click event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the maximum number of seconds between two mouse click events, for a double click event to be registered
static int eventtap_doubleClickInterval(lua_State* L) {
    lua_pushnumber(L, [NSEvent doubleClickInterval]);
    return 1;
}

static int eventtap_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    eventtap_t* eventtap = luaL_checkudata(L, 1, USERDATA_TAG);
    if (eventtap->tap) {
        if (CGEventTapIsEnabled(eventtap->tap)) CGEventTapEnable(eventtap->tap, false);

        CFMachPortInvalidate(eventtap->tap);
        CFRunLoopRemoveSource(CFRunLoopGetMain(), eventtap->runloopsrc, kCFRunLoopCommonModes);
        CFRelease(eventtap->runloopsrc);
        CFRelease(eventtap->tap);
    }

    eventtap->fn = [skin luaUnref:refTable ref:eventtap->fn];
    [skin destroyGCCanary:&(eventtap->lsCanary)];

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    eventtap_t* e = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: Eventtap Mask: 0x%llx (%p)", USERDATA_TAG, e->mask, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg eventtap_metalib[] = {
    {"start",     eventtap_start},
    {"stop",      eventtap_stop},
    {"isEnabled", eventtap_isEnabled},
    {"__tostring", userdata_tostring},
    {"__gc",      eventtap_gc},
    {NULL,        NULL}
};

// Functions for returned object when module loads
static luaL_Reg eventtaplib[] = {
    {"new",                     eventtap_new},
    {"keyStrokes",              eventtap_keyStrokes},
    {"checkKeyboardModifiers",  checkKeyboardModifiers},
    {"checkMouseButtons",       checkMouseButtons},
    {"keyRepeatDelay",          eventtap_keyRepeatDelay},
    {"keyRepeatInterval",       eventtap_keyRepeatInterval},
    {"doubleClickInterval",     eventtap_doubleClickInterval},
    {"isSecureInputEnabled", secureInputEnabled},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_libeventtap(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:eventtaplib metaFunctions:meta_gcLib objectFunctions:eventtap_metalib];

    return 1;
}
