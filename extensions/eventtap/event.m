#import "eventtap_event.h"
@import IOKit.hidsystem ;

#define FLAGS_TAG "hs.eventtap.event.flags"

static CGEventSourceRef eventSource = NULL;

static int eventtap_event_gc(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    if (event)
      CFRelease(event);
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0;
}

/// hs.eventtap.event:copy() -> event
/// Constructor
/// Duplicates an `hs.eventtap.event` event for further modification or injection
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

/// hs.eventtap.event.newEvent() -> event
/// Constructor
/// Creates a blank event.  You will need to set its type with [hs.eventtap.event:setType](#setType)
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new `hs.eventtap.event` object
///
/// Notes:
///  * this is an empty event that you should set a type for and whatever other properties may be appropriate before posting.
static int eventtap_event_newEvent(lua_State* L) {
    CGEventRef event = CGEventCreate(eventSource);
    new_eventtap_event(L, event);
    CFRelease(event);
    return 1;
}

/// hs.eventtap.event.newEventFromData(data) -> event
/// Constructor
/// Creates an event from the data encoded in the string provided.
///
/// Parameters:
///  * data - a string containing binary data provided by [hs.eventtap.event:asData](#asData) representing an event.
///
/// Returns:
///  * a new `hs.eventtap.event` object or nil if the string did not represent a valid event
static int eventtap_event_newEventFromData(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSData *data = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;

    CGEventRef event = CGEventCreateFromData(NULL, (__bridge CFDataRef)data);
    if (event) {
        new_eventtap_event(L, event);
        CFRelease(event);
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.eventtap.event:asData() -> string
/// Method
/// Returns a string containing binary data representing the event.  This can be used to record events for later use.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string representing the event or nil if the event cannot be represented as a string
///
/// Notes:
///  * You can recreate the event for later posting with [hs.eventtap.event.newnEventFromData](#newEventFromData)
static int eventtap_event_asData(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CFDataRef data = CGEventCreateData(NULL, event) ;
    if (data) {
        [[LuaSkin shared] pushNSObject:(__bridge_transfer NSData *)data] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.eventtap.event:location([pointTable]) -> event | table
/// Method
/// Get or set the current mouse pointer location as defined for the event.
///
/// Parameters:
///  * pointTable - an optional point table specifying the x and y coordinates of the mouse pointer location for the event
///
/// Returns:
///  * if pointTable is provided, returns the `hs.eventtap.event` object; otherwise returns a point table containing x and y key-value pairs specifying the mouse pointer location as specified for this event.
///
/// Notes:
///  * the use or effect of this method is undefined if the event is not a mouse type event.
static int eventtap_event_location(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:NSPointFromCGPoint(CGEventGetLocation(event))] ;
    } else {
        NSPoint theLocation = [skin tableToPointAtIndex:2] ;
        CGEventSetLocation(event, NSPointToCGPoint(theLocation)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.eventtap.event:timestamp([absolutetime]) -> event | integer
/// Method
/// Get or set the timestamp of the event.
///
/// Parameters:
///  * absolutetime - an optional integer specifying the timestamp for the event.
///
/// Returns:
///  * if absolutetime is provided, returns the `hs.eventtap.event` object; otherwise returns the current timestamp for the event.
///
/// Notes:
///  * Synthesized events have a timestamp of 0 by default.
///  * The timestamp, if specified, is expressed as an integer representing the number of nanoseconds since the system was last booted.  See `hs.timer.absoluteTime`.
///  * This field appears to be informational only and is not required when crafting your own events with this module.
static int eventtap_event_timestamp(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)CGEventGetTimestamp(event)) ;
    } else {
        CGEventSetTimestamp(event, (CGEventTimestamp)lua_tointeger(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.eventtap.event:setType(type) -> event
/// Method
/// Set the type for this event.
///
/// Parameters:
///  * type - an integer matching one of the event types described in [hs.eventtap.event.types](#types)
///
/// Returns:
///  * the `hs.eventtap.event` object
static int eventtap_event_setType(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventSetType(event, (CGEventType)lua_tointeger(L, 2)) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.eventtap.event:rawFlags([flags]) -> event | integer
/// Method
/// Experimental method to get or set the modifier flags for an event directly.
///
/// Parameters:
///  * flags - an optional integer, made by logically combining values from [hs.eventtap.event.rawFlagMasks](#rawFlagMasks) specifying the modifier keys which should be set for this event
///
/// Returns:
///  * if flags is provided, returns the `hs.eventtap.event` object; otherwise returns the current flags set as an integer
///
/// Notes:
///  * This method is experimental and may undergo changes or even removal in the future
///  * See [hs.eventtap.event.rawFlagMasks](#rawFlagMasks) for more information
static int eventtap_event_rawFlags(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)CGEventGetFlags(event)) ;
    } else {
        CGEventSetFlags(event, (CGEventFlags)lua_tointeger(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.eventtap.event:getFlags() -> table
/// Method
/// Gets the keyboard modifiers of an event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the keyboard modifiers that present in the event - i.e. zero or more of the following keys, each with a value of `true`:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///  * The table responds to the following methods:
///   * contain(mods) -> boolean
///    * Returns true if the modifiers contain all of given modifiers
///   * containExactly(mods) -> boolean
///    * Returns true if the modifiers contain all of given modifiers exactly and nothing else
///  * Parameter mods is a table containing zero or more of the following:
///   * cmd or ⌘
///   * alt or ⌥
///   * shift or ⇧
///   * ctrl or ⌃
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

    luaL_getmetatable(L, FLAGS_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.eventtap.event:setFlags(table) -> event
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
///  * The `hs.eventap.event` object.
static int eventtap_event_setFlags(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    luaL_checktype(L, 2, LUA_TTABLE);

    CGEventFlags flags = (CGEventFlags)0;

    if ((void)lua_getfield(L, 2, "cmd"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskCommand;
    if ((void)lua_getfield(L, 2, "alt"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskAlternate;
    if ((void)lua_getfield(L, 2, "ctrl"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskControl;
    if ((void)lua_getfield(L, 2, "shift"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskShift;
    if ((void)lua_getfield(L, 2, "fn"), lua_toboolean(L, -1)) flags |= kCGEventFlagMaskSecondaryFn;

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
            if ((type == NSEventTypeKeyDown) || (type == NSEventTypeKeyUp)) {
                lua_pushstring(L, [[sysEvent characters] UTF8String]) ;                       lua_setfield(L, -2, "characters") ;
                lua_pushstring(L, [[sysEvent charactersIgnoringModifiers] UTF8String]) ;      lua_setfield(L, -2, "charactersIgnoringModifiers") ;
                lua_pushinteger(L, [sysEvent keyCode]) ;                                      lua_setfield(L, -2, "keyCode") ;
            }
            if ((type == NSEventTypeLeftMouseDown) || (type == NSEventTypeLeftMouseUp) || (type == NSEventTypeRightMouseDown) || (type == NSEventTypeRightMouseUp) || (type == NSEventTypeOtherMouseDown) || (type == NSEventTypeOtherMouseUp)) {
                lua_pushinteger(L, [sysEvent buttonNumber]) ;                                 lua_setfield(L, -2, "buttonNumber") ;
                lua_pushinteger(L, [sysEvent clickCount]) ;                                   lua_setfield(L, -2, "clickCount") ;
                lua_pushnumber(L, (lua_Number)[sysEvent pressure]) ;                          lua_setfield(L, -2, "pressure") ;
            }
            if ((type == NSEventTypeAppKitDefined) || (type == NSEventTypeSystemDefined) || (type == NSEventTypeApplicationDefined) || (type == NSEventTypePeriodic)) {
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
    BOOL        clean    = lua_isnone(L, 2) ? NO : (BOOL)lua_toboolean(L, 2) ;
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
    CGKeyCode keycode = (CGKeyCode)luaL_checkinteger(L, 2);
    CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, (int64_t)keycode);

    lua_settop(L,1) ;
    return 1;
}

/// hs.eventtap.event:getUnicodeString()
/// Method
/// Gets the single unicode character of an event
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the unicode character
static int eventtap_event_getUnicodeString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TBREAK];

    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    UniChar *buffer;
    UniCharCount actual = 0;
    // Get the length of the string
    CGEventKeyboardGetUnicodeString(event, 0, &actual, NULL);
    buffer = malloc(actual * sizeof(UniChar));
    CGEventKeyboardGetUnicodeString(event, actual, &actual, buffer);

    // Convert buffer -> NSString
    NSString *theString = [NSString stringWithCharacters:buffer length:actual];
    [skin pushNSObject:theString];

    return 1;
}

/// hs.eventtap.event:setUnicodeString(string)
/// Method
/// Sets a unicode string as the output of the event
///
/// Parameters:
///  * string - A string containing unicode characters, which will be applied to the event
///
/// Returns:
///  * The `hs.eventtap.event` object
///
/// Notes:
///  * Calling this method will reset any flags previously set on the event (because they don't make any sense, and you should not try to set flags again)
///  * This is likely to only work with short unicode strings that resolve to a single character
static int eventtap_event_setUnicodeString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TSTRING, LS_TBREAK];

    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    NSString *theString = [skin toNSObjectAtIndex:2];
    NSUInteger stringLen = theString.length;
    NSUInteger usedLen = 0;

    UniChar buffer[stringLen];
    [theString getBytes:(void*)&buffer
              maxLength:stringLen
             usedLength:&usedLen
               encoding:NSUnicodeStringEncoding
                options:NSStringEncodingConversionAllowLossy
                  range:NSMakeRange(0, stringLen)
         remainingRange:NULL];

    CGEventSetFlags(event, (CGEventFlags)0);
    CGEventKeyboardSetUnicodeString(event, usedLen, buffer);

    lua_settop(L, 1);
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
//         AXUIElementRef app = lua_touserdata(L, 2);
        AXUIElementRef app = *((AXUIElementRef*)luaL_checkudata(L, 2, "hs.application")) ;

        pid_t pid;
        AXUIElementGetPid(app, &pid);

        ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSStatus err = GetProcessForPID(pid, &psn);
#pragma clang diagnostic pop
        if (err != noErr) {
            NSLog(@"ERROR: Unable to get PSN for PID: %d", pid);
        } else {
            CGEventPostToPSN(&psn, event);
        }
    }
    else {
        CGEventPost(kCGSessionEventTap, event);
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
    CGEventField field = (CGEventField)(luaL_checkinteger(L, 2));

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
    CGMouseButton whichButton = (CGMouseButton)(luaL_checkinteger(L, 2));

    if (CGEventSourceButtonState((CGEventSourceStateID)(CGEventGetIntegerValueField(event, kCGEventSourceStateID)), whichButton))
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
    CGEventField field = (CGEventField)(luaL_checkinteger(L, 2));
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
        int64_t value = (int64_t)luaL_checkinteger(L, 3);
        CGEventSetIntegerValueField(event, field, value);
    }

    lua_settop(L,1) ;
    return 1;
}

/// hs.eventtap.event.newKeyEvent([mods], key, isdown) -> event
/// Constructor
/// Creates a keyboard event
///
/// Parameters:
///  * mods - An optional table containing zero or more of the following:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///  * key - A string containing the name of a key (see `hs.hotkey` for more information) or an integer specifying the virtual keycode for the key.
///  * isdown - A boolean, true if the event should be a key-down, false if it should be a key-up
///
/// Returns:
///  * An `hs.eventtap.event` object
///
/// Notes:
///  * The original version of this constructor utilized a shortcut which merged `flagsChanged` and `keyUp`/`keyDown` events into one.  This approach is still supported for backwards compatibility and because it *does* work in most cases.
///  * According to Apple Documentation, the proper way to perform a keypress with modifiers is through multiple key events; for example to generate 'Å', you should do the following:
/// ~~~lua
///     hs.eventtap.event.newKeyEvent(hs.keycodes.map.shift, true):post()
///     hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, true):post()
///     hs.eventtap.event.newKeyEvent("a", true):post()
///     hs.eventtap.event.newKeyEvent("a", false):post()
///     hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, false):post()
///     hs.eventtap.event.newKeyEvent(hs.keycodes.map.shift, false):post()
/// ~~~
///  * The shortcut method is still supported, though if you run into odd behavior or need to generate `flagsChanged` events without a corresponding `keyUp` or `keyDown`, please check out the syntax demonstrated above.
/// ~~~lua
///     hs.eventtap.event.newKeyEvent({"shift", "alt"}, "a", true):post()
///     hs.eventtap.event.newKeyEvent({"shift", "alt"}, "a", false):post()
/// ~~~
///
/// * The shortcut approach is still limited to generating only the left version of modifiers.
static int eventtap_event_newKeyEvent(lua_State* L) {
    LuaSkin      *skin = [LuaSkin shared];
    BOOL         hasModTable = NO ;
    int          keyCodePos = 2 ;
    CGEventFlags flags = (CGEventFlags)0;

    if (lua_type(L, 1) == LUA_TTABLE) {
        [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        const char *modifier;

        lua_pushnil(L);
        while (lua_next(L, 1) != 0) {
            modifier = lua_tostring(L, -1);
            if (!modifier) {
                [skin logBreadcrumb:[NSString stringWithFormat:@"hs.eventtap.event.newKeyEvent() unexpected entry in modifiers table: %d", lua_type(L, -1)]];
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
        hasModTable = YES ;
    } else if (lua_type(L, 1) == LUA_TNIL) {
        [skin checkArgs:LS_TNIL, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        keyCodePos  = 1 ;
    }
    BOOL         isDown  = (BOOL)lua_toboolean(L, keyCodePos + 1) ;
    CGKeyCode    keyCode = (CGKeyCode)lua_tointeger(L, keyCodePos) ;

    CGEventRef keyevent = CGEventCreateKeyboardEvent(eventSource, keyCode, isDown);
    if (hasModTable) CGEventSetFlags(keyevent, flags);
    new_eventtap_event(L, keyevent);
    CFRelease(keyevent);

    return 1;
}

/// hs.eventtap.event.newSystemKeyEvent(key, isdown) -> event
/// Constructor
/// Creates a keyboard event for special keys (e.g. media playback)
///
/// Parameters:
///  * key - A string containing the name of a special key. The possible names are:
///   * SOUND_UP
///   * SOUND_DOWN
///   * MUTE
///   * BRIGHTNESS_UP
///   * BRIGHTNESS_DOWN
///   * CONTRAST_UP
///   * CONTRAST_DOWN
///   * POWER
///   * LAUNCH_PANEL
///   * VIDMIRROR
///   * PLAY
///   * EJECT
///   * NEXT
///   * PREVIOUS
///   * FAST
///   * REWIND
///   * ILLUMINATION_UP
///   * ILLUMINATION_DOWN
///   * ILLUMINATION_TOGGLE
///   * CAPS_LOCK
///   * HELP
///   * NUM_LOCK
///  * isdown - A boolean, true if the event should be a key-down, false if it should be a key-up
///
/// Returns:
///  * An `hs.eventtap.event` object
///
/// Notes:
///  * To set modifiers on a system key event (e.g. cmd/ctrl/etc), see the `hs.eventtap.event:setFlags()` method
///  * The event names are case sensitive
static int eventtap_event_newSystemKeyEvent(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN, LS_TBREAK];

    NSString *keyName = [skin toNSObjectAtIndex:1];
    BOOL isDown = (BOOL)lua_toboolean(L, 2);
    int keyVal = -1;

    if ([keyName isEqualToString:@"SOUND_UP"]) {
        keyVal = NX_KEYTYPE_SOUND_UP;
    } else if ([keyName isEqualToString:@"SOUND_DOWN"]) {
        keyVal = NX_KEYTYPE_SOUND_DOWN;
    } else if ([keyName isEqualToString:@"POWER"]) {
        keyVal = NX_POWER_KEY;
    } else if ([keyName isEqualToString:@"MUTE"]) {
        keyVal = NX_KEYTYPE_MUTE;
    } else if ([keyName isEqualToString:@"BRIGHTNESS_UP"]) {
        keyVal = NX_KEYTYPE_BRIGHTNESS_UP;
    } else if ([keyName isEqualToString:@"BRIGHTNESS_DOWN"]) {
        keyVal = NX_KEYTYPE_BRIGHTNESS_DOWN;
    } else if ([keyName isEqualToString:@"CONTRAST_UP"]) {
        keyVal = NX_KEYTYPE_CONTRAST_UP;
    } else if ([keyName isEqualToString:@"CONTRAST_DOWN"]) {
        keyVal = NX_KEYTYPE_CONTRAST_DOWN;
    } else if ([keyName isEqualToString:@"LAUNCH_PANEL"]) {
        keyVal = NX_KEYTYPE_LAUNCH_PANEL;
    } else if ([keyName isEqualToString:@"EJECT"]) {
        keyVal = NX_KEYTYPE_EJECT;
    } else if ([keyName isEqualToString:@"VIDMIRROR"]) {
        keyVal = NX_KEYTYPE_VIDMIRROR;
    } else if ([keyName isEqualToString:@"PLAY"]) {
        keyVal = NX_KEYTYPE_PLAY;
    } else if ([keyName isEqualToString:@"NEXT"]) {
        keyVal = NX_KEYTYPE_NEXT;
    } else if ([keyName isEqualToString:@"PREVIOUS"]) {
        keyVal = NX_KEYTYPE_PREVIOUS;
    } else if ([keyName isEqualToString:@"FAST"]) {
        keyVal = NX_KEYTYPE_FAST;
    } else if ([keyName isEqualToString:@"REWIND"]) {
        keyVal = NX_KEYTYPE_REWIND;
    } else if ([keyName isEqualToString:@"ILLUMINATION_UP"]) {
        keyVal = NX_KEYTYPE_ILLUMINATION_UP;
    } else if ([keyName isEqualToString:@"ILLUMINATION_DOWN"]) {
        keyVal = NX_KEYTYPE_ILLUMINATION_DOWN;
    } else if ([keyName isEqualToString:@"ILLUMINATION_TOGGLE"]) {
        keyVal = NX_KEYTYPE_ILLUMINATION_TOGGLE;
    } else if ([keyName isEqualToString:@"CAPS_LOCK"]) {
        keyVal = NX_KEYTYPE_CAPS_LOCK;
    } else if ([keyName isEqualToString:@"HELP"]) {
        keyVal = NX_KEYTYPE_HELP;
    } else if ([keyName isEqualToString:@"NUM_LOCK"]) {
        keyVal = NX_KEYTYPE_NUM_LOCK;
    } else {
        [skin logError:[NSString stringWithFormat:@"Unknown system key for hs.eventtap.event.newSystemKeyEvent(): %@", keyName]];
        lua_pushnil(L);
        return 1;
    }

    NSEvent *keyEvent = [NSEvent otherEventWithType:NSEventTypeSystemDefined location:NSMakePoint(0, 0) modifierFlags:(isDown ? NX_KEYDOWN : NX_KEYUP) timestamp:0 windowNumber:0 context:0 subtype:NX_SUBTYPE_AUX_CONTROL_BUTTONS data1:(keyVal << 16 | (isDown ? NX_KEYDOWN : NX_KEYUP) << 8) data2:-1];
    new_eventtap_event(L, keyEvent.CGEvent);

    return 1;
}

/// hs.eventtap.event.newScrollEvent(offsets, mods, unit) -> event
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
    LuaSkin *skin = [LuaSkin shared];
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushnumber(L, 1); lua_gettable(L, 1); int32_t offset_y = (int32_t)lua_tointeger(L, -1) ; lua_pop(L, 1);
    lua_pushnumber(L, 2); lua_gettable(L, 1); int32_t offset_x = (int32_t)lua_tointeger(L, -1) ; lua_pop(L, 1);

    const char *modifier;
    const char *unit;
    CGEventFlags flags = (CGEventFlags)0;
    CGScrollEventUnit type;

    luaL_checktype(L, 2, LUA_TTABLE);
    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        modifier = lua_tostring(L, -1);
        if (!modifier) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"hs.eventtap.event.newScrollEvent() unexpected entry in modifiers table: %d", lua_type(L, -1)]];
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

    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(eventSource, type, 2, offset_x, offset_y);
    CGEventSetFlags(scrollEvent, flags);
    new_eventtap_event(L, scrollEvent);
    CFRelease(scrollEvent);

    return 1;
}

static int eventtap_event_newMouseEvent(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    CGEventType type = (CGEventType)(luaL_checkinteger(L, 1));
    CGPoint point = hs_topoint(L, 2);
    const char* buttonString = luaL_checkstring(L, 3);

    CGEventFlags flags = (CGEventFlags)0;
    const char *modifier;

    CGMouseButton button = kCGMouseButtonLeft;

    if (strcmp(buttonString, "right") == 0)
        button = kCGMouseButtonRight;
    else if (strcmp(buttonString, "other") == 0)
        button = kCGMouseButtonCenter;

    if (!lua_isnoneornil(L, 4) && (lua_type(L, 4) == LUA_TTABLE)) {
        lua_pushnil(L);
        while (lua_next(L, 4) != 0) {
            modifier = lua_tostring(L, -2);
            if (!modifier) {
                [skin logBreadcrumb:[NSString stringWithFormat:@"hs.eventtap.event.newMouseEvent() unexpected entry in modifiers table: %d", lua_type(L, -1)]];
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

    CGEventRef event = CGEventCreateMouseEvent(eventSource, type, point, button);
    CGEventSetFlags(event, flags);
    new_eventtap_event(L, event);
    CFRelease(event);

    return 1;
}

/// hs.eventtap.event:systemKey() -> table
/// Method
/// Returns the special key and its state if the event is a NSSystemDefined event of subtype AUX_CONTROL_BUTTONS (special-key pressed)
///
/// Parameters:
///  * None
///
/// Returns:
///  * If the event is a NSSystemDefined event of subtype AUX_CONTROL_BUTTONS, a table with the following keys defined:
///    * key    -- a string containing one of the following labels indicating the key involved:
///      * SOUND_UP
///      * SOUND_DOWN
///      * MUTE
///      * BRIGHTNESS_UP
///      * BRIGHTNESS_DOWN
///      * CONTRAST_UP
///      * CONTRAST_DOWN
///      * POWER
///      * LAUNCH_PANEL
///      * VIDMIRROR
///      * PLAY
///      * EJECT
///      * NEXT
///      * PREVIOUS
///      * FAST
///      * REWIND
///      * ILLUMINATION_UP
///      * ILLUMINATION_DOWN
///      * ILLUMINATION_TOGGLE
///      * CAPS_LOCK
///      * HELP
///      * NUM_LOCK
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
    if ((type == NSEventTypeAppKitDefined) || (type == NSEventTypeSystemDefined) || (type == NSEventTypeApplicationDefined) || (type == NSEventTypePeriodic)) {
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
///   * NSEventTypePressure     --  An NSEvent type representing a change in pressure on a pressure-sensitive device. Requires a 64-bit processor.
///
/// Notes:
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.eventtap.event.types`.
///  * In previous versions of Hammerspoon, type labels were defined with the labels in all lowercase.  This practice is deprecated, but an __index metamethod allows the lowercase labels to still be used; however a warning will be printed to the Hammerspoon console.  At some point, this may go away, so please update your code to follow the new format.

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

    // The middleMouse* mappings here are for backwards compatibility (likely for nearly zero users)
    lua_pushinteger(L, kCGEventOtherMouseDown);     lua_setfield(L, -2, "middleMouseDown");
    lua_pushinteger(L, kCGEventOtherMouseUp);       lua_setfield(L, -2, "middleMouseUp");
    lua_pushinteger(L, kCGEventOtherMouseDragged);  lua_setfield(L, -2, "middleMouseDragged");

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
    lua_pushinteger(L, kCGEventOtherMouseDown);     lua_setfield(L, -2, "otherMouseDown");
    lua_pushstring(L, "otherMouseDown") ;           lua_rawseti(L, -2, kCGEventOtherMouseDown);
    lua_pushinteger(L, kCGEventOtherMouseUp);       lua_setfield(L, -2, "otherMouseUp");
    lua_pushstring(L, "otherMouseUp") ;             lua_rawseti(L, -2, kCGEventOtherMouseUp);
    lua_pushinteger(L, kCGEventOtherMouseDragged);  lua_setfield(L, -2, "otherMouseDragged");
    lua_pushstring(L, "otherMouseDragged") ;        lua_rawseti(L, -2, kCGEventOtherMouseDragged);
    lua_pushinteger(L, kCGEventNull);               lua_setfield(L, -2, "nullEvent");
    lua_pushstring(L, "nullEvent") ;                lua_rawseti(L, -2, kCGEventNull);
    lua_pushinteger(L, NSEventTypeMouseEntered);             lua_setfield(L, -2, "NSMouseEntered");
    lua_pushstring(L, "NSMouseEntered") ;           lua_rawseti(L, -2, NSEventTypeMouseEntered);
    lua_pushinteger(L, NSEventTypeMouseExited);              lua_setfield(L, -2, "NSMouseExited");
    lua_pushstring(L, "NSMouseExited") ;            lua_rawseti(L, -2, NSEventTypeMouseExited);
    lua_pushinteger(L, NSEventTypeAppKitDefined);            lua_setfield(L, -2, "NSAppKitDefined");
    lua_pushstring(L, "NSAppKitDefined") ;          lua_rawseti(L, -2, NSEventTypeAppKitDefined);
    lua_pushinteger(L, NSEventTypeSystemDefined);            lua_setfield(L, -2, "NSSystemDefined");
    lua_pushstring(L, "NSSystemDefined") ;          lua_rawseti(L, -2, NSEventTypeSystemDefined);
    lua_pushinteger(L, NSEventTypeApplicationDefined);       lua_setfield(L, -2, "NSApplicationDefined");
    lua_pushstring(L, "NSApplicationDefined") ;     lua_rawseti(L, -2, NSEventTypeApplicationDefined);
    lua_pushinteger(L, NSEventTypePeriodic);                 lua_setfield(L, -2, "NSPeriodic");
    lua_pushstring(L, "NSPeriodic") ;               lua_rawseti(L, -2, NSEventTypePeriodic);
    lua_pushinteger(L, NSEventTypeCursorUpdate);             lua_setfield(L, -2, "NSCursorUpdate");
    lua_pushstring(L, "NSCursorUpdate") ;           lua_rawseti(L, -2, NSEventTypeCursorUpdate);
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
    lua_pushinteger(L, NSEventTypePressure);        lua_setfield(L, -2, "NSEventTypePressure");
    lua_pushstring(L, "NSEventTypePressure") ;      lua_rawseti(L, -2, NSEventTypePressure);

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

/// hs.eventtap.event.rawFlagMasks[]
/// Constant
/// A table containing key-value pairs describing the raw modifier flags which can be manipulated with [hs.eventtap.event:rawFlags](#rawFlags).
///
/// This table and [hs.eventtap.event:rawFlags](#rawFlags) are both considered experimental as the full meanings behind some of these flags and what combinations are likely to be observed is still being determined.  It is possible that some of these key names may change in the future.
///
/// At present, what is known about the flags is presented here:
///  * alternate                 - Corresponds to the left (or only) alt key on the keyboard
///  * command                   - Corresponds to the left (or only) cmd key on the keyboard
///  * control                   - Corresponds to the left (or only) ctrl key on the keyboard
///  * shift                     - Corresponds to the left (or only) shift key on the keyboard
///  * numericPad                - Indicates that the key corresponds to one defined as belonging to the numeric keypad, if present
///  * secondaryFn               - Indicates the fn key found on most modern Macintosh laptops.  May also be observed with function and other special keys (arrows, page-up/down, etc.)
///  * deviceRightAlternate      - Corresponds to the right alt key on the keyboard (if present)
///  * deviceRightCommand        - Corresponds to the right cmd key on the keyboard (if present)
///  * deviceRightControl        - Corresponds to the right ctrl key on the keyboard (if present)
///  * deviceRightShift          - Corresponds to the right alt key on the keyboard (if present)
///  * nonCoalesced              - Indicates that multiple mouse movements are not being coalesced into one event if delivery of the event has been delayed
///
/// The following are also defined in IOLLEvent.h, but the description is a guess since I have not observed them myself
///  * alphaShift                - related to the caps-lock in some way?
///  * alphaShiftStateless       - related to the caps-lock in some way?
///  * deviceAlphaShiftStateless - related to the caps-lock in some way?
///  * deviceLeftAlternate       -
///  * deviceLeftCommand         -
///  * deviceLeftControl         -
///  * deviceLeftShift           -
///  * help                      - related to a modifier found on old NeXT keyboards but not on modern keyboards?
///
/// It has also been observed that synthetic events that have been posted also have the bit represented by 0x20000000 set.  This constant does not appear in IOLLEvent.h or CGEventTypes.h, which defines most of the constants used in this module, so it is not included within this table at present, but may be added in the future if any corroborating information can be found.
///
/// For what it may be worth, I have found it most useful to filter out `nonCoalesced` and 0x20000000 before examining the flags in my own code, like this: `hs.eventtap.event:rawFlags() & 0xdffffeff` where 0xdffffeff = ~(0x20000000 | 0x100) (limited to the 32 bits since that is what is returned by `rawFlags`).
///
/// Any documentation or references that can be found which can further expand on the information here is welcome -- Please submit any information you may have through the Hammerspoon GitHub site or Google group.
static int push_flagMasks(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NX_ALPHASHIFTMASK) ;                   lua_setfield(L, -2, "alphaShift") ;
    lua_pushinteger(L, NX_SHIFTMASK) ;                        lua_setfield(L, -2, "shift") ;
    lua_pushinteger(L, NX_CONTROLMASK) ;                      lua_setfield(L, -2, "control") ;
    lua_pushinteger(L, NX_ALTERNATEMASK) ;                    lua_setfield(L, -2, "alternate") ;
    lua_pushinteger(L, NX_COMMANDMASK) ;                      lua_setfield(L, -2, "command") ;
    lua_pushinteger(L, NX_NUMERICPADMASK) ;                   lua_setfield(L, -2, "numericPad") ;
    lua_pushinteger(L, NX_HELPMASK) ;                         lua_setfield(L, -2, "help") ;
    lua_pushinteger(L, NX_SECONDARYFNMASK) ;                  lua_setfield(L, -2, "secondaryFn") ;
    lua_pushinteger(L, NX_DEVICELCTLKEYMASK) ;                lua_setfield(L, -2, "deviceLeftControl") ;
    lua_pushinteger(L, NX_DEVICERCTLKEYMASK) ;                lua_setfield(L, -2, "deviceRightControl") ;
    lua_pushinteger(L, NX_DEVICELSHIFTKEYMASK) ;              lua_setfield(L, -2, "deviceLeftShift") ;
    lua_pushinteger(L, NX_DEVICERSHIFTKEYMASK) ;              lua_setfield(L, -2, "deviceRightShift") ;
    lua_pushinteger(L, NX_DEVICELCMDKEYMASK) ;                lua_setfield(L, -2, "deviceLeftCommand") ;
    lua_pushinteger(L, NX_DEVICERCMDKEYMASK) ;                lua_setfield(L, -2, "deviceRightCommand") ;
    lua_pushinteger(L, NX_DEVICELALTKEYMASK) ;                lua_setfield(L, -2, "deviceLeftAlternate") ;
    lua_pushinteger(L, NX_DEVICERALTKEYMASK) ;                lua_setfield(L, -2, "deviceRightAlternate") ;
    lua_pushinteger(L, NX_ALPHASHIFT_STATELESS_MASK) ;        lua_setfield(L, -2, "alphaShiftStateless") ;
    lua_pushinteger(L, NX_DEVICE_ALPHASHIFT_STATELESS_MASK) ; lua_setfield(L, -2, "deviceAlphaShiftStateless") ;
    lua_pushinteger(L, NX_NONCOALSESCEDMASK) ;                lua_setfield(L, -2, "nonCoalesced") ;
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventType eventType = CGEventGetType(event) ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: Event type: %d (%p)", EVENT_USERDATA_TAG, eventType, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int meta_gc(lua_State* __unused L) {
    if (eventSource) {
        CFRelease(eventSource);
        eventSource = NULL;
    }
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg eventtapevent_metalib[] = {
    {"asData",          eventtap_event_asData},
    {"location",        eventtap_event_location},
    {"rawFlags",        eventtap_event_rawFlags},
    {"timestamp",       eventtap_event_timestamp},
    {"setType",         eventtap_event_setType},
    {"copy",            eventtap_event_copy},
    {"getFlags",        eventtap_event_getFlags},
    {"setFlags",        eventtap_event_setFlags},
    {"getKeyCode",      eventtap_event_getKeyCode},
    {"setKeyCode",      eventtap_event_setKeyCode},
    {"getUnicodeString", eventtap_event_getUnicodeString},
    {"setUnicodeString", eventtap_event_setUnicodeString},
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
    {"newEvent",          eventtap_event_newEvent},
    {"newEventFromData",  eventtap_event_newEventFromData},
    {"newKeyEvent",       eventtap_event_newKeyEvent},
    {"newSystemKeyEvent", eventtap_event_newSystemKeyEvent},
    {"_newMouseEvent",    eventtap_event_newMouseEvent},
    {"newScrollEvent",    eventtap_event_newScrollWheelEvent},
    {NULL,                NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

static CGEventFlags flagsFromTable(lua_State* L, int arg) {
    luaL_checktype(L, arg, LUA_TTABLE);

    CGEventFlags flags = 0;

    lua_getfield(L, arg, "cmd");
    if (lua_toboolean(L, -1)) {
        flags |= kCGEventFlagMaskCommand;
    }

    lua_getfield(L, arg, "alt");
    if (lua_toboolean(L, -1)) {
        flags |= kCGEventFlagMaskAlternate;
    }

    lua_getfield(L, arg, "ctrl");
    if (lua_toboolean(L, -1)) {
        flags |= kCGEventFlagMaskControl;
    }

    lua_getfield(L, arg, "shift");
    if (lua_toboolean(L, -1)) {
        flags |= kCGEventFlagMaskShift;
    }

    lua_getfield(L, arg, "fn");
    if (lua_toboolean(L, -1)) {
        flags |= kCGEventFlagMaskSecondaryFn;
    }

    return flags;
}

static CGEventFlags flagsFromArray(lua_State* L, int arg) {
    luaL_checktype(L, arg, LUA_TTABLE);

    CGEventFlags flags = 0;
    const char *modifier;
    lua_pushnil(L);
    while (lua_next(L, arg) != 0) {
        modifier = lua_tostring(L, -1);
        if (!modifier) {
            LuaSkin *skin = [LuaSkin shared];
            [skin logBreadcrumb:[NSString stringWithFormat:@"hs.eventtap.event.flags: unexpected entry in modifiers table: %d", lua_type(L, -1)]];
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

    return flags;
}

static int flags_contain(lua_State* L) {
    CGEventFlags eventFlags = flagsFromTable(L, 1);
    CGEventFlags flags = flagsFromArray(L, 2);

    lua_pushboolean(L, (eventFlags & flags) == flags);

    return 1;
}

static int flags_containExactly(lua_State* L) {
    CGEventFlags eventFlags = flagsFromTable(L, 1);
    CGEventFlags flags = flagsFromArray(L, 2);

    lua_pushboolean(L, eventFlags == flags);

    return 1;
}

int luaopen_hs_eventtap_event(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibraryWithObject:EVENT_USERDATA_TAG functions:eventtapeventlib metaFunctions:meta_gcLib objectFunctions:eventtapevent_metalib];

    pushtypestable(L);
    lua_setfield(L, -2, "types");

    pushpropertiestable(L);
    lua_setfield(L, -2, "properties");

    push_flagMasks(L) ; lua_setfield(L, -2, "rawFlagMasks") ;

    eventSource = nil;

    luaL_newmetatable(L, FLAGS_TAG);

    lua_newtable(L);
    lua_pushcfunction(L, flags_contain);
    lua_setfield(L, -2, "contain");
    lua_pushcfunction(L, flags_containExactly);
    lua_setfield(L, -2, "containExactly");

    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);

    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
//     eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    return 1;
}
