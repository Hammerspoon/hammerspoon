#import "eventtap_event.h"
#import <IOKit/hidsystem/ev_keymap.h>

#import "../hammerspoon.h"

CGEventSourceRef eventSource;

static int eventtap_event_gc(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CFRelease(event);
    return 0;
}

/// hs.eventtap.event:copy() -> event
/// Constructor
/// Duplicateis an `hs.eventtap.event` event for further modification or injection
///
/// Parameters:
///  * None
///
/// Returns:
///  * A new `hs.eventtap.event` object
static int eventtap_event_copy(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);

    CGEventRef copy = CGEventCreateCopy(event);
    new_eventtap_event(L, copy);
    CFRelease(copy);

    return 1;
}

/// hs.eventtap.event:getFlags() -> table
/// Method
/// Gets the keyboard modifiers of an event
///
/// Parametes:
///  * None
///
/// Returns:
///  * A table containing the keyboard modifiers that present in the event - i.e. zero or more of the following keys, each with a value of `true`:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
static int eventtap_event_getFlags(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);

    lua_newtable(L);
    CGEventFlags curAltkey = CGEventGetFlags(event);
    if (curAltkey & kCGEventFlagMaskAlternate) { lua_pushboolean(L, YES); lua_setfield(L, -2, "alt"); }
    if (curAltkey & kCGEventFlagMaskShift) { lua_pushboolean(L, YES); lua_setfield(L, -2, "shift"); }
    if (curAltkey & kCGEventFlagMaskControl) { lua_pushboolean(L, YES); lua_setfield(L, -2, "ctrl"); }
    if (curAltkey & kCGEventFlagMaskCommand) { lua_pushboolean(L, YES); lua_setfield(L, -2, "cmd"); }
    if (curAltkey & kCGEventFlagMaskSecondaryFn) { lua_pushboolean(L, YES); lua_setfield(L, -2, "fn"); }
    return 1;
}

/// hs.eventtap.event:setFlags(table)
/// Method
/// Sets the keyboard modifiers of an event
///
/// Parameters:
///  * A table containing the keyboard modifiers to be sent with the event - i.e. zero or more of the following keys, each with a value of `true`:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///
/// Returns:
///  * The `hs.eventap.evant` object.
static int eventtap_event_setFlags(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    luaL_checktype(L, 2, LUA_TTABLE);

    CGEventFlags flags = 0;

    if (lua_getfield(L, 2, "cmd"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskCommand;
    if (lua_getfield(L, 2, "alt"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskAlternate;
    if (lua_getfield(L, 2, "ctrl"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskControl;
    if (lua_getfield(L, 2, "shift"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskShift;
    if (lua_getfield(L, 2, "fn"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskSecondaryFn;

    CGEventSetFlags(event, flags);

    lua_settop(L,1) ;
    return 1;
}

/// hs.eventtap.event:getRawEventData() -> table
/// Method
/// Returns raw data about the event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table with two keys:
///    * CGEventData -- a table with keys containing CGEvent data about the event.
///    * NSEventData -- a table with keys containing NSEvent data about the event.
///
/// Notes:
///  * Most of the data in `CGEventData` is already available through other methods, but is presented here without any cleanup or parsing.
///  * This method is expected to be used mostly for testing and expanding the range of possibilities available with the hs.eventtap module.  If you find that you are regularly using specific data from this method for common or re-usable purposes, consider submitting a request for adding a more targeted method to hs.eventtap or hs.eventtap.event -- it will likely be more efficient and faster for common tasks, something eventtaps need to be to minimize affecting system responsiveness.
static int eventtap_event_getRawEventData(lua_State* L) {
    CGEventRef  event    = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventType cgType   = CGEventGetType(event) ;

    lua_newtable(L) ;
        lua_newtable(L) ;
            lua_pushinteger(L, CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));  lua_setfield(L, -2, "keycode") ;
            lua_pushinteger(L, CGEventGetFlags(event));                                       lua_setfield(L, -2, "flags") ;
            lua_pushinteger(L, cgType);                                                       lua_setfield(L, -2, "type") ;
        lua_setfield(L, -2, "CGEventData") ;

        lua_newtable(L) ;
        if ((cgType != kCGEventTapDisabledByTimeout) && (cgType != kCGEventTapDisabledByUserInput)) {
            NSEvent*    sysEvent = [NSEvent eventWithCGEvent:event];
            NSEventType type     = [sysEvent type] ;
            lua_pushinteger(L, [sysEvent modifierFlags]);                                     lua_setfield(L, -2, "modifierFlags") ;
            lua_pushinteger(L, type);                                                         lua_setfield(L, -2, "type") ;
            lua_pushinteger(L, [sysEvent windowNumber]);                                      lua_setfield(L, -2, "windowNumber") ;
            if ((type == NSKeyDown) || (type == NSKeyUp)) {
                lua_pushstring(L, [[sysEvent characters] UTF8String]) ;                       lua_setfield(L, -2, "characters") ;
                lua_pushstring(L, [[sysEvent charactersIgnoringModifiers] UTF8String]) ;      lua_setfield(L, -2, "charactersIgnoringModifiers") ;
                lua_pushinteger(L, [sysEvent keyCode]) ;                                      lua_setfield(L, -2, "keyCode") ;
            }
            if ((type == NSLeftMouseDown) || (type == NSLeftMouseUp) || (type == NSRightMouseDown) || (type == NSRightMouseUp) || (type == NSOtherMouseDown) || (type == NSOtherMouseUp)) {
                lua_pushinteger(L, [sysEvent buttonNumber]) ;                                 lua_setfield(L, -2, "buttonNumber") ;
                lua_pushinteger(L, [sysEvent clickCount]) ;                                   lua_setfield(L, -2, "clickCount") ;
                lua_pushnumber(L, [sysEvent pressure]) ;                                      lua_setfield(L, -2, "pressure") ;
            }
            if ((type == NSAppKitDefined) || (type == NSSystemDefined) || (type == NSApplicationDefined) || (type == NSPeriodic)) {
                lua_pushinteger(L, [sysEvent data1]) ;                                        lua_setfield(L, -2, "data1") ;
                lua_pushinteger(L, [sysEvent data2]) ;                                        lua_setfield(L, -2, "data2") ;
                lua_pushinteger(L, [sysEvent subtype]) ;                                      lua_setfield(L, -2, "subtype") ;
            }
        }
        lua_setfield(L, -2, "NSEventData") ;
    return 1;
}

/// hs.eventtap.event:getCharacters([clean]) -> string or nil
/// Method
/// Returns the Unicode character, if any, represented by a keyDown or keyUp event.
///
/// Parameters:
///  * clean -- an optional parameter, default `false`, which indicates if key modifiers, other than Shift, should be stripped from the keypress before converting to Unicode.
///
/// Returns:
///  * A string containing the Unicode character represented by the keyDown or keyUp event, or nil if the event is not a keyUp or keyDown.
///
/// Notes:
///  * This method should only be used on keyboard events
///  * If `clean` is true, all modifiers except for Shift are stripped from the character before converting to the Unicode character represented by the keypress.
///  * If the keypress does not correspond to a valid Unicode character, an empty string is returned (e.g. if `clean` is false, then Opt-E will return an empty string, while Opt-Shift-E will return an accent mark).
static int eventtap_event_getCharacters(lua_State* L) {
    CGEventRef  event    = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    BOOL        clean    = lua_isnone(L, 2) ? NO : lua_toboolean(L, 2) ;
    CGEventType cgType   = CGEventGetType(event) ;

    if ((cgType == kCGEventKeyDown) || (cgType == kCGEventKeyUp)) {
        if (clean)
            lua_pushstring(L, [[[NSEvent eventWithCGEvent:event] charactersIgnoringModifiers] UTF8String]) ;
        else
            lua_pushstring(L, [[[NSEvent eventWithCGEvent:event] characters] UTF8String]) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.eventtap.event:getKeyCode() -> keycode
/// Method
/// Gets the raw keycode for the event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the raw keycode, taken from `hs.keycodes.map`
///
/// Notes:
///  * This method should only be used on keyboard events
static int eventtap_event_getKeyCode(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    lua_pushinteger(L, CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));
    return 1;
}

/// hs.eventtap.event:setKeyCode(keycode)
/// Method
/// Sets the raw keycode for the event
///
/// Parameters:
///  * keycode - A number containing a raw keycode, taken from `hs.keycodes.map`
///
/// Returns:
///  * The `hs.eventtap.event` object
///
/// Notes:
///  * This method should only be used on keyboard events
static int eventtap_event_setKeyCode(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGKeyCode keycode = luaL_checkinteger(L, 2);
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, (int64_t)keycode);

    lua_settop(L,1) ;
    return 1;
}

/// hs.eventtap.event:post([app])
/// Method
/// Posts the event to the OS - i.e. emits the keyboard/mouse input defined by the event
///
/// Parameters:
///  * app - An optional `hs.application` object. If specified, the event will only be sent to that application
///
/// Returns:
///  * The `hs.eventtap.event` object
//  * None
static int eventtap_event_post(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);

    if (luaL_testudata(L, 2, "hs.application")) {
        AXUIElementRef app = lua_touserdata(L, 2);

        pid_t pid;
        AXUIElementGetPid(app, &pid);

        ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        GetProcessForPID(pid, &psn);
#pragma clang diagnostic pop
        CGEventPostToPSN(&psn, event);
    }
    else {
        CGEventPost(kCGHIDEventTap, event);
    }

    usleep(1000);

    lua_settop(L, 1) ;
//     return 0;
    return 1 ;
}

/// hs.eventtap.event:getType() -> number
/// Method
/// Gets the type of the event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the type of the event, taken from `hs.eventtap.event.types`
static int eventtap_event_getType(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    lua_pushinteger(L, CGEventGetType(event));
    return 1;
}

/// hs.eventtap.event:getProperty(prop) -> number
/// Method
/// Gets a property of the event
///
/// Parameters:
///  * prop - A value taken from `hs.eventtap.event.properties`
///
/// Returns:
///  * A number containing the value of the requested property
///
/// Notes:
///  * The properties are `CGEventField` values, as documented at https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/index.html#//apple_ref/c/tdef/CGEventField
static int eventtap_event_getProperty(lua_State* L) {
    CGEventRef   event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventField field = (CGEventField)luaL_checkinteger(L, 2);

    if ((field == kCGMouseEventPressure)                ||   // These fields use a double (floating point number)
        (field == kCGScrollWheelEventFixedPtDeltaAxis1) ||
        (field == kCGScrollWheelEventFixedPtDeltaAxis2) ||
        (field == kCGScrollWheelEventFixedPtDeltaAxis3) ||
        (field == kCGTabletEventPointPressure)          ||
        (field == kCGTabletEventTiltX)                  ||
        (field == kCGTabletEventTiltY)                  ||
        (field == kCGTabletEventRotation)               ||
        (field == kCGTabletEventTangentialPressure)) {
        lua_pushnumber(L, CGEventGetDoubleValueField(event, field));
    } else {
        lua_pushinteger(L, CGEventGetIntegerValueField(event, field));
    }
    return 1;
}

/// hs.eventtap.event:getButtonState(button) -> bool
/// Method
/// Gets the state of a mouse button in the event
///
/// Parameters:
///  * button - A number between 0 and 31. The left mouse button is 0, the right mouse button is 1 and the middle mouse button is 2. The meaning of the remaining buttons varies by hardware, and their functionality varies by application (typically they are not present on a mouse and have no effect in an application)
///
/// Returns:
///  * A boolean, true if the specified mouse button is to be clicked by the event
///
/// Notes:
///  * This method should only be called on mouse events
static int eventtap_event_getButtonState(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGMouseButton whichButton = (CGMouseButton)luaL_checkinteger(L, 2);

    if (CGEventSourceButtonState((CGEventSourceStateID)CGEventGetIntegerValueField(event, kCGEventSourceStateID), whichButton))
        lua_pushboolean(L, YES) ;
    else
        lua_pushboolean(L, NO) ;
    return 1;
}

/// hs.eventtap.event:setProperty(prop, value)
/// Method
/// Sets a property of the event
///
/// Parameters:
///  * prop - A value from `hs.eventtap.event.properties`
///  * value - A number containing the value of the specified property
///
/// Returns:
///  * The `hs.eventtap.event` object.
///
/// Notes:
///  * The properties are `CGEventField` values, as documented at https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/index.html#//apple_ref/c/tdef/CGEventField
static int eventtap_event_setProperty(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventField field = (CGEventField)luaL_checkinteger(L, 2);
    if ((field == kCGMouseEventPressure)                ||   // These fields use a double (floating point number)
        (field == kCGScrollWheelEventFixedPtDeltaAxis1) ||
        (field == kCGScrollWheelEventFixedPtDeltaAxis2) ||
        (field == kCGScrollWheelEventFixedPtDeltaAxis3) ||
        (field == kCGTabletEventPointPressure)          ||
        (field == kCGTabletEventTiltX)                  ||
        (field == kCGTabletEventTiltY)                  ||
        (field == kCGTabletEventRotation)               ||
        (field == kCGTabletEventTangentialPressure)) {
        double value = luaL_checknumber(L, 3) ;
        CGEventSetDoubleValueField(event, field, value);
    } else {
        int value = (int)luaL_checkinteger(L, 3);
        CGEventSetIntegerValueField(event, field, value);
    }

    lua_settop(L,1) ;
    return 1;
}

/// hs.eventtap.event.newKeyEvent(mods, key, isdown) -> event
/// Constructor
/// Creates a keyboard event
///
/// Parameters:
///  * mods - A table containing zero or more of the following:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///  * key - A string containing the name of a key (see `hs.hotkey` for more information)
///  * isdown - A boolean, true if the event should be a key-down, false if it should be a key-up
///
/// Returns:
///  * An `hs.eventtap.event` object
static int eventtap_event_newKeyEvent(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    const char* key = luaL_checkstring(L, 2);
    bool isdown = lua_toboolean(L, 3);
    const char *modifier;

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "keycodes");
    lua_getfield(L, -1, "map");
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    CGKeyCode keycode = lua_tointeger(L, -1);
    lua_pop(L, 2);

    CGEventFlags flags = 0;
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        modifier = lua_tostring(L, -1);
        if (!modifier) {
            CLS_NSLOG(@"ERROR: Unexpected entry in modifiers table, seems to be null (%d)", lua_type(L, -1));
            lua_pop(L, 1);
            continue;
        }

        if (strcmp(modifier, "cmd") == 0 || strcmp(modifier, "⌘") == 0) flags |= kCGEventFlagMaskCommand;
        else if (strcmp(modifier, "ctrl") == 0 || strcmp(modifier, "⌃") == 0) flags |= kCGEventFlagMaskControl;
        else if (strcmp(modifier, "alt") == 0 || strcmp(modifier, "⌥") == 0) flags |= kCGEventFlagMaskAlternate;
        else if (strcmp(modifier, "shift") == 0 || strcmp(modifier, "⇧") == 0) flags |= kCGEventFlagMaskShift;
        else if (strcmp(modifier, "fn") == 0) flags |= kCGEventFlagMaskSecondaryFn;
        lua_pop(L, 1);
    }

    if (!eventSource) {
        eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    }

    CGEventRef keyevent = CGEventCreateKeyboardEvent(eventSource, keycode, isdown);
    CGEventSetFlags(keyevent, flags);
    new_eventtap_event(L, keyevent);
    CFRelease(keyevent);

    return 1;
}

/// hs.eventtap.event.newScrollWheelEvent(offsets, mods, unit) -> event
/// Constructor
/// Creates a scroll wheel event
///
/// Parameters:
///  * offsets - A table containing the {horizontal, vertical} amount to scroll. Positive values scroll up or left, negative values scroll down or right.
///  * mods - A table containing zero or more of the following:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///  * unit - An optional string containing the name of the unit for scrolling. Either "line" (the default) or "pixel"
///
/// Returns:
///  * An `hs.eventtap.event` object
static int eventtap_event_newScrollWheelEvent(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushnumber(L, 1); lua_gettable(L, 1); uint32_t offset_y = (uint32_t)lua_tointeger(L, -1) ; lua_pop(L, 1);
    lua_pushnumber(L, 2); lua_gettable(L, 1); uint32_t offset_x = (uint32_t)lua_tointeger(L, -1) ; lua_pop(L, 1);

    const char *modifier;
    const char *unit;
    CGEventFlags flags = 0;
    CGScrollEventUnit type;

    luaL_checktype(L, 2, LUA_TTABLE);
    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        modifier = lua_tostring(L, -1);
        if (!modifier) {
            CLS_NSLOG(@"ERROR: Unexpected entry in modifiers table, seems to be null (%d)", lua_type(L, -1));
            lua_pop(L, 1);
            continue;
        }

        if (strcmp(modifier, "cmd") == 0 || strcmp(modifier, "⌘") == 0) flags |= kCGEventFlagMaskCommand;
        else if (strcmp(modifier, "ctrl") == 0 || strcmp(modifier, "⌃") == 0) flags |= kCGEventFlagMaskControl;
        else if (strcmp(modifier, "alt") == 0 || strcmp(modifier, "⌥") == 0) flags |= kCGEventFlagMaskAlternate;
        else if (strcmp(modifier, "shift") == 0 || strcmp(modifier, "⇧") == 0) flags |= kCGEventFlagMaskShift;
        else if (strcmp(modifier, "fn") == 0) flags |= kCGEventFlagMaskSecondaryFn;
        lua_pop(L, 1);
    }
    unit = lua_tostring(L, 3);
    if (unit && strcmp(unit, "pixel") == 0) type = kCGScrollEventUnitPixel; else type = kCGScrollEventUnitLine;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(source, type, 2, offset_x, offset_y);
    CGEventSetFlags(scrollEvent, flags);
    new_eventtap_event(L, scrollEvent);
    CFRelease(scrollEvent);

    return 1;
}

static int eventtap_event_newMouseEvent(lua_State* L) {
    CGEventType type = (CGEventType)luaL_checkinteger(L, 1);
    CGPoint point = hs_topoint(L, 2);
    const char* buttonString = luaL_checkstring(L, 3);

    CGEventFlags flags = 0;
    const char *modifier;

    CGMouseButton button = kCGMouseButtonLeft;

    if (strcmp(buttonString, "right") == 0)
        button = kCGMouseButtonRight;
    else if (strcmp(buttonString, "middle") == 0)
        button = kCGMouseButtonCenter;

    if (!lua_isnoneornil(L, 4) && (lua_type(L, 4) == LUA_TTABLE)) {
        lua_pushnil(L);
        while (lua_next(L, 4) != 0) {
            modifier = lua_tostring(L, -2);
            if (!modifier) {
                CLS_NSLOG(@"Error: Unexpected entry in modifiers table, seems to be null (%d)", lua_type(L, -1));
                lua_pop(L, 1);
                continue;
            }
            if (strcmp(modifier, "cmd") == 0 || strcmp(modifier, "⌘") == 0) flags |= kCGEventFlagMaskCommand;
            else if (strcmp(modifier, "ctrl") == 0 || strcmp(modifier, "⌃") == 0) flags |= kCGEventFlagMaskControl;
            else if (strcmp(modifier, "alt") == 0 || strcmp(modifier, "⌥") == 0) flags |= kCGEventFlagMaskAlternate;
            else if (strcmp(modifier, "shift") == 0 || strcmp(modifier, "⇧") == 0) flags |= kCGEventFlagMaskShift;
            else if (strcmp(modifier, "fn") == 0) flags |= kCGEventFlagMaskSecondaryFn;
            lua_pop(L, 1);
        }
    }

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef event = CGEventCreateMouseEvent(source, type, point, button);
    CGEventSetFlags(event, flags);
    new_eventtap_event(L, event);
    CFRelease(event);

    return 1;
}

/// hs.eventtap.event.systemKey() -> table
/// Method
/// Returns the special key and its state if the event is a NSSystemDefined event of subtype AUX_CONTROL_BUTTONS (special-key pressed)
///
/// Parameters:
///  * None
///
/// Returns:
///  * If the event is a NSSystemDefined event of subtype AUX_CONTROL_BUTTONS, a table with the following keys defined:
///    * key    -- a string containing one of the following labels indicating the key involved:
///         SOUND_UP            SOUND_DOWN          MUTE
///         BRIGHTNESS_UP       BRIGHTNESS_DOWN
///         CONTRAST_UP         CONTRAST_DOWN
///         POWER               LAUNCH_PANEL        VIDMIRROR
///         PLAY                EJECT               NEXT
///         PREVIOUS            FAST                REWIND
///         ILLUMINATION_UP     ILLUMINATION_DOWN   ILLUMINATION_TOGGLE
///         CAPS_LOCK           HELP                NUM_LOCK
///      or "undefined" if the key detected is unrecognized.
///    * keyCode -- the numeric keyCode corresponding to the key specified in `key`.
///    * down   -- a boolean value indicating if the key is pressed down (true) or just released (false)
///    * repeat -- a boolean indicating if this event is because the keydown is repeating.  This will always be false for a key release.
///  * If the event does not correspond to a NSSystemDefined event of subtype AUX_CONTROL_BUTTONS, then an empty table is returned.
///
/// Notes:
/// * CAPS_LOCK seems to sometimes generate 0 or 2 key release events (down == false), especially on builtin laptop keyboards, so it is probably safest (more reliable) to look for cases where down == true only.
/// * If the key field contains "undefined", you can use the number in keyCode to look it up in `/System/Library/Frameworks/IOKit.framework/Headers/hidsystem/ev_keymap.h`.  If you believe the numeric value is part of a new system update or was otherwise mistakenly left out, please submit the label (it will defined in the header file as `NX_KEYTYPE_something`) and number to the Hammerspoon maintainers at https://github.com/Hammerspoon/hammerspoon with a request for inclusion in the next Hammerspoon update.
static int eventtap_event_systemKey(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    NSEvent*    sysEvent = [NSEvent eventWithCGEvent:event];
    NSEventType type     = [sysEvent type] ;

    lua_newtable(L) ;
    if ((type == NSAppKitDefined) || (type == NSSystemDefined) || (type == NSApplicationDefined) || (type == NSPeriodic)) {
        NSInteger data1      = [sysEvent data1] ;
        if ([sysEvent subtype] == NX_SUBTYPE_AUX_CONTROL_BUTTONS) {
            int keyCode      = (data1 & 0xFFFF0000) >> 16;
            int keyFlags     = (data1 &     0xFFFF);
            switch(keyCode) {
//
// This list is based on the definition of NX_SPECIALKEY_POST_MASK found in
// /System/Library/Frameworks/IOKit.framework/Headers/hidsystem/ev_keymap.h
//
                case NX_KEYTYPE_SOUND_UP:            lua_pushstring(L, "SOUND_UP");            break ;
                case NX_KEYTYPE_SOUND_DOWN:          lua_pushstring(L, "SOUND_DOWN");          break ;
                case NX_POWER_KEY:                   lua_pushstring(L, "POWER");               break ;
                case NX_KEYTYPE_MUTE:                lua_pushstring(L, "MUTE");                break ;
                case NX_KEYTYPE_BRIGHTNESS_UP:       lua_pushstring(L, "BRIGHTNESS_UP");       break ;
                case NX_KEYTYPE_BRIGHTNESS_DOWN:     lua_pushstring(L, "BRIGHTNESS_DOWN");     break ;
                case NX_KEYTYPE_CONTRAST_UP:         lua_pushstring(L, "CONTRAST_UP");         break ;
                case NX_KEYTYPE_CONTRAST_DOWN:       lua_pushstring(L, "CONTRAST_DOWN");       break ;
                case NX_KEYTYPE_LAUNCH_PANEL:        lua_pushstring(L, "LAUNCH_PANEL");        break ;
                case NX_KEYTYPE_EJECT:               lua_pushstring(L, "EJECT");               break ;
                case NX_KEYTYPE_VIDMIRROR:           lua_pushstring(L, "VIDMIRROR");           break ;
                case NX_KEYTYPE_PLAY:                lua_pushstring(L, "PLAY");                break ;
                case NX_KEYTYPE_NEXT:                lua_pushstring(L, "NEXT");                break ;
                case NX_KEYTYPE_PREVIOUS:            lua_pushstring(L, "PREVIOUS");            break ;
                case NX_KEYTYPE_FAST:                lua_pushstring(L, "FAST");                break ;
                case NX_KEYTYPE_REWIND:              lua_pushstring(L, "REWIND");              break ;
                case NX_KEYTYPE_ILLUMINATION_UP:     lua_pushstring(L, "ILLUMINATION_UP");     break ;
                case NX_KEYTYPE_ILLUMINATION_DOWN:   lua_pushstring(L, "ILLUMINATION_DOWN");   break ;
                case NX_KEYTYPE_ILLUMINATION_TOGGLE: lua_pushstring(L, "ILLUMINATION_TOGGLE"); break ;
//
// The following also seem to trigger NSSystemDefined events, but are not listed in NX_SPECIALKEY_POST_MASK
//
                case NX_KEYTYPE_CAPS_LOCK:           lua_pushstring(L, "CAPS_LOCK");           break ;
                case NX_KEYTYPE_HELP:                lua_pushstring(L, "HELP");                break ;
                case NX_KEYTYPE_NUM_LOCK:            lua_pushstring(L, "NUM_LOCK");            break ;

                default:                             lua_pushstring(L, "undefined") ;          break ;
            }
            lua_setfield(L, -2, "key") ;
            lua_pushinteger(L, keyCode) ; lua_setfield(L, -2, "keyCode") ;
            lua_pushboolean(L, ((keyFlags & 0xFF00) >> 8) == 0x0a ) ; lua_setfield(L, -2, "down") ;
            lua_pushboolean(L, (keyFlags & 0x1) > 0) ; lua_setfield(L, -2, "repeat") ;
        }
    }
    return 1;
}

/// hs.eventtap.event.types -> table
/// Constant
/// A table containing event types to be used with `hs.eventtap.new(...)` and returned by `hs.eventtap.event:type()`.  The table supports forward (label to number) and reverse (number to label) lookups to increase its flexibility.
///
/// The constants defined in this table are as follows:
///
///   * nullEvent               --  Specifies a null event.
///   * leftMouseDown           --  Specifies a mouse down event with the left button.
///   * leftMouseUp             --  Specifies a mouse up event with the left button.
///   * rightMouseDown          --  Specifies a mouse down event with the right button.
///   * rightMouseUp            --  Specifies a mouse up event with the right button.
///   * mouseMoved              --  Specifies a mouse moved event.
///   * leftMouseDragged        --  Specifies a mouse drag event with the left button down.
///   * rightMouseDragged       --  Specifies a mouse drag event with the right button down.
///   * keyDown                 --  Specifies a key down event.
///   * keyUp                   --  Specifies a key up event.
///   * flagsChanged            --  Specifies a key changed event for a modifier or status key.
///   * scrollWheel             --  Specifies a scroll wheel moved event.
///   * tabletPointer           --  Specifies a tablet pointer event.
///   * tabletProximity         --  Specifies a tablet proximity event.
///   * otherMouseDown          --  Specifies a mouse down event with one of buttons 2-31.
///   * otherMouseUp            --  Specifies a mouse up event with one of buttons 2-31.
///   * otherMouseDragged       --  Specifies a mouse drag event with one of buttons 2-31 down.
///
///  The following events, also included in the lookup table, are provided through NSEvent and currently may require the use of `hs.eventtap.event:getRawEventData()` to retrieve supporting information.  Target specific methods may be added as the usability of these events is explored.
///
///   * NSMouseEntered          --  See Mouse-Tracking and Cursor-Update Events in Cocoa Event Handling Guide.
///   * NSMouseExited           --  See Mouse-Tracking and Cursor-Update Events in Cocoa Event Handling Guide.
///   * NSCursorUpdate          --  See Mouse-Tracking and Cursor-Update Events in Cocoa Event Handling Guide.
///   * NSAppKitDefined         --  See Event Objects and Types in Cocoa Event Handling Guide.
///   * NSSystemDefined         --  See Event Objects and Types in Cocoa Event Handling Guide.
///   * NSApplicationDefined    --  See Event Objects and Types in Cocoa Event Handling Guide.
///   * NSPeriodic              --  See Event Objects and Types in Cocoa Event Handling Guide.
///   * NSEventTypeGesture      --  An event that represents some type of gesture such as NSEventTypeMagnify, NSEventTypeSwipe, NSEventTypeRotate, NSEventTypeBeginGesture, or NSEventTypeEndGesture.
///   * NSEventTypeMagnify      --  An event representing a pinch open or pinch close gesture.
///   * NSEventTypeSwipe        --  An event representing a swipe gesture.
///   * NSEventTypeRotate       --  An event representing a rotation gesture.
///   * NSEventTypeBeginGesture --  An event that represents a gesture beginning.
///   * NSEventTypeEndGesture   --  An event that represents a gesture ending.
///   * NSEventTypeSmartMagnify --  NSEvent type for the smart zoom gesture (2-finger double tap on trackpads) along with a corresponding NSResponder method. In response to this event, you should intelligently magnify the content.
///   * NSEventTypeQuickLook    --  Supports the new event responder method that initiates a Quicklook.
///
/// Notes:
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.eventtap.event.types`.
///  * In previous versions of Hammerspoon, type labels were defined with the labels in all lowercase.  This practice is deprecated, but an __index metamethod allows the lowercase labels to still be used; however a warning will be printed to the Hammerspoon console.  At some point, this may go away, so please update your code to follow the new format.

// wait until Travis catches up with 10.10.3
//
//   * NSEventTypePressure     --  An NSEvent type representing a change in pressure on a pressure-sensitive device. Requires a 64-bit processor.

static void pushtypestable(lua_State* L) {
    lua_newtable(L);
    lua_pushinteger(L, kCGEventLeftMouseDown);      lua_setfield(L, -2, "leftMouseDown");
    lua_pushstring(L, "leftMouseDown") ;            lua_rawseti(L, -2, kCGEventLeftMouseDown);
    lua_pushinteger(L, kCGEventLeftMouseUp);        lua_setfield(L, -2, "leftMouseUp");
    lua_pushstring(L, "leftMouseUp") ;              lua_rawseti(L, -2, kCGEventLeftMouseUp);
    lua_pushinteger(L, kCGEventLeftMouseDragged);   lua_setfield(L, -2, "leftMouseDragged");
    lua_pushstring(L, "leftMouseDragged") ;         lua_rawseti(L, -2, kCGEventLeftMouseDragged);
    lua_pushinteger(L, kCGEventRightMouseDown);     lua_setfield(L, -2, "rightMouseDown");
    lua_pushstring(L, "rightMouseDown") ;           lua_rawseti(L, -2, kCGEventRightMouseDown);
    lua_pushinteger(L, kCGEventRightMouseUp);       lua_setfield(L, -2, "rightMouseUp");
    lua_pushstring(L, "rightMouseUp") ;             lua_rawseti(L, -2, kCGEventRightMouseUp);
    lua_pushinteger(L, kCGEventRightMouseDragged);  lua_setfield(L, -2, "rightMouseDragged");
    lua_pushstring(L, "rightMouseDragged") ;        lua_rawseti(L, -2, kCGEventRightMouseDragged);
    lua_pushinteger(L, kCGEventOtherMouseDown);     lua_setfield(L, -2, "middleMouseDown");
    lua_pushstring(L, "middleMouseDown") ;          lua_rawseti(L, -2, kCGEventOtherMouseDown);
    lua_pushinteger(L, kCGEventOtherMouseUp);       lua_setfield(L, -2, "middleMouseUp");
    lua_pushstring(L, "middleMouseUp") ;            lua_rawseti(L, -2, kCGEventOtherMouseUp);
    lua_pushinteger(L, kCGEventOtherMouseDragged);  lua_setfield(L, -2, "middleMouseDragged");
    lua_pushstring(L, "middleMouseDragged") ;       lua_rawseti(L, -2, kCGEventOtherMouseDragged);
    lua_pushinteger(L, kCGEventMouseMoved);         lua_setfield(L, -2, "mouseMoved");
    lua_pushstring(L, "mouseMoved") ;               lua_rawseti(L, -2, kCGEventMouseMoved);
    lua_pushinteger(L, kCGEventFlagsChanged);       lua_setfield(L, -2, "flagsChanged");
    lua_pushstring(L, "flagsChanged") ;             lua_rawseti(L, -2, kCGEventFlagsChanged);
    lua_pushinteger(L, kCGEventScrollWheel);        lua_setfield(L, -2, "scrollWheel");
    lua_pushstring(L, "scrollWheel") ;              lua_rawseti(L, -2, kCGEventScrollWheel);
    lua_pushinteger(L, kCGEventKeyDown);            lua_setfield(L, -2, "keyDown");
    lua_pushstring(L, "keyDown") ;                  lua_rawseti(L, -2, kCGEventKeyDown);
    lua_pushinteger(L, kCGEventKeyUp);              lua_setfield(L, -2, "keyUp");
    lua_pushstring(L, "keyUp") ;                    lua_rawseti(L, -2, kCGEventKeyUp);
    lua_pushinteger(L, kCGEventTabletPointer);      lua_setfield(L, -2, "tabletPointer");
    lua_pushstring(L, "tabletPointer") ;            lua_rawseti(L, -2, kCGEventTabletPointer);
    lua_pushinteger(L, kCGEventTabletProximity);    lua_setfield(L, -2, "tabletProximity");
    lua_pushstring(L, "tabletProximity") ;          lua_rawseti(L, -2, kCGEventTabletProximity);
    lua_pushinteger(L, kCGEventNull);               lua_setfield(L, -2, "nullEvent");
    lua_pushstring(L, "nullEvent") ;                lua_rawseti(L, -2, kCGEventNull);
    lua_pushinteger(L, NSMouseEntered);             lua_setfield(L, -2, "NSMouseEntered");
    lua_pushstring(L, "NSMouseEntered") ;           lua_rawseti(L, -2, NSMouseEntered);
    lua_pushinteger(L, NSMouseExited);              lua_setfield(L, -2, "NSMouseExited");
    lua_pushstring(L, "NSMouseExited") ;            lua_rawseti(L, -2, NSMouseExited);
    lua_pushinteger(L, NSAppKitDefined);            lua_setfield(L, -2, "NSAppKitDefined");
    lua_pushstring(L, "NSAppKitDefined") ;          lua_rawseti(L, -2, NSAppKitDefined);
    lua_pushinteger(L, NSSystemDefined);            lua_setfield(L, -2, "NSSystemDefined");
    lua_pushstring(L, "NSSystemDefined") ;          lua_rawseti(L, -2, NSSystemDefined);
    lua_pushinteger(L, NSApplicationDefined);       lua_setfield(L, -2, "NSApplicationDefined");
    lua_pushstring(L, "NSApplicationDefined") ;     lua_rawseti(L, -2, NSApplicationDefined);
    lua_pushinteger(L, NSPeriodic);                 lua_setfield(L, -2, "NSPeriodic");
    lua_pushstring(L, "NSPeriodic") ;               lua_rawseti(L, -2, NSPeriodic);
    lua_pushinteger(L, NSCursorUpdate);             lua_setfield(L, -2, "NSCursorUpdate");
    lua_pushstring(L, "NSCursorUpdate") ;           lua_rawseti(L, -2, NSCursorUpdate);
    lua_pushinteger(L, NSEventTypeGesture);         lua_setfield(L, -2, "NSEventTypeGesture");
    lua_pushstring(L, "NSEventTypeGesture") ;       lua_rawseti(L, -2, NSEventTypeGesture);
    lua_pushinteger(L, NSEventTypeMagnify);         lua_setfield(L, -2, "NSEventTypeMagnify");
    lua_pushstring(L, "NSEventTypeMagnify") ;       lua_rawseti(L, -2, NSEventTypeMagnify);
    lua_pushinteger(L, NSEventTypeSwipe);           lua_setfield(L, -2, "NSEventTypeSwipe");
    lua_pushstring(L, "NSEventTypeSwipe") ;         lua_rawseti(L, -2, NSEventTypeSwipe);
    lua_pushinteger(L, NSEventTypeRotate);          lua_setfield(L, -2, "NSEventTypeRotate");
    lua_pushstring(L, "NSEventTypeRotate") ;        lua_rawseti(L, -2, NSEventTypeRotate);
    lua_pushinteger(L, NSEventTypeBeginGesture);    lua_setfield(L, -2, "NSEventTypeBeginGesture");
    lua_pushstring(L, "NSEventTypeBeginGesture") ;  lua_rawseti(L, -2, NSEventTypeBeginGesture);
    lua_pushinteger(L, NSEventTypeEndGesture);      lua_setfield(L, -2, "NSEventTypeEndGesture");
    lua_pushstring(L, "NSEventTypeEndGesture") ;    lua_rawseti(L, -2, NSEventTypeEndGesture);
    lua_pushinteger(L, NSEventTypeSmartMagnify);    lua_setfield(L, -2, "NSEventTypeSmartMagnify");
    lua_pushstring(L, "NSEventTypeSmartMagnify") ;  lua_rawseti(L, -2, NSEventTypeSmartMagnify);
    lua_pushinteger(L, NSEventTypeQuickLook);       lua_setfield(L, -2, "NSEventTypeQuickLook");
    lua_pushstring(L, "NSEventTypeQuickLook") ;     lua_rawseti(L, -2, NSEventTypeQuickLook);
// wait until Travis catches up with 10.10.3
//    lua_pushinteger(L, NSEventTypePressure);        lua_setfield(L, -2, "NSEventTypePressure");
//    lua_pushstring(L, "NSEventTypePressure") ;      lua_rawseti(L, -2, NSEventTypePressure);

//     lua_pushinteger(L, kCGEventTapDisabledByTimeout);    lua_setfield(L, -2, "tapDisabledByTimeout");
//     lua_pushstring(L, "tapDisabledByTimeout") ;         lua_rawseti(L, -2, kCGEventTapDisabledByTimeout);
//     lua_pushinteger(L, kCGEventTapDisabledByUserInput);  lua_setfield(L, -2, "tapDisabledByUserInput");
//     lua_pushstring(L, "tapDisabledByUserInput") ;       lua_rawseti(L, -2, kCGEventTapDisabledByUserInput);
}

/// hs.eventtap.event.properties -> table
/// Constant
/// A table containing property types for use with `hs.eventtap.event:getProperty()` and `hs.eventtap.event:setProperty()`.  The table supports forward (label to number) and reverse (number to label) lookups to increase its flexibility.
///
/// The constants defined in this table are as follows:
///    (I) in the description indicates that this property is returned or set as an integer
///    (N) in the description indicates that this property is returned or set as a number (floating point)
///
///   * mouseEventNumber                              -- (I) The mouse button event number. Matching mouse-down and mouse-up events will have the same event number.
///   * mouseEventClickState                          -- (I) The mouse button click state. A click state of 1 represents a single click. A click state of 2 represents a double-click. A click state of 3 represents a triple-click.
///   * mouseEventPressure                            -- (N) The mouse button pressure. The pressure value may range from 0 to 1, with 0 representing the mouse being up. This value is commonly set by tablet pens mimicking a mouse.
///   * mouseEventButtonNumber                        -- (I) The mouse button number. For information about the possible values, see Mouse Buttons.
///   * mouseEventDeltaX                              -- (I) The horizontal mouse delta since the last mouse movement event.
///   * mouseEventDeltaY                              -- (I) The vertical mouse delta since the last mouse movement event.
///   * mouseEventInstantMouser                       -- (I) The value is non-zero if the event should be ignored by the Inkwell subsystem.
///   * mouseEventSubtype                             -- (I) Encoding of the mouse event subtype as a kCFNumberIntType.
///   * keyboardEventAutorepeat                       -- (I) Non-zero when this is an autorepeat of a key-down, and zero otherwise.
///   * keyboardEventKeycode                          -- (I) The virtual keycode of the key-down or key-up event.
///   * keyboardEventKeyboardType                     -- (I) The keyboard type identifier.
///   * scrollWheelEventDeltaAxis1                    -- (I) Scrolling data. This field typically contains the change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventDeltaAxis2                    -- (I) Scrolling data. This field typically contains the change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventDeltaAxis3                    -- (I) This field is not used.
///   * scrollWheelEventFixedPtDeltaAxis1             -- (N) Contains scrolling data which represents a line-based or pixel-based change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventFixedPtDeltaAxis2             -- (N) Contains scrolling data which represents a line-based or pixel-based change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventFixedPtDeltaAxis3             -- (N) This field is not used.
///   * scrollWheelEventPointDeltaAxis1               -- (I) Pixel-based scrolling data. The scrolling data represents the change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventPointDeltaAxis2               -- (I) Pixel-based scrolling data. The scrolling data represents the change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventPointDeltaAxis3               -- (I) This field is not used.
///   * scrollWheelEventInstantMouser                 -- (I) Indicates whether the event should be ignored by the Inkwell subsystem. If the value is non-zero, the event should be ignored.
///   * tabletEventPointX                             -- (I) The absolute X coordinate in tablet space at full tablet resolution.
///   * tabletEventPointY                             -- (I) The absolute Y coordinate in tablet space at full tablet resolution.
///   * tabletEventPointZ                             -- (I) The absolute Z coordinate in tablet space at full tablet resolution.
///   * tabletEventPointButtons                       -- (I) The tablet button state. Bit 0 is the first button, and a set bit represents a closed or pressed button. Up to 16 buttons are supported.
///   * tabletEventPointPressure                      -- (N) The tablet pen pressure. A value of 0.0 represents no pressure, and 1.0 represents maximum pressure.
///   * tabletEventTiltX                              -- (N) The horizontal tablet pen tilt. A value of 0.0 represents no tilt, and 1.0 represents maximum tilt.
///   * tabletEventTiltY                              -- (N) The vertical tablet pen tilt. A value of 0.0 represents no tilt, and 1.0 represents maximum tilt.
///   * tabletEventRotation                           -- (N) The tablet pen rotation.
///   * tabletEventTangentialPressure                 -- (N) The tangential pressure on the device. A value of 0.0 represents no pressure, and 1.0 represents maximum pressure.
///   * tabletEventDeviceID                           -- (I) The system-assigned unique device ID.
///   * tabletEventVendor1                            -- (I) A vendor-specified value.
///   * tabletEventVendor2                            -- (I) A vendor-specified value.
///   * tabletEventVendor3                            -- (I) A vendor-specified value.
///   * tabletProximityEventVendorID                  -- (I) The vendor-defined ID, typically the USB vendor ID.
///   * tabletProximityEventTabletID                  -- (I) The vendor-defined tablet ID, typically the USB product ID.
///   * tabletProximityEventPointerID                 -- (I) The vendor-defined ID of the pointing device.
///   * tabletProximityEventDeviceID                  -- (I) The system-assigned device ID.
///   * tabletProximityEventSystemTabletID            -- (I) The system-assigned unique tablet ID.
///   * tabletProximityEventVendorPointerType         -- (I) The vendor-assigned pointer type.
///   * tabletProximityEventVendorPointerSerialNumber -- (I) The vendor-defined pointer serial number.
///   * tabletProximityEventVendorUniqueID            -- (I) The vendor-defined unique ID.
///   * tabletProximityEventCapabilityMask            -- (I) The device capabilities mask.
///   * tabletProximityEventPointerType               -- (I) The pointer type.
///   * tabletProximityEventEnterProximity            -- (I) Indicates whether the pen is in proximity to the tablet. The value is non-zero if the pen is in proximity to the tablet and zero when leaving the tablet.
///   * eventTargetProcessSerialNumber                -- (I) The event target process serial number. The value is a 64-bit long word.
///   * eventTargetUnixProcessID                      -- (I) The event target Unix process ID.
///   * eventSourceUnixProcessID                      -- (I) The event source Unix process ID.
///   * eventSourceUserData                           -- (I) Event source user-supplied data, up to 64 bits.
///   * eventSourceUserID                             -- (I) The event source Unix effective UID.
///   * eventSourceGroupID                            -- (I) The event source Unix effective GID.
///   * eventSourceStateID                            -- (I) The event source state ID used to create this event.
///   * scrollWheelEventIsContinuous                  -- (I) Indicates whether a scrolling event contains continuous, pixel-based scrolling data. The value is non-zero when the scrolling data is pixel-based and zero when the scrolling data is line-based.
///
/// Notes:
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.eventtap.event.properties`.
///  * In previous versions of Hammerspoon, property labels were defined with the labels in all lowercase.  This practice is deprecated, but an __index metamethod allows the lowercase labels to still be used; however a warning will be printed to the Hammerspoon console.  At some point, this may go away, so please update your code to follow the new format.
static void pushpropertiestable(lua_State* L) {
    lua_newtable(L);
    lua_pushinteger(L, kCGMouseEventNumber);                                 lua_setfield(L, -2, "mouseEventNumber");
    lua_pushstring(L, "mouseEventNumber") ;                                 lua_rawseti(L, -2, kCGMouseEventNumber);
    lua_pushinteger(L, kCGMouseEventClickState);                             lua_setfield(L, -2, "mouseEventClickState");
    lua_pushstring(L, "mouseEventClickState") ;                             lua_rawseti(L, -2, kCGMouseEventClickState);
    lua_pushinteger(L, kCGMouseEventPressure);                               lua_setfield(L, -2, "mouseEventPressure");
    lua_pushstring(L, "mouseEventPressure") ;                            lua_rawseti(L, -2, kCGMouseEventPressure);
    lua_pushinteger(L, kCGMouseEventButtonNumber);                           lua_setfield(L, -2, "mouseEventButtonNumber");
    lua_pushstring(L, "mouseEventButtonNumber") ;                           lua_rawseti(L, -2, kCGMouseEventButtonNumber);
    lua_pushinteger(L, kCGMouseEventDeltaX);                                 lua_setfield(L, -2, "mouseEventDeltaX");
    lua_pushstring(L, "mouseEventDeltaX") ;                                 lua_rawseti(L, -2, kCGMouseEventDeltaX);
    lua_pushinteger(L, kCGMouseEventDeltaY);                                 lua_setfield(L, -2, "mouseEventDeltaY");
    lua_pushstring(L, "mouseEventDeltaY") ;                                 lua_rawseti(L, -2, kCGMouseEventDeltaY);
    lua_pushinteger(L, kCGMouseEventInstantMouser);                          lua_setfield(L, -2, "mouseEventInstantMouser");
    lua_pushstring(L, "mouseEventInstantMouser") ;                          lua_rawseti(L, -2, kCGMouseEventInstantMouser);
    lua_pushinteger(L, kCGMouseEventSubtype);                                lua_setfield(L, -2, "mouseEventSubtype");
    lua_pushstring(L, "mouseEventSubtype") ;                                lua_rawseti(L, -2, kCGMouseEventSubtype);
    lua_pushinteger(L, kCGKeyboardEventAutorepeat);                          lua_setfield(L, -2, "keyboardEventAutorepeat");
    lua_pushstring(L, "keyboardEventAutorepeat") ;                          lua_rawseti(L, -2, kCGKeyboardEventAutorepeat);
    lua_pushinteger(L, kCGKeyboardEventKeycode);                             lua_setfield(L, -2, "keyboardEventKeycode");
    lua_pushstring(L, "keyboardEventKeycode") ;                             lua_rawseti(L, -2, kCGKeyboardEventKeycode);
    lua_pushinteger(L, kCGKeyboardEventKeyboardType);                        lua_setfield(L, -2, "keyboardEventKeyboardType");
    lua_pushstring(L, "keyboardEventKeyboardType") ;                        lua_rawseti(L, -2, kCGKeyboardEventKeyboardType);
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis1);                       lua_setfield(L, -2, "scrollWheelEventDeltaAxis1");
    lua_pushstring(L, "scrollWheelEventDeltaAxis1") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis1);
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis2);                       lua_setfield(L, -2, "scrollWheelEventDeltaAxis2");
    lua_pushstring(L, "scrollWheelEventDeltaAxis2") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis2);
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis3);                       lua_setfield(L, -2, "scrollWheelEventDeltaAxis3");
    lua_pushstring(L, "scrollWheelEventDeltaAxis3") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis3);
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis1);                lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis1");
    lua_pushstring(L, "scrollWheelEventFixedPtDeltaAxis1") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis1);
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis2);                lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis2");
    lua_pushstring(L, "scrollWheelEventFixedPtDeltaAxis2") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis2);
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis3);                lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis3");
    lua_pushstring(L, "scrollWheelEventFixedPtDeltaAxis3") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis3);
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis1);                  lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis1");
    lua_pushstring(L, "scrollWheelEventPointDeltaAxis1") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis1);
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis2);                  lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis2");
    lua_pushstring(L, "scrollWheelEventPointDeltaAxis2") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis2);
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis3);                  lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis3");
    lua_pushstring(L, "scrollWheelEventPointDeltaAxis3") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis3);
    lua_pushinteger(L, kCGScrollWheelEventInstantMouser);                    lua_setfield(L, -2, "scrollWheelEventInstantMouser");
    lua_pushstring(L, "scrollWheelEventInstantMouser") ;                    lua_rawseti(L, -2, kCGScrollWheelEventInstantMouser);
    lua_pushinteger(L, kCGTabletEventPointX);                                lua_setfield(L, -2, "tabletEventPointX");
    lua_pushstring(L, "tabletEventPointX") ;                                lua_rawseti(L, -2, kCGTabletEventPointX);
    lua_pushinteger(L, kCGTabletEventPointY);                                lua_setfield(L, -2, "tabletEventPointY");
    lua_pushstring(L, "tabletEventPointY") ;                                lua_rawseti(L, -2, kCGTabletEventPointY);
    lua_pushinteger(L, kCGTabletEventPointZ);                                lua_setfield(L, -2, "tabletEventPointZ");
    lua_pushstring(L, "tabletEventPointZ") ;                                lua_rawseti(L, -2, kCGTabletEventPointZ);
    lua_pushinteger(L, kCGTabletEventPointButtons);                          lua_setfield(L, -2, "tabletEventPointButtons");
    lua_pushstring(L, "tabletEventPointButtons") ;                          lua_rawseti(L, -2, kCGTabletEventPointButtons);
    lua_pushinteger(L, kCGTabletEventPointPressure);                         lua_setfield(L, -2, "tabletEventPointPressure");
    lua_pushstring(L, "tabletEventPointPressure") ;                         lua_rawseti(L, -2, kCGTabletEventPointPressure);
    lua_pushinteger(L, kCGTabletEventTiltX);                                 lua_setfield(L, -2, "tabletEventTiltX");
    lua_pushstring(L, "tabletEventTiltX") ;                                 lua_rawseti(L, -2, kCGTabletEventTiltX);
    lua_pushinteger(L, kCGTabletEventTiltY);                                 lua_setfield(L, -2, "tabletEventTiltY");
    lua_pushstring(L, "tabletEventTiltY") ;                                 lua_rawseti(L, -2, kCGTabletEventTiltY);
    lua_pushinteger(L, kCGTabletEventRotation);                              lua_setfield(L, -2, "tabletEventRotation");
    lua_pushstring(L, "tabletEventRotation") ;                              lua_rawseti(L, -2, kCGTabletEventRotation);
    lua_pushinteger(L, kCGTabletEventTangentialPressure);                    lua_setfield(L, -2, "tabletEventTangentialPressure");
    lua_pushstring(L, "tabletEventTangentialPressure") ;                    lua_rawseti(L, -2, kCGTabletEventTangentialPressure);
    lua_pushinteger(L, kCGTabletEventDeviceID);                              lua_setfield(L, -2, "tabletEventDeviceID");
    lua_pushstring(L, "tabletEventDeviceID") ;                              lua_rawseti(L, -2, kCGTabletEventDeviceID);
    lua_pushinteger(L, kCGTabletEventVendor1);                               lua_setfield(L, -2, "tabletEventVendor1");
    lua_pushstring(L, "tabletEventVendor1") ;                               lua_rawseti(L, -2, kCGTabletEventVendor1);
    lua_pushinteger(L, kCGTabletEventVendor2);                               lua_setfield(L, -2, "tabletEventVendor2");
    lua_pushstring(L, "tabletEventVendor2") ;                               lua_rawseti(L, -2, kCGTabletEventVendor2);
    lua_pushinteger(L, kCGTabletEventVendor3);                               lua_setfield(L, -2, "tabletEventVendor3");
    lua_pushstring(L, "tabletEventVendor3") ;                               lua_rawseti(L, -2, kCGTabletEventVendor3);
    lua_pushinteger(L, kCGTabletProximityEventVendorID);                     lua_setfield(L, -2, "tabletProximityEventVendorID");
    lua_pushstring(L, "tabletProximityEventVendorID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventVendorID);
    lua_pushinteger(L, kCGTabletProximityEventTabletID);                     lua_setfield(L, -2, "tabletProximityEventTabletID");
    lua_pushstring(L, "tabletProximityEventTabletID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventTabletID);
    lua_pushinteger(L, kCGTabletProximityEventPointerID);                    lua_setfield(L, -2, "tabletProximityEventPointerID");
    lua_pushstring(L, "tabletProximityEventPointerID") ;                    lua_rawseti(L, -2, kCGTabletProximityEventPointerID);
    lua_pushinteger(L, kCGTabletProximityEventDeviceID);                     lua_setfield(L, -2, "tabletProximityEventDeviceID");
    lua_pushstring(L, "tabletProximityEventDeviceID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventDeviceID);
    lua_pushinteger(L, kCGTabletProximityEventSystemTabletID);               lua_setfield(L, -2, "tabletProximityEventSystemTabletID");
    lua_pushstring(L, "tabletProximityEventSystemTabletID") ;               lua_rawseti(L, -2, kCGTabletProximityEventSystemTabletID);
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerType);            lua_setfield(L, -2, "tabletProximityEventVendorPointerType");
    lua_pushstring(L, "tabletProximityEventVendorPointerType") ;            lua_rawseti(L, -2, kCGTabletProximityEventVendorPointerType);
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerSerialNumber);    lua_setfield(L, -2, "tabletProximityEventVendorPointerSerialNumber");
    lua_pushstring(L, "tabletProximityEventVendorPointerSerialNumber") ;    lua_rawseti(L, -2, kCGTabletProximityEventVendorPointerSerialNumber);
    lua_pushinteger(L, kCGTabletProximityEventVendorUniqueID);               lua_setfield(L, -2, "tabletProximityEventVendorUniqueID");
    lua_pushstring(L, "tabletProximityEventVendorUniqueID") ;               lua_rawseti(L, -2, kCGTabletProximityEventVendorUniqueID);
    lua_pushinteger(L, kCGTabletProximityEventCapabilityMask);               lua_setfield(L, -2, "tabletProximityEventCapabilityMask");
    lua_pushstring(L, "tabletProximityEventCapabilityMask") ;               lua_rawseti(L, -2, kCGTabletProximityEventCapabilityMask);
    lua_pushinteger(L, kCGTabletProximityEventPointerType);                  lua_setfield(L, -2, "tabletProximityEventPointerType");
    lua_pushstring(L, "tabletProximityEventPointerType") ;                  lua_rawseti(L, -2, kCGTabletProximityEventPointerType);
    lua_pushinteger(L, kCGTabletProximityEventEnterProximity);               lua_setfield(L, -2, "tabletProximityEventEnterProximity");
    lua_pushstring(L, "tabletProximityEventEnterProximity") ;               lua_rawseti(L, -2, kCGTabletProximityEventEnterProximity);
    lua_pushinteger(L, kCGEventTargetProcessSerialNumber);                   lua_setfield(L, -2, "eventTargetProcessSerialNumber");
    lua_pushstring(L, "eventTargetProcessSerialNumber") ;                   lua_rawseti(L, -2, kCGEventTargetProcessSerialNumber);
    lua_pushinteger(L, kCGEventTargetUnixProcessID);                         lua_setfield(L, -2, "eventTargetUnixProcessID");
    lua_pushstring(L, "eventTargetUnixProcessID") ;                         lua_rawseti(L, -2, kCGEventTargetUnixProcessID);
    lua_pushinteger(L, kCGEventSourceUnixProcessID);                         lua_setfield(L, -2, "eventSourceUnixProcessID");
    lua_pushstring(L, "eventSourceUnixProcessID") ;                         lua_rawseti(L, -2, kCGEventSourceUnixProcessID);
    lua_pushinteger(L, kCGEventSourceUserData);                              lua_setfield(L, -2, "eventSourceUserData");
    lua_pushstring(L, "eventSourceUserData") ;                              lua_rawseti(L, -2, kCGEventSourceUserData);
    lua_pushinteger(L, kCGEventSourceUserID);                                lua_setfield(L, -2, "eventSourceUserID");
    lua_pushstring(L, "eventSourceUserID") ;                                lua_rawseti(L, -2, kCGEventSourceUserID);
    lua_pushinteger(L, kCGEventSourceGroupID);                               lua_setfield(L, -2, "eventSourceGroupID");
    lua_pushstring(L, "eventSourceGroupID") ;                               lua_rawseti(L, -2, kCGEventSourceGroupID);
    lua_pushinteger(L, kCGEventSourceStateID);                               lua_setfield(L, -2, "eventSourceStateID");
    lua_pushstring(L, "eventSourceStateID") ;                               lua_rawseti(L, -2, kCGEventSourceStateID);
    lua_pushinteger(L, kCGScrollWheelEventIsContinuous);                     lua_setfield(L, -2, "scrollWheelEventIsContinuous");
    lua_pushstring(L, "scrollWheelEventIsContinuous") ;                     lua_rawseti(L, -2, kCGScrollWheelEventIsContinuous);
}

static int userdata_tostring(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    int eventType = CGEventGetType(event) ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: Event type: %d (%p)", EVENT_USERDATA_TAG, eventType, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int meta_gc(lua_State* __unused L) {
    if (eventSource) {
        CFRelease(eventSource);
        eventSource = nil;
    }
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg eventtapevent_metalib[] = {
    {"copy",            eventtap_event_copy},
    {"getFlags",        eventtap_event_getFlags},
    {"setFlags",        eventtap_event_setFlags},
    {"getKeyCode",      eventtap_event_getKeyCode},
    {"setKeyCode",      eventtap_event_setKeyCode},
    {"getType",         eventtap_event_getType},
    {"post",            eventtap_event_post},
    {"getProperty",     eventtap_event_getProperty},
    {"setProperty",     eventtap_event_setProperty},
    {"getButtonState",  eventtap_event_getButtonState},
    {"getRawEventData", eventtap_event_getRawEventData},
    {"getCharacters",   eventtap_event_getCharacters},
    {"systemKey",       eventtap_event_systemKey},
    {"__tostring",      userdata_tostring},
    {"__gc",            eventtap_event_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg eventtapeventlib[] = {
    {"newKeyEvent",     eventtap_event_newKeyEvent},
    {"_newMouseEvent",  eventtap_event_newMouseEvent},
    {"newScrollEvent",  eventtap_event_newScrollWheelEvent},
    {NULL,              NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_eventtap_event(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibraryWithObject:EVENT_USERDATA_TAG functions:eventtapeventlib metaFunctions:meta_gcLib objectFunctions:eventtapevent_metalib];

    pushtypestable(L);
    lua_setfield(L, -2, "types");

    pushpropertiestable(L);
    lua_setfield(L, -2, "properties");

    eventSource = nil;

    return 1;
}
