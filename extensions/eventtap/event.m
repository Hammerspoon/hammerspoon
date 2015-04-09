#import "eventtap_event.h"


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
///  * None
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

    return 0;
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
    lua_pushnumber(L, CGEventGetDoubleValueField(event, kCGKeyboardEventKeycode));
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
///  * None
///
/// Notes:
///  * This method should only be used on keyboard events
static int eventtap_event_setKeyCode(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGKeyCode keycode = luaL_checknumber(L, 2);
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, (int64_t)keycode);
    return 0;
}

/// hs.eventtap.event:post([app])
/// Method
/// Posts the event to the OS - i.e. emits the keyboard/mouse input defined by the event
///
/// Parameters:
///  * app - An optional `hs.application` object. If specified, the event will only be sent to that application
///
/// Returns:
///  * None
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
        CGEventPost(kCGSessionEventTap, event);
    }

    return 0;
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
    lua_pushnumber(L, CGEventGetType(event));
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
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventField field = luaL_checknumber(L, 2);
    lua_pushnumber(L, CGEventGetDoubleValueField(event, field));
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
    CGMouseButton whichButton = luaL_checknumber(L, 2);

    if (CGEventSourceButtonState(CGEventGetDoubleValueField(event, kCGEventSourceStateID), whichButton))
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
///  * None
///
/// Notes:
///  * The properties are `CGEventField` values, as documented at https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/index.html#//apple_ref/c/tdef/CGEventField
static int eventtap_event_setProperty(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventField field = luaL_checknumber(L, 2);
    double value = luaL_checknumber(L, 3);
    CGEventSetDoubleValueField(event, field, value);
    return 0;
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
    CGKeyCode keycode = lua_tonumber(L, -1);
    lua_pop(L, 2);

    CGEventFlags flags = 0;
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        modifier = lua_tostring(L, -1);
        if (!modifier) {
            // FIXME: Show a proper error here, probably do a proper type check instead of just trusting lua_tostring
            NSLog(@"ERROR: Unexpected entry in modifiers table, seems to be null (%d)", lua_type(L, -1));
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

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef keyevent = CGEventCreateKeyboardEvent(source, keycode, isdown);
    CGEventSetFlags(keyevent, flags);
    new_eventtap_event(L, keyevent);
    CFRelease(keyevent);

    return 1;
}

static int eventtap_event_newMouseEvent(lua_State* L) {
    CGEventType type = luaL_checknumber(L, 1);
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
                NSLog(@"Error: Unexpected entry in modifiers table, seems to be null (%d)", lua_type(L, -1));
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

/// hs.eventtap.event.types -> table
/// Constant
/// A table for use with `hs.eventtap.new()`, containing the following keys:
///    keydown, keyup,
///    leftmousedown, leftmouseup, leftmousedragged,
///    rightmousedown, rightmouseup, rightmousedragged,
///    middlemousedown, middlemouseup, middlemousedragged,
///    mousemoved, flagschanged, scrollwheel,
///    tabletpointer, tabletproximity,
///    nullevent, tapdisabledbytimeout, tapdisabledbyuserinput
static void pushtypestable(lua_State* L) {
    lua_newtable(L);
    lua_pushnumber(L, kCGEventLeftMouseDown);           lua_setfield(L, -2, "leftmousedown");
    lua_pushstring(L, "leftmousedown") ;                lua_rawseti(L, -2, kCGEventLeftMouseDown);
    lua_pushnumber(L, kCGEventLeftMouseUp);             lua_setfield(L, -2, "leftmouseup");
    lua_pushstring(L, "leftmouseup") ;                  lua_rawseti(L, -2, kCGEventLeftMouseUp);
    lua_pushnumber(L, kCGEventLeftMouseDragged);        lua_setfield(L, -2, "leftmousedragged");
    lua_pushstring(L, "leftmousedragged") ;             lua_rawseti(L, -2, kCGEventLeftMouseDragged);
    lua_pushnumber(L, kCGEventRightMouseDown);          lua_setfield(L, -2, "rightmousedown");
    lua_pushstring(L, "rightmousedown") ;               lua_rawseti(L, -2, kCGEventRightMouseDown);
    lua_pushnumber(L, kCGEventRightMouseUp);            lua_setfield(L, -2, "rightmouseup");
    lua_pushstring(L, "rightmouseup") ;                 lua_rawseti(L, -2, kCGEventRightMouseUp);
    lua_pushnumber(L, kCGEventRightMouseDragged);       lua_setfield(L, -2, "rightmousedragged");
    lua_pushstring(L, "rightmousedragged") ;            lua_rawseti(L, -2, kCGEventRightMouseDragged);
    lua_pushnumber(L, kCGEventOtherMouseDown);          lua_setfield(L, -2, "middlemousedown");
    lua_pushstring(L, "middlemousedown") ;              lua_rawseti(L, -2, kCGEventOtherMouseDown);
    lua_pushnumber(L, kCGEventOtherMouseUp);            lua_setfield(L, -2, "middlemouseup");
    lua_pushstring(L, "middlemouseup") ;                lua_rawseti(L, -2, kCGEventOtherMouseUp);
    lua_pushnumber(L, kCGEventOtherMouseDragged);       lua_setfield(L, -2, "middlemousedragged");
    lua_pushstring(L, "middlemousedragged") ;           lua_rawseti(L, -2, kCGEventOtherMouseDragged);
    lua_pushnumber(L, kCGEventMouseMoved);              lua_setfield(L, -2, "mousemoved");
    lua_pushstring(L, "mousemoved") ;                   lua_rawseti(L, -2, kCGEventMouseMoved);
    lua_pushnumber(L, kCGEventFlagsChanged);            lua_setfield(L, -2, "flagschanged");
    lua_pushstring(L, "flagschanged") ;                 lua_rawseti(L, -2, kCGEventFlagsChanged);
    lua_pushnumber(L, kCGEventScrollWheel);             lua_setfield(L, -2, "scrollwheel");
    lua_pushstring(L, "scrollwheel") ;                  lua_rawseti(L, -2, kCGEventScrollWheel);
    lua_pushnumber(L, kCGEventKeyDown);                 lua_setfield(L, -2, "keydown");
    lua_pushstring(L, "keydown") ;                      lua_rawseti(L, -2, kCGEventKeyDown);
    lua_pushnumber(L, kCGEventKeyUp);                   lua_setfield(L, -2, "keyup");
    lua_pushstring(L, "keyup") ;                        lua_rawseti(L, -2, kCGEventKeyUp);
    lua_pushnumber(L, kCGEventTabletPointer);           lua_setfield(L, -2, "tabletpointer");
    lua_pushstring(L, "tabletpointer") ;                lua_rawseti(L, -2, kCGEventTabletPointer);
    lua_pushnumber(L, kCGEventTabletProximity);         lua_setfield(L, -2, "tabletproximity");
    lua_pushstring(L, "tabletproximity") ;              lua_rawseti(L, -2, kCGEventTabletProximity);
    lua_pushnumber(L, kCGEventNull);                    lua_setfield(L, -2, "nullevent");
    lua_pushstring(L, "nullevent") ;                    lua_rawseti(L, -2, kCGEventNull);
    lua_pushnumber(L, kCGEventTapDisabledByTimeout);    lua_setfield(L, -2, "tapdisabledbytimeout");
    lua_pushstring(L, "tapdisabledbytimeout") ;         lua_rawseti(L, -2, kCGEventTapDisabledByTimeout);
    lua_pushnumber(L, kCGEventTapDisabledByUserInput);  lua_setfield(L, -2, "tapdisabledbyuserinput");
    lua_pushstring(L, "tapdisabledbyuserinput") ;       lua_rawseti(L, -2, kCGEventTapDisabledByUserInput);
}

/// hs.eventtap.event.properties -> table
/// Constant
/// A table for use with `hs.eventtap.event:getProperty()` and `hs.eventtap.event:setProperty()`; contains the following keys:
///    - MouseEventNumber
///    - MouseEventClickState
///    - MouseEventPressure
///    - MouseEventButtonNumber
///    - MouseEventDeltaX
///    - MouseEventDeltaY
///    - MouseEventInstantMouser
///    - MouseEventSubtype
///    - KeyboardEventAutorepeat
///    - KeyboardEventKeycode
///    - KeyboardEventKeyboardType
///    - ScrollWheelEventDeltaAxis1
///    - ScrollWheelEventDeltaAxis2
///    - ScrollWheelEventDeltaAxis3
///    - ScrollWheelEventFixedPtDeltaAxis1
///    - ScrollWheelEventFixedPtDeltaAxis2
///    - ScrollWheelEventFixedPtDeltaAxis3
///    - ScrollWheelEventPointDeltaAxis1
///    - ScrollWheelEventPointDeltaAxis2
///    - ScrollWheelEventPointDeltaAxis3
///    - ScrollWheelEventInstantMouser
///    - TabletEventPointX
///    - TabletEventPointY
///    - TabletEventPointZ
///    - TabletEventPointButtons
///    - TabletEventPointPressure
///    - TabletEventTiltX
///    - TabletEventTiltY
///    - TabletEventRotation
///    - TabletEventTangentialPressure
///    - TabletEventDeviceID
///    - TabletEventVendor1
///    - TabletEventVendor2
///    - TabletEventVendor3
///    - TabletProximityEventVendorID
///    - TabletProximityEventTabletID
///    - TabletProximityEventPointerID
///    - TabletProximityEventDeviceID
///    - TabletProximityEventSystemTabletID
///    - TabletProximityEventVendorPointerType
///    - TabletProximityEventVendorPointerSerialNumber
///    - TabletProximityEventVendorUniqueID
///    - TabletProximityEventCapabilityMask
///    - TabletProximityEventPointerType
///    - TabletProximityEventEnterProximity
///    - EventTargetProcessSerialNumber
///    - EventTargetUnixProcessID
///    - EventSourceUnixProcessID
///    - EventSourceUserData
///    - EventSourceUserID
///    - EventSourceGroupID
///    - EventSourceStateID
///    - ScrollWheelEventIsContinuous
static void pushpropertiestable(lua_State* L) {
    lua_newtable(L);
    lua_pushnumber(L, kCGMouseEventNumber);                                 lua_setfield(L, -2, "MouseEventNumber");
    lua_pushstring(L, "MouseEventNumber") ;                                 lua_rawseti(L, -2, kCGMouseEventNumber);
    lua_pushnumber(L, kCGMouseEventClickState);                             lua_setfield(L, -2, "MouseEventClickState");
    lua_pushstring(L, "MouseEventClickState") ;                             lua_rawseti(L, -2, kCGMouseEventClickState);
    lua_pushnumber(L, kCGMouseEventPressure);                               lua_setfield(L, -2, "MouseEventPressure");
    lua_pushstring(L, "kCGMouseEventPressure") ;                            lua_rawseti(L, -2, kCGMouseEventPressure);
    lua_pushnumber(L, kCGMouseEventButtonNumber);                           lua_setfield(L, -2, "MouseEventButtonNumber");
    lua_pushstring(L, "MouseEventButtonNumber") ;                           lua_rawseti(L, -2, kCGMouseEventButtonNumber);
    lua_pushnumber(L, kCGMouseEventDeltaX);                                 lua_setfield(L, -2, "MouseEventDeltaX");
    lua_pushstring(L, "MouseEventDeltaX") ;                                 lua_rawseti(L, -2, kCGMouseEventDeltaX);
    lua_pushnumber(L, kCGMouseEventDeltaY);                                 lua_setfield(L, -2, "MouseEventDeltaY");
    lua_pushstring(L, "MouseEventDeltaY") ;                                 lua_rawseti(L, -2, kCGMouseEventDeltaY);
    lua_pushnumber(L, kCGMouseEventInstantMouser);                          lua_setfield(L, -2, "MouseEventInstantMouser");
    lua_pushstring(L, "MouseEventInstantMouser") ;                          lua_rawseti(L, -2, kCGMouseEventInstantMouser);
    lua_pushnumber(L, kCGMouseEventSubtype);                                lua_setfield(L, -2, "MouseEventSubtype");
    lua_pushstring(L, "MouseEventSubtype") ;                                lua_rawseti(L, -2, kCGMouseEventSubtype);
    lua_pushnumber(L, kCGKeyboardEventAutorepeat);                          lua_setfield(L, -2, "KeyboardEventAutorepeat");
    lua_pushstring(L, "KeyboardEventAutorepeat") ;                          lua_rawseti(L, -2, kCGKeyboardEventAutorepeat);
    lua_pushnumber(L, kCGKeyboardEventKeycode);                             lua_setfield(L, -2, "KeyboardEventKeycode");
    lua_pushstring(L, "KeyboardEventKeycode") ;                             lua_rawseti(L, -2, kCGKeyboardEventKeycode);
    lua_pushnumber(L, kCGKeyboardEventKeyboardType);                        lua_setfield(L, -2, "KeyboardEventKeyboardType");
    lua_pushstring(L, "KeyboardEventKeyboardType") ;                        lua_rawseti(L, -2, kCGKeyboardEventKeyboardType);
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis1);                       lua_setfield(L, -2, "ScrollWheelEventDeltaAxis1");
    lua_pushstring(L, "ScrollWheelEventDeltaAxis1") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis1);
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis2);                       lua_setfield(L, -2, "ScrollWheelEventDeltaAxis2");
    lua_pushstring(L, "ScrollWheelEventDeltaAxis2") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis2);
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis3);                       lua_setfield(L, -2, "ScrollWheelEventDeltaAxis3");
    lua_pushstring(L, "ScrollWheelEventDeltaAxis3") ;                       lua_rawseti(L, -2, kCGScrollWheelEventDeltaAxis3);
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis1);                lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis1");
    lua_pushstring(L, "ScrollWheelEventFixedPtDeltaAxis1") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis1);
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis2);                lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis2");
    lua_pushstring(L, "ScrollWheelEventFixedPtDeltaAxis2") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis2);
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis3);                lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis3");
    lua_pushstring(L, "ScrollWheelEventFixedPtDeltaAxis3") ;                lua_rawseti(L, -2, kCGScrollWheelEventFixedPtDeltaAxis3);
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis1);                  lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis1");
    lua_pushstring(L, "ScrollWheelEventPointDeltaAxis1") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis1);
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis2);                  lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis2");
    lua_pushstring(L, "ScrollWheelEventPointDeltaAxis2") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis2);
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis3);                  lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis3");
    lua_pushstring(L, "ScrollWheelEventPointDeltaAxis3") ;                  lua_rawseti(L, -2, kCGScrollWheelEventPointDeltaAxis3);
    lua_pushnumber(L, kCGScrollWheelEventInstantMouser);                    lua_setfield(L, -2, "ScrollWheelEventInstantMouser");
    lua_pushstring(L, "ScrollWheelEventInstantMouser") ;                    lua_rawseti(L, -2, kCGScrollWheelEventInstantMouser);
    lua_pushnumber(L, kCGTabletEventPointX);                                lua_setfield(L, -2, "TabletEventPointX");
    lua_pushstring(L, "TabletEventPointX") ;                                lua_rawseti(L, -2, kCGTabletEventPointX);
    lua_pushnumber(L, kCGTabletEventPointY);                                lua_setfield(L, -2, "TabletEventPointY");
    lua_pushstring(L, "TabletEventPointY") ;                                lua_rawseti(L, -2, kCGTabletEventPointY);
    lua_pushnumber(L, kCGTabletEventPointZ);                                lua_setfield(L, -2, "TabletEventPointZ");
    lua_pushstring(L, "TabletEventPointZ") ;                                lua_rawseti(L, -2, kCGTabletEventPointZ);
    lua_pushnumber(L, kCGTabletEventPointButtons);                          lua_setfield(L, -2, "TabletEventPointButtons");
    lua_pushstring(L, "TabletEventPointButtons") ;                          lua_rawseti(L, -2, kCGTabletEventPointButtons);
    lua_pushnumber(L, kCGTabletEventPointPressure);                         lua_setfield(L, -2, "TabletEventPointPressure");
    lua_pushstring(L, "TabletEventPointPressure") ;                         lua_rawseti(L, -2, kCGTabletEventPointPressure);
    lua_pushnumber(L, kCGTabletEventTiltX);                                 lua_setfield(L, -2, "TabletEventTiltX");
    lua_pushstring(L, "TabletEventTiltX") ;                                 lua_rawseti(L, -2, kCGTabletEventTiltX);
    lua_pushnumber(L, kCGTabletEventTiltY);                                 lua_setfield(L, -2, "TabletEventTiltY");
    lua_pushstring(L, "TabletEventTiltY") ;                                 lua_rawseti(L, -2, kCGTabletEventTiltY);
    lua_pushnumber(L, kCGTabletEventRotation);                              lua_setfield(L, -2, "TabletEventRotation");
    lua_pushstring(L, "TabletEventRotation") ;                              lua_rawseti(L, -2, kCGTabletEventRotation);
    lua_pushnumber(L, kCGTabletEventTangentialPressure);                    lua_setfield(L, -2, "TabletEventTangentialPressure");
    lua_pushstring(L, "TabletEventTangentialPressure") ;                    lua_rawseti(L, -2, kCGTabletEventTangentialPressure);
    lua_pushnumber(L, kCGTabletEventDeviceID);                              lua_setfield(L, -2, "TabletEventDeviceID");
    lua_pushstring(L, "TabletEventDeviceID") ;                              lua_rawseti(L, -2, kCGTabletEventDeviceID);
    lua_pushnumber(L, kCGTabletEventVendor1);                               lua_setfield(L, -2, "TabletEventVendor1");
    lua_pushstring(L, "TabletEventVendor1") ;                               lua_rawseti(L, -2, kCGTabletEventVendor1);
    lua_pushnumber(L, kCGTabletEventVendor2);                               lua_setfield(L, -2, "TabletEventVendor2");
    lua_pushstring(L, "TabletEventVendor2") ;                               lua_rawseti(L, -2, kCGTabletEventVendor2);
    lua_pushnumber(L, kCGTabletEventVendor3);                               lua_setfield(L, -2, "TabletEventVendor3");
    lua_pushstring(L, "TabletEventVendor3") ;                               lua_rawseti(L, -2, kCGTabletEventVendor3);
    lua_pushnumber(L, kCGTabletProximityEventVendorID);                     lua_setfield(L, -2, "TabletProximityEventVendorID");
    lua_pushstring(L, "TabletProximityEventVendorID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventVendorID);
    lua_pushnumber(L, kCGTabletProximityEventTabletID);                     lua_setfield(L, -2, "TabletProximityEventTabletID");
    lua_pushstring(L, "TabletProximityEventTabletID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventTabletID);
    lua_pushnumber(L, kCGTabletProximityEventPointerID);                    lua_setfield(L, -2, "TabletProximityEventPointerID");
    lua_pushstring(L, "TabletProximityEventPointerID") ;                    lua_rawseti(L, -2, kCGTabletProximityEventPointerID);
    lua_pushnumber(L, kCGTabletProximityEventDeviceID);                     lua_setfield(L, -2, "TabletProximityEventDeviceID");
    lua_pushstring(L, "TabletProximityEventDeviceID") ;                     lua_rawseti(L, -2, kCGTabletProximityEventDeviceID);
    lua_pushnumber(L, kCGTabletProximityEventSystemTabletID);               lua_setfield(L, -2, "TabletProximityEventSystemTabletID");
    lua_pushstring(L, "TabletProximityEventSystemTabletID") ;               lua_rawseti(L, -2, kCGTabletProximityEventSystemTabletID);
    lua_pushnumber(L, kCGTabletProximityEventVendorPointerType);            lua_setfield(L, -2, "TabletProximityEventVendorPointerType");
    lua_pushstring(L, "TabletProximityEventVendorPointerType") ;            lua_rawseti(L, -2, kCGTabletProximityEventVendorPointerType);
    lua_pushnumber(L, kCGTabletProximityEventVendorPointerSerialNumber);    lua_setfield(L, -2, "TabletProximityEventVendorPointerSerialNumber");
    lua_pushstring(L, "TabletProximityEventVendorPointerSerialNumber") ;    lua_rawseti(L, -2, kCGTabletProximityEventVendorPointerSerialNumber);
    lua_pushnumber(L, kCGTabletProximityEventVendorUniqueID);               lua_setfield(L, -2, "TabletProximityEventVendorUniqueID");
    lua_pushstring(L, "TabletProximityEventVendorUniqueID") ;               lua_rawseti(L, -2, kCGTabletProximityEventVendorUniqueID);
    lua_pushnumber(L, kCGTabletProximityEventCapabilityMask);               lua_setfield(L, -2, "TabletProximityEventCapabilityMask");
    lua_pushstring(L, "TabletProximityEventCapabilityMask") ;               lua_rawseti(L, -2, kCGTabletProximityEventCapabilityMask);
    lua_pushnumber(L, kCGTabletProximityEventPointerType);                  lua_setfield(L, -2, "TabletProximityEventPointerType");
    lua_pushstring(L, "TabletProximityEventPointerType") ;                  lua_rawseti(L, -2, kCGTabletProximityEventPointerType);
    lua_pushnumber(L, kCGTabletProximityEventEnterProximity);               lua_setfield(L, -2, "TabletProximityEventEnterProximity");
    lua_pushstring(L, "TabletProximityEventEnterProximity") ;               lua_rawseti(L, -2, kCGTabletProximityEventEnterProximity);
    lua_pushnumber(L, kCGEventTargetProcessSerialNumber);                   lua_setfield(L, -2, "EventTargetProcessSerialNumber");
    lua_pushstring(L, "EventTargetProcessSerialNumber") ;                   lua_rawseti(L, -2, kCGEventTargetProcessSerialNumber);
    lua_pushnumber(L, kCGEventTargetUnixProcessID);                         lua_setfield(L, -2, "EventTargetUnixProcessID");
    lua_pushstring(L, "EventTargetUnixProcessID") ;                         lua_rawseti(L, -2, kCGEventTargetUnixProcessID);
    lua_pushnumber(L, kCGEventSourceUnixProcessID);                         lua_setfield(L, -2, "EventSourceUnixProcessID");
    lua_pushstring(L, "EventSourceUnixProcessID") ;                         lua_rawseti(L, -2, kCGEventSourceUnixProcessID);
    lua_pushnumber(L, kCGEventSourceUserData);                              lua_setfield(L, -2, "EventSourceUserData");
    lua_pushstring(L, "EventSourceUserData") ;                              lua_rawseti(L, -2, kCGEventSourceUserData);
    lua_pushnumber(L, kCGEventSourceUserID);                                lua_setfield(L, -2, "EventSourceUserID");
    lua_pushstring(L, "EventSourceUserID") ;                                lua_rawseti(L, -2, kCGEventSourceUserID);
    lua_pushnumber(L, kCGEventSourceGroupID);                               lua_setfield(L, -2, "EventSourceGroupID");
    lua_pushstring(L, "EventSourceGroupID") ;                               lua_rawseti(L, -2, kCGEventSourceGroupID);
    lua_pushnumber(L, kCGEventSourceStateID);                               lua_setfield(L, -2, "EventSourceStateID");
    lua_pushstring(L, "EventSourceStateID") ;                               lua_rawseti(L, -2, kCGEventSourceStateID);
    lua_pushnumber(L, kCGScrollWheelEventIsContinuous);                     lua_setfield(L, -2, "ScrollWheelEventIsContinuous");
    lua_pushstring(L, "ScrollWheelEventIsContinuous") ;                     lua_rawseti(L, -2, kCGScrollWheelEventIsContinuous);
}

// static int meta_gc(lua_State* __unused L) {
//     [eventtapeventHandlers removeAllIndexes];
//     eventtapeventHandlers = nil;
//     return 0;
// }

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
    {"__gc",            eventtap_event_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg eventtapeventlib[] = {
    {"newKeyEvent",     eventtap_event_newKeyEvent},
    {"_newMouseEvent",   eventtap_event_newMouseEvent},
    {NULL,              NULL}
};

// // Metatable for returned object when module loads
// static const luaL_Reg meta_gcLib[] = {
//     {"__gc",    meta_gc},
//     {NULL,      NULL}
// };

int luaopen_hs_eventtap_event(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, eventtapevent_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, EVENT_USERDATA_TAG);

    luaL_newlib(L, eventtapeventlib);
        pushtypestable(L);
        lua_setfield(L, -2, "types");

        pushpropertiestable(L);
        lua_setfield(L, -2, "properties");

//         luaL_newlib(L, meta_gcLib);
//         lua_setmetatable(L, -2);

    return 1;
}
