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
    lua_pushnumber(L, CGEventGetDoubleValueField(event, kCGKeyboardEventKeycode));
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

/// eventtap.event:post(app = nil)
/// Posts the event to the system as if the user did it manually.
/// If app is a valid application instance, posts this event only to that application (I think).
static int eventtap_event_post(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    
    if (luaL_testudata(L, 2, "application")) {
        AXUIElementRef app = lua_touserdata(L, 2);
        
        pid_t pid;
        AXUIElementGetPid(app, &pid);
        
        ProcessSerialNumber psn;
        GetProcessForPID(pid, &psn);
        CGEventPostToPSN(&psn, event);
    }
    else {
        CGEventPost(kCGSessionEventTap, event);
    }
    
    return 0;
}

/// eventtap.event:gettype() -> number
/// Gets the type of the given event; return value will be one of the values in the eventtap.event.types table.
static int eventtap_event_gettype(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    lua_pushnumber(L, CGEventGetType(event));
    return 1;
}

/// eventtap.event:getproperty(prop) -> number
/// Gets the given property of the given event; prop is one of the values in the eventtap.event.properties table; return value is a number defined here: https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html#//apple_ref/c/tdef/CGEventField
static int eventtap_event_getproperty(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CGEventField field = luaL_checknumber(L, 2);
    lua_pushnumber(L, CGEventGetDoubleValueField(event, field));
    return 1;
}

/// eventtap.event:setproperty(prop, value)
/// Sets the given property of the given event; prop is one of the values in the eventtap.event.properties table; value is a number defined here: https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html#//apple_ref/c/tdef/CGEventField
static int eventtap_event_setproperty(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, "eventtap_event");
    CGEventField field = luaL_checknumber(L, 2);
    double value = luaL_checknumber(L, 3);
    CGEventSetDoubleValueField(event, field, value);
    return 0;
}

/// eventtap.event.newkeyevent(mods, key, isdown) -> event
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

/// eventtap.event.newmouseevent(type, point, button) -> event
/// Creates a new mouse event.
///   - type is one of the values in eventtap.event.types
///   - point is a table with keys {x,y}
///   - button is a string of one of the values: {'left', 'right', 'middle'}
static int eventtap_event_newmouseevent(lua_State* L) {
    CGEventType type = luaL_checknumber(L, 1);
    CGPoint point = hydra_topoint(L, 2);
    const char* buttonString = luaL_checkstring(L, 3);
    
    CGMouseButton button = kCGMouseButtonLeft;
    
    if (strcmp(buttonString, "right") == 0)
        button = kCGMouseButtonRight;
    else if (strcmp(buttonString, "middle") == 0)
        button = kCGMouseButtonCenter;
    
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef event = CGEventCreateMouseEvent(source, type, point, button);
    new_eventtap_event(L, event);
    CFRelease(event);
    
    return 1;
}

/// eventtap.event.types -> table
/// Table for use with `eventtap.new`, with the following keys:
///   keydown, keyup,
///   leftmousedown, leftmouseup, leftmousedragged,
///   rightmousedown, rightmouseup, rightmousedragged,
///   middlemousedown, middlemouseup, middlemousedragged,
///   mousemoved, flagschanged, scrollwheel
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

/// eventtap.event.properties -> table
/// For use with eventtap.event:{get,set}property; contains the following keys:
///   - MouseEventNumber
///   - MouseEventClickState
///   - MouseEventPressure
///   - MouseEventButtonNumber
///   - MouseEventDeltaX
///   - MouseEventDeltaY
///   - MouseEventInstantMouser
///   - MouseEventSubtype
///   - KeyboardEventAutorepeat
///   - KeyboardEventKeycode
///   - KeyboardEventKeyboardType
///   - ScrollWheelEventDeltaAxis1
///   - ScrollWheelEventDeltaAxis2
///   - ScrollWheelEventDeltaAxis3
///   - ScrollWheelEventFixedPtDeltaAxis1
///   - ScrollWheelEventFixedPtDeltaAxis2
///   - ScrollWheelEventFixedPtDeltaAxis3
///   - ScrollWheelEventPointDeltaAxis1
///   - ScrollWheelEventPointDeltaAxis2
///   - ScrollWheelEventPointDeltaAxis3
///   - ScrollWheelEventInstantMouser
///   - TabletEventPointX
///   - TabletEventPointY
///   - TabletEventPointZ
///   - TabletEventPointButtons
///   - TabletEventPointPressure
///   - TabletEventTiltX
///   - TabletEventTiltY
///   - TabletEventRotation
///   - TabletEventTangentialPressure
///   - TabletEventDeviceID
///   - TabletEventVendor1
///   - TabletEventVendor2
///   - TabletEventVendor3
///   - TabletProximityEventVendorID
///   - TabletProximityEventTabletID
///   - TabletProximityEventPointerID
///   - TabletProximityEventDeviceID
///   - TabletProximityEventSystemTabletID
///   - TabletProximityEventVendorPointerType
///   - TabletProximityEventVendorPointerSerialNumber
///   - TabletProximityEventVendorUniqueID
///   - TabletProximityEventCapabilityMask
///   - TabletProximityEventPointerType
///   - TabletProximityEventEnterProximity
///   - EventTargetProcessSerialNumber
///   - EventTargetUnixProcessID
///   - EventSourceUnixProcessID
///   - EventSourceUserData
///   - EventSourceUserID
///   - EventSourceGroupID
///   - EventSourceStateID
///   - ScrollWheelEventIsContinuous
static void pushpropertiestable(lua_State* L) {
    lua_newtable(L);
    lua_pushnumber(L, kCGMouseEventNumber);                               lua_setfield(L, -2, "MouseEventNumber");
    lua_pushnumber(L, kCGMouseEventClickState);                           lua_setfield(L, -2, "MouseEventClickState");
    lua_pushnumber(L, kCGMouseEventPressure);                             lua_setfield(L, -2, "MouseEventPressure");
    lua_pushnumber(L, kCGMouseEventButtonNumber);                         lua_setfield(L, -2, "MouseEventButtonNumber");
    lua_pushnumber(L, kCGMouseEventDeltaX);                               lua_setfield(L, -2, "MouseEventDeltaX");
    lua_pushnumber(L, kCGMouseEventDeltaY);                               lua_setfield(L, -2, "MouseEventDeltaY");
    lua_pushnumber(L, kCGMouseEventInstantMouser);                        lua_setfield(L, -2, "MouseEventInstantMouser");
    lua_pushnumber(L, kCGMouseEventSubtype);                              lua_setfield(L, -2, "MouseEventSubtype");
    lua_pushnumber(L, kCGKeyboardEventAutorepeat);                        lua_setfield(L, -2, "KeyboardEventAutorepeat");
    lua_pushnumber(L, kCGKeyboardEventKeycode);                           lua_setfield(L, -2, "KeyboardEventKeycode");
    lua_pushnumber(L, kCGKeyboardEventKeyboardType);                      lua_setfield(L, -2, "KeyboardEventKeyboardType");
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis1);                     lua_setfield(L, -2, "ScrollWheelEventDeltaAxis1");
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis2);                     lua_setfield(L, -2, "ScrollWheelEventDeltaAxis2");
    lua_pushnumber(L, kCGScrollWheelEventDeltaAxis3);                     lua_setfield(L, -2, "ScrollWheelEventDeltaAxis3");
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis1);              lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis1");
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis2);              lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis2");
    lua_pushnumber(L, kCGScrollWheelEventFixedPtDeltaAxis3);              lua_setfield(L, -2, "ScrollWheelEventFixedPtDeltaAxis3");
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis1);                lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis1");
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis2);                lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis2");
    lua_pushnumber(L, kCGScrollWheelEventPointDeltaAxis3);                lua_setfield(L, -2, "ScrollWheelEventPointDeltaAxis3");
    lua_pushnumber(L, kCGScrollWheelEventInstantMouser);                  lua_setfield(L, -2, "ScrollWheelEventInstantMouser");
    lua_pushnumber(L, kCGTabletEventPointX);                              lua_setfield(L, -2, "TabletEventPointX");
    lua_pushnumber(L, kCGTabletEventPointY);                              lua_setfield(L, -2, "TabletEventPointY");
    lua_pushnumber(L, kCGTabletEventPointZ);                              lua_setfield(L, -2, "TabletEventPointZ");
    lua_pushnumber(L, kCGTabletEventPointButtons);                        lua_setfield(L, -2, "TabletEventPointButtons");
    lua_pushnumber(L, kCGTabletEventPointPressure);                       lua_setfield(L, -2, "TabletEventPointPressure");
    lua_pushnumber(L, kCGTabletEventTiltX);                               lua_setfield(L, -2, "TabletEventTiltX");
    lua_pushnumber(L, kCGTabletEventTiltY);                               lua_setfield(L, -2, "TabletEventTiltY");
    lua_pushnumber(L, kCGTabletEventRotation);                            lua_setfield(L, -2, "TabletEventRotation");
    lua_pushnumber(L, kCGTabletEventTangentialPressure);                  lua_setfield(L, -2, "TabletEventTangentialPressure");
    lua_pushnumber(L, kCGTabletEventDeviceID);                            lua_setfield(L, -2, "TabletEventDeviceID");
    lua_pushnumber(L, kCGTabletEventVendor1);                             lua_setfield(L, -2, "TabletEventVendor1");
    lua_pushnumber(L, kCGTabletEventVendor2);                             lua_setfield(L, -2, "TabletEventVendor2");
    lua_pushnumber(L, kCGTabletEventVendor3);                             lua_setfield(L, -2, "TabletEventVendor3");
    lua_pushnumber(L, kCGTabletProximityEventVendorID);                   lua_setfield(L, -2, "TabletProximityEventVendorID");
    lua_pushnumber(L, kCGTabletProximityEventTabletID);                   lua_setfield(L, -2, "TabletProximityEventTabletID");
    lua_pushnumber(L, kCGTabletProximityEventPointerID);                  lua_setfield(L, -2, "TabletProximityEventPointerID");
    lua_pushnumber(L, kCGTabletProximityEventDeviceID);                   lua_setfield(L, -2, "TabletProximityEventDeviceID");
    lua_pushnumber(L, kCGTabletProximityEventSystemTabletID);             lua_setfield(L, -2, "TabletProximityEventSystemTabletID");
    lua_pushnumber(L, kCGTabletProximityEventVendorPointerType);          lua_setfield(L, -2, "TabletProximityEventVendorPointerType");
    lua_pushnumber(L, kCGTabletProximityEventVendorPointerSerialNumber);  lua_setfield(L, -2, "TabletProximityEventVendorPointerSerialNumber");
    lua_pushnumber(L, kCGTabletProximityEventVendorUniqueID);             lua_setfield(L, -2, "TabletProximityEventVendorUniqueID");
    lua_pushnumber(L, kCGTabletProximityEventCapabilityMask);             lua_setfield(L, -2, "TabletProximityEventCapabilityMask");
    lua_pushnumber(L, kCGTabletProximityEventPointerType);                lua_setfield(L, -2, "TabletProximityEventPointerType");
    lua_pushnumber(L, kCGTabletProximityEventEnterProximity);             lua_setfield(L, -2, "TabletProximityEventEnterProximity");
    lua_pushnumber(L, kCGEventTargetProcessSerialNumber);                 lua_setfield(L, -2, "EventTargetProcessSerialNumber");
    lua_pushnumber(L, kCGEventTargetUnixProcessID);                       lua_setfield(L, -2, "EventTargetUnixProcessID");
    lua_pushnumber(L, kCGEventSourceUnixProcessID);                       lua_setfield(L, -2, "EventSourceUnixProcessID");
    lua_pushnumber(L, kCGEventSourceUserData);                            lua_setfield(L, -2, "EventSourceUserData");
    lua_pushnumber(L, kCGEventSourceUserID);                              lua_setfield(L, -2, "EventSourceUserID");
    lua_pushnumber(L, kCGEventSourceGroupID);                             lua_setfield(L, -2, "EventSourceGroupID");
    lua_pushnumber(L, kCGEventSourceStateID);                             lua_setfield(L, -2, "EventSourceStateID");
    lua_pushnumber(L, kCGScrollWheelEventIsContinuous);                   lua_setfield(L, -2, "ScrollWheelEventIsContinuous");                    
}

static luaL_Reg eventtapeventlib[] = {
    // module methods
    {"newkeyevent", eventtap_event_newkeyevent},
    {"newmouseevent", eventtap_event_newmouseevent},
    
    // instance methods
    {"copy", eventtap_event_copy},
    {"getflags", eventtap_event_getflags},
    {"setflags", eventtap_event_setflags},
    {"getkeycode", eventtap_event_getkeycode},
    {"setkeycode", eventtap_event_setkeycode},
    {"gettype", eventtap_event_gettype},
    {"post", eventtap_event_post},
    
    {"getproperty", eventtap_event_getproperty},
    {"setproperty", eventtap_event_setproperty},
    
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
    
    pushpropertiestable(L);
    lua_setfield(L, -2, "properties");
    
    return 1;
}
