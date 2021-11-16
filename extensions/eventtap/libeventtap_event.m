#import <Foundation/Foundation.h>
#import "TouchEvents.h"
#import "eventtap_event.h"
#import "HSuicore.h"
#include "IOHIDEventTypes.h"
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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

/// hs.eventtap.event.newGesture(gestureType[, gestureValue]) -> event
/// Constructor
/// Creates an gesture event.
///
/// Parameters:
///  * gestureType - the type of gesture you want to create as a string (see notes below).
///  * [gestureValue] - an optional value for the specific gesture (i.e. magnification amount or rotation in degrees).
///
/// Returns:
///  * a new `hs.eventtap.event` object or `nil` if the `gestureType` is not valid.
///
/// Notes:
///  * Valid gestureType values are:
///   * `beginMagnify` - Starts a magnification event with an optional magnification value as a number (defaults to 0). The exact unit of measurement is unknown.
///   * `endMagnify` - Starts a magnification event with an optional magnification value as a number (defaults to 0.1). The exact unit of measurement is unknown.
///   * `beginRotate` - Starts a rotation event with an rotation value in degrees (i.e. a value of 45 turns it 45 degrees left - defaults to 0).
///   * `endRotate` - Starts a rotation event with an rotation value in degrees (i.e. a value of 45 turns it 45 degrees left - defaults to 45).
///   * `beginSwipeLeft` - Begin a swipe left.
///   * `endSwipeLeft` - End a swipe left.
///   * `beginSwipeRight` - Begin a swipe right.
///   * `endSwipeRight` - End a swipe right.
///   * `beginSwipeUp` - Begin a swipe up.
///   * `endSwipeUp` - End a swipe up.
///   * `beginSwipeDown` - Begin a swipe down.
///   * `endSwipeDown` - End a swipe down.
///
///  * Example Usage:
///   ```lua
///   hs.hotkey.bind({"cmd", "alt", "ctrl"}, "1", function()
///       print("Magnify slightly")
///       a = require("hs.eventtap.event").newGesture("beginMagnify", 0)
///       b = require("hs.eventtap.event").newGesture("endMagnify", 0.1)
///       a:post()
///       b:post()
///   end)
///   hs.hotkey.bind({"cmd", "alt", "ctrl"}, "2", function()
///       print("Swipe down")
///       a = require("hs.eventtap.event").newGesture("beginSwipeDown")
///       b = require("hs.eventtap.event").newGesture("endSwipeDown")
///       a:post()
///       b:post()
///   end)
///   hs.hotkey.bind({"cmd", "alt", "ctrl"}, "3", function()
///       print("Rotate 45 degrees left")
///       a = require("hs.eventtap.event").newGesture("beginRotate", 0)
///       b = require("hs.eventtap.event").newGesture("endRotate", 45)
///       a:post()
///       b:post()
///   end)
///   hs.hotkey.bind({"cmd", "alt", "ctrl"}, "4", function()
///       print("Rotate 45 degrees right")
///       a = require("hs.eventtap.event").newGesture("beginRotate", 0)
///       b = require("hs.eventtap.event").newGesture("endRotate", -45)
///       a:post()
///       b:post()
///   end)
///   ```
static int eventtap_event_newGesture(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    
    NSString *gesture = [skin toNSObjectAtIndex:1];
    NSDictionary* gestureDict;
    
    if ([gesture isEqualToString:@"beginSwipeLeft"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"endSwipeLeft"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kTLInfoSwipeLeft), kTLInfoKeySwipeDirection,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"beginSwipeRight"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"endSwipeRight"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kTLInfoSwipeRight), kTLInfoKeySwipeDirection,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"beginSwipeUp"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"endSwipeUp"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kTLInfoSwipeUp), kTLInfoKeySwipeDirection,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"beginSwipeDown"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"endSwipeDown"]) {
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                       @(kTLInfoSwipeDown), kTLInfoKeySwipeDirection,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       nil];
    }
    else if ([gesture isEqualToString:@"beginMagnify"]) {
        NSNumber *magnificationValue = [skin toNSObjectAtIndex:2];
        double magnification = 0.0;
        if (magnificationValue) {
            magnification = [magnificationValue floatValue];
        }
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeMagnify), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       @(magnification), kTLInfoKeyMagnification,
                       nil];
    }
    else if ([gesture isEqualToString:@"endMagnify"]) {
        NSNumber *magnificationValue = [skin toNSObjectAtIndex:2];
        double magnification = 0.1;
        if (magnificationValue) {
            magnification = [magnificationValue floatValue];
        }
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeMagnify), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       @(magnification), kTLInfoKeyMagnification,
                       nil];
    }
    else if ([gesture isEqualToString:@"beginRotate"]) {
        NSNumber *rotatationValue = [skin toNSObjectAtIndex:2];
        double rotatation = 0.0;
        if (rotatationValue) {
            rotatation = [rotatationValue floatValue];
        }
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeRotate), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseBegan), kTLInfoKeyGesturePhase,
                       @(rotatation), kTLInfoKeyRotation,
                       nil];
    }
    else if ([gesture isEqualToString:@"endRotate"]) {
        NSNumber *rotatationValue = [skin toNSObjectAtIndex:2];
        double rotatation = 45;
        if (rotatationValue) {
            rotatation = [rotatationValue floatValue];
        }
        gestureDict = [NSDictionary dictionaryWithObjectsAndKeys:
                       @(kTLInfoSubtypeRotate), kTLInfoKeyGestureSubtype,
                       @(kIOHIDEventPhaseEnded), kTLInfoKeyGesturePhase,
                       @(rotatation), kTLInfoKeyRotation,
                       nil];
    }
    else
    {
        [LuaSkin logError:@"hs.eventtap.event.newGesture() - Invalid gesture identifier supplied."];
        lua_pushnil(L) ;
        return 1;
    }
    
    CGEventRef event = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(gestureDict), (__bridge CFArrayRef)@[]);
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
///  * You can recreate the event for later posting with [hs.eventtap.event.newEventFromData](#newEventFromData)
static int eventtap_event_asData(lua_State* L) {
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CFDataRef data = CGEventCreateData(NULL, event) ;
    if (data) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:(__bridge_transfer NSData *)data] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    CGEventSetType(event, (CGEventType)(lua_tointeger(L, 2))) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)(CGEventGetFlags(event))) ;
    } else {
        CGEventSetFlags(event, (CGEventFlags)(lua_tointeger(L, 2))) ;
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
            lua_pushinteger(L, (lua_Integer)(CGEventGetFlags(event)));                        lua_setfield(L, -2, "flags") ;
            lua_pushinteger(L, cgType);                                                       lua_setfield(L, -2, "type") ;
        lua_setfield(L, -2, "CGEventData") ;

        lua_newtable(L) ;
        if ((cgType != kCGEventTapDisabledByTimeout) && (cgType != kCGEventTapDisabledByUserInput)) {
            NSEvent*    sysEvent = [NSEvent eventWithCGEvent:event];
            NSEventType type     = [sysEvent type] ;
            lua_pushinteger(L, (lua_Integer)([sysEvent modifierFlags]));                      lua_setfield(L, -2, "modifierFlags") ;
            lua_pushinteger(L, (lua_Integer)type);                                            lua_setfield(L, -2, "type") ;
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
    BOOL        clean    = lua_isnone(L, 2) ? NO : (BOOL)(lua_toboolean(L, 2)) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    free(buffer);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TSTRING, LS_TBREAK];

    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    NSString *theString = [skin toNSObjectAtIndex:2];
    NSUInteger stringLen = [theString lengthOfBytesUsingEncoding:NSUnicodeStringEncoding];
    NSUInteger usedLen = 0;

    UniChar *buffer = malloc(stringLen);
    BOOL result = [theString getBytes:(void*)buffer
                            maxLength:stringLen
                           usedLength:&usedLen
                             encoding:NSUnicodeStringEncoding
                              options:NSStringEncodingConversionAllowLossy
                                range:NSMakeRange(0, theString.length)
                       remainingRange:NULL];
    if (!result) {
        [skin logWarn:[NSString stringWithFormat:@"hs.eventtap.event:setUnicodeString() failed to convert: %@", theString]];
    }

    CGEventSetFlags(event, (CGEventFlags)0);
    CGEventKeyboardSetUnicodeString(event, theString.length, buffer);

    free(buffer);

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
static int eventtap_event_post(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK];

    CGEventRef event = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);

    if (luaL_testudata(L, 2, APPLICATION_USERDATA_TAG)) {
        HSapplication *appObj = [skin toNSObjectAtIndex:2] ;
        pid_t pid = appObj.pid;

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
        // NOTE: @latenitefilms has tried to use `kCGHIDEventTap` as discussed in #2104
        //       however, it doesn't seem to be any different than `kCGSessionEventTap`
        CGEventPost(kCGSessionEventTap, event);
    }

    usleep(1000);

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.eventtap.event:getType([nsSpecificType]) -> number
/// Method
/// Gets the type of the event
///
/// Parameters:
///  * `nsSpecificType` - an optional boolean, default false, specifying whether or not a more specific Cocoa NSEvent type should be returned, if available.
///
/// Returns:
///  * A number containing the type of the event, taken from `hs.eventtap.event.types`
///
/// Notes:
///  * some newer events are grouped into a more generic event for watching purposes and the specific event type is determined by examining the event through the Cocoa API. The primary example of this is for gestures on a trackpad or touches of the touchbar, as all of these are grouped under the `hs.eventtap.event.types.gesture` event. For example:
///
///      ```lua
///      myTap = hs.eventtap.new( { hs.eventtap.event.types.gesture }, function(e)
///          local gestureType = e:getType(true)
///          if gestureType == hs.eventtap.types.directTouch then
///              -- they touched the touch bar
///          elseif gestureType == hs.eventtap.types.gesture then
///              -- they are touching the trackpad, but it's not for a gesture
///          elseif gestureType == hs.eventtap.types.magnify then
///              -- they're preforming a magnify gesture
///          -- etc -- see hs.eventtap.event.types for more
///          endif
///      end
///      ```
static int eventtap_event_getType(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    CGEventRef event   = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG);
    BOOL       nsEvent = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (nsEvent) {
        NSEvent *cocoaEvent = [NSEvent eventWithCGEvent:event] ;
        NSUInteger eventType = [cocoaEvent type] ;
        lua_pushinteger(L, (lua_Integer)(eventType)) ;
    } else {
        lua_pushinteger(L, CGEventGetType(event));
    }
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
    LuaSkin      *skin = [LuaSkin sharedWithState:L];
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
    BOOL         isDown  = (BOOL)(lua_toboolean(L, keyCodePos + 1)) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN, LS_TBREAK];

    NSString *keyName = [skin toNSObjectAtIndex:1];
    BOOL isDown = (BOOL)(lua_toboolean(L, 2));
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    else if (strcmp(buttonString, "none") == 0)
        button = 0;

    if (!lua_isnoneornil(L, 4) && (lua_type(L, 4) == LUA_TTABLE)) {
        lua_pushnil(L);
        while (lua_next(L, 4) != 0) {
            modifier = lua_tostring(L, -1);
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

/// hs.eventtap.event:getTouches() -> table | nil
/// Method
/// Returns a table of details containing information about touches on the trackpad associated with this event if the event is of the type `hs.eventtap.event.types.gesture`.
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the event is of the type gesture, returns a table; otherwise returns nil.
///
/// Notes:
///  * if the event is of the type gesture, the table will contain one or more tables in an array. Each member table of the array will have the following key-value pairs:
///    * `device`                     - a string containing a unique identifier for the device on which the touch occurred. At present we do not have a way to match the identifier to a specific touch device, but if multiple such devices are attached to the computer, this value will differ between them.
///    * `deviceSize`                 - a size table containing keys `h` and `w` for the height and width of the touch device in points (72 PPI resolution).
///    * `force`                      - a number representing a measure of the force of the touch when the device is a forcetouch trackpad. This will be 0.0 for non-forcetouch trackpads and the touchbar.
///    * `identity`                   - a string specifying a unique identifier for the touch guaranteed to be unique for the life of the touch. This identifier may be used to track the movement of a specific touch (e.g. finger) as it moves through successive callbacks.
///    * `phase`                      - a string specifying the current phase the touch is considered to be in. The possible values are: "began", "moved", "stationary", "ended", or "cancelled".
///    * `resting`                    - Resting touches occur when a user simply rests their thumb on the trackpad device. Requires that the foreground window has views accepting resting touches.
///    * `timestamp`                  - a number representing the time the touch was detected. This number corresponds to seconds since the last system boot, not including time the computer has been asleep. Comparable to `hs.timer.absoluteTime() / 1000000000`.
///    * `touching`                   - a boolean specifying whether or not the touch phase is "began", "moved", or "stationary" (i.e. is *not* "ended" or "cancelled").
///    * `type`                       - a string specifying the type of touch. A "direct" touch will indicate a touchbar, while a trackpad will report "indirect".
///
///    * The following fields will be present when the touch is from a touchpad (`type` == "indirect")`
///      * `normalizedPosition`         - a point table specifying the `x` and `y` coordinates of the touch, each normalized to be a value between 0.0 and 1.0. `{ x = 0, y = 0 }` is the lower left corner of the touch device.
///      * `previousNormalizedPosition` - a point table specifying the `x` and `y` coordinates of the previous position for this specific touch (as linked by `identity`) normalezed to values between 0.0 and 1.0.
///
///    * The following fields will be present when the touch is from the touchbar (`type` == "direct")`
///      * `location`                   - a point table specifying the `x` and `y` coordinates of the touch location within the touchbar.
///      * `previousLocation`           - a point table specifying the `x` and `y` coordinates of the previous location for this specific touch (as linked by `identity`) within the touchbar.
static int eventtap_event_getTouches(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TBREAK] ;
    CGEventRef  event      = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG) ;
    NSEvent     *asNSEvent = [NSEvent eventWithCGEvent:event] ;

    if (CGEventGetType(event) == NSEventTypeGesture) {
        NSSet *touches = asNSEvent.allTouches ;
        [skin pushNSObject:touches] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.eventtap.event:getTouchDetails() -> table | nil
/// Method
/// Returns a table contining more information about some touch related events.
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the event is a touch event (i.e. is an event of type `hs.eventtap.event.types.gesture`), then this method returns a table with zero or more of the following key-value pairs:
///    * if the gesture is for a pressure event:
///      * `pressure`         - a number between 0.0 and 1.0 inclusive indicating the relative amount of pressure applied by the touch; trackpads which are not pressure sensitive will only report the discrete values of 0.0 and 1.0.
///      * `stage`            - an integer between 0 and 2 specifying the stage. 0 represents a touch transitioning to a state too light to be considered a touch, usually at the end of a click; 1 represents a touch with enough pressure to be considered a mouseDown event; 2 represents additional pressure, usually what would trigger a "deep" or "force" touch.
///      * `stageTransition`  - a number between 0.0 and 1.0. As the pressure increases and transition between stages begins, this will rise from 0.0 to 1.0; as the pressure decreases and a transition between stages begins, this will fall from 0.0 to -1.0. When the pressure is solidly within a specific stage, this will remain 0.0.
///      * `pressureBehavior` - a string specifying the effect or purpose of the pressure. Note that the exact meaning (in terms of haptic feedback or action being performed) of each label is target application or ui element specific. Valid values for this key are:
///        * "unknown", "default", "click", "generic", "accelerator", "deepClick", "deepDrag"
///    * if the gesture is for a magnification event:
///      * `magnification` - a number specifying the change in magnification that should be added to the current scaling of an item to achieve the new scale factor.
///    * if the gesture is for a rotation event:
///      * `rotation` - a number specifying in degrees the change in rotation that should be added as specified by this event. Clockwise rotation is indicated by a negative number while counter-clockwise rotation will be positive.
static int eventtap_event_getTouchDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, EVENT_USERDATA_TAG, LS_TBREAK] ;
    CGEventRef  event      = *(CGEventRef*)luaL_checkudata(L, 1, EVENT_USERDATA_TAG) ;
    NSEvent     *asNSEvent = [NSEvent eventWithCGEvent:event] ;
    NSEventType type       = asNSEvent.type ;

    if (CGEventGetType(event) == NSEventTypeGesture) {
        lua_newtable(L) ;

        if (type == NSEventTypePressure) {
            lua_pushnumber(L, (lua_Number)asNSEvent.pressure) ; lua_setfield(L, -2, "pressure") ;
            lua_pushinteger(L, asNSEvent.stage) ;               lua_setfield(L, -2, "stage") ;
            lua_pushnumber(L, asNSEvent.stageTransition) ;      lua_setfield(L, -2, "stageTransition") ;
            NSPressureBehavior pressureBehavior = asNSEvent.pressureBehavior ;
            switch(pressureBehavior) {
                case NSPressureBehaviorUnknown:            lua_pushstring(L, "unknown") ; break ;
                case NSPressureBehaviorPrimaryDefault:     lua_pushstring(L, "default") ; break ;
                case NSPressureBehaviorPrimaryClick:       lua_pushstring(L, "click") ; break ;
                case NSPressureBehaviorPrimaryGeneric:     lua_pushstring(L, "generic") ; break ;
                case NSPressureBehaviorPrimaryAccelerator: lua_pushstring(L, "accelerator") ; break ;
                case NSPressureBehaviorPrimaryDeepClick:   lua_pushstring(L, "deepClick") ; break ;
                case NSPressureBehaviorPrimaryDeepDrag:    lua_pushstring(L, "deepDrag") ; break ;
                default:
                    lua_pushfstring(L, "** unrecognized pressureBehavior: %d", pressureBehavior) ;
            }
            lua_setfield(L, -2, "pressureBehavior") ;
        }

        if (type == NSEventTypeMagnify) {
            lua_pushnumber(L, asNSEvent.magnification) ;        lua_setfield(L, -2, "magnification") ;
        }

        if (type == NSEventTypeRotate) {
            lua_pushnumber(L, (lua_Number)asNSEvent.rotation) ; lua_setfield(L, -2, "rotation") ;
        }

    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.eventtap.event.types -> table
/// Constant
/// A table containing event types to be used with `hs.eventtap.new(...)` and returned by `hs.eventtap.event:type()`.  The table supports forward (label to number) and reverse (number to label) lookups to increase its flexibility.
///
/// The constants defined in this table are as follows:
///
///   * nullEvent         --  Specifies a null event. (thus far unobserved; please submit an issue if you can provide more information)
///   * leftMouseDown     --  Specifies a mouse down event with the left button.
///   * leftMouseUp       --  Specifies a mouse up event with the left button.
///   * rightMouseDown    --  Specifies a mouse down event with the right button.
///   * rightMouseUp      --  Specifies a mouse up event with the right button.
///   * mouseMoved        --  Specifies a mouse moved event.
///   * leftMouseDragged  --  Specifies a mouse drag event with the left button down.
///   * rightMouseDragged --  Specifies a mouse drag event with the right button down.
///   * keyDown           --  Specifies a key down event.
///   * keyUp             --  Specifies a key up event.
///   * flagsChanged      --  Specifies a key changed event for a modifier or status key.
///   * scrollWheel       --  Specifies a scroll wheel moved event.
///   * tabletPointer     --  Specifies a tablet pointer event.
///   * tabletProximity   --  Specifies a tablet proximity event.
///   * otherMouseDown    --  Specifies a mouse down event with one of buttons 2-31.
///   * otherMouseUp      --  Specifies a mouse up event with one of buttons 2-31.
///   * otherMouseDragged --  Specifies a mouse drag event with one of buttons 2-31 down.
///
///  The following events, also included in the lookup table, are provided through NSEvent and currently may require the use of `hs.eventtap.event:getRawEventData()` to retrieve supporting information.  Target specific methods may be added as the usability of these events is explored.
///
///   * gesture               --  An event that represents a touch event on a touch sensitive trackpad or touchbar. See below.
///   * systemDefined         --  An event indicating some system event has occurred. For us, it is primarily used to detect special system keys (Volume Up/Down, etc.). See [hs.eventtap.event:systemKey](#systemKey) and [hs.eventtap.event.newSystemKeyEvent](#newSystemKeyEvent).
///
///   * appKitDefined         --  (thus far unobserved; please submit an issue if you can provide more information)
///   * applicationDefined    --  (thus far unobserved; please submit an issue if you can provide more information)
///   * cursorUpdate          --  (thus far unobserved; please submit an issue if you can provide more information)
///   * mouseEntered          --  (thus far unobserved; please submit an issue if you can provide more information)
///   * mouseExited           --  (thus far unobserved; please submit an issue if you can provide more information)
///   * periodic              --  (thus far unobserved; please submit an issue if you can provide more information)
///   * quickLook             --  (thus far unobserved; please submit an issue if you can provide more information)
///
///  To detect the following events, setup your eventtap to capture the `hs.eventtap.event.type.gesture` type and examine the value of [hs.eventtap.event:getType(true)](#getType).
///   * gesture      --  The user touched a portion of a touchpad
///   * directTouch  --  The user touched a portion of the touch bar.
///   * changeMode   --  A double-tap on the side of an Apple Pencil paired with an iPad that is being used as an external monitor via Sidecar.
///   * magnify      --  The user performed a pinch open or pinch close gesture.
///   * pressure     --  The pressure on a forcetouch trackpad has changed..
///   * rotate       --  The user performed a rotation gesture.
///   * smartMagnify --  The user performed a smart zoom gesture (2-finger double tap on trackpads).
///   * swipe        --  The user performed a swipe gesture. (thus far unobserved; please submit an issue if you can provide more information)

static void pushtypestable(lua_State* L) {
    lua_newtable(L);
    lua_pushinteger(L, kCGEventNull);                  lua_setfield(L, -2, "nullEvent");
    lua_pushinteger(L, kCGEventLeftMouseDown);         lua_setfield(L, -2, "leftMouseDown");
    lua_pushinteger(L, kCGEventLeftMouseUp);           lua_setfield(L, -2, "leftMouseUp");
    lua_pushinteger(L, kCGEventLeftMouseDragged);      lua_setfield(L, -2, "leftMouseDragged");
    lua_pushinteger(L, kCGEventRightMouseDown);        lua_setfield(L, -2, "rightMouseDown");
    lua_pushinteger(L, kCGEventRightMouseUp);          lua_setfield(L, -2, "rightMouseUp");
    lua_pushinteger(L, kCGEventRightMouseDragged);     lua_setfield(L, -2, "rightMouseDragged");
    lua_pushinteger(L, kCGEventOtherMouseDown);        lua_setfield(L, -2, "otherMouseDown");
    lua_pushinteger(L, kCGEventOtherMouseUp);          lua_setfield(L, -2, "otherMouseUp");
    lua_pushinteger(L, kCGEventOtherMouseDragged);     lua_setfield(L, -2, "otherMouseDragged");
    lua_pushinteger(L, kCGEventMouseMoved);            lua_setfield(L, -2, "mouseMoved");
    lua_pushinteger(L, kCGEventKeyDown);               lua_setfield(L, -2, "keyDown");
    lua_pushinteger(L, kCGEventKeyUp);                 lua_setfield(L, -2, "keyUp");
    lua_pushinteger(L, kCGEventFlagsChanged);          lua_setfield(L, -2, "flagsChanged");
    lua_pushinteger(L, kCGEventScrollWheel);           lua_setfield(L, -2, "scrollWheel");
    lua_pushinteger(L, kCGEventTabletPointer);         lua_setfield(L, -2, "tabletPointer");
    lua_pushinteger(L, kCGEventTabletProximity);       lua_setfield(L, -2, "tabletProximity");

// // The middleMouse* mappings here are for backwards compatibility (likely for nearly zero users)
//     lua_pushinteger(L, kCGEventOtherMouseDown);        lua_setfield(L, -2, "middleMouseDown");
//     lua_pushinteger(L, kCGEventOtherMouseUp);          lua_setfield(L, -2, "middleMouseUp");
//     lua_pushinteger(L, kCGEventOtherMouseDragged);     lua_setfield(L, -2, "middleMouseDragged");


    lua_pushinteger(L, NSEventTypeMouseEntered);       lua_setfield(L, -2, "mouseEntered");
    lua_pushinteger(L, NSEventTypeMouseExited);        lua_setfield(L, -2, "mouseExited");
    lua_pushinteger(L, NSEventTypeCursorUpdate);       lua_setfield(L, -2, "cursorUpdate");

    lua_pushinteger(L, NSEventTypePeriodic);           lua_setfield(L, -2, "periodic");

    lua_pushinteger(L, NSEventTypeAppKitDefined);      lua_setfield(L, -2, "appKitDefined");
    lua_pushinteger(L, NSEventTypeSystemDefined);      lua_setfield(L, -2, "systemDefined");
    lua_pushinteger(L, NSEventTypeApplicationDefined); lua_setfield(L, -2, "applicationDefined");
    lua_pushinteger(L, NSEventTypeQuickLook);          lua_setfield(L, -2, "quickLook");

    lua_pushinteger(L, NSEventTypeGesture);            lua_setfield(L, -2, "gesture");
    lua_pushinteger(L, NSEventTypeMagnify);            lua_setfield(L, -2, "magnify");
    lua_pushinteger(L, NSEventTypeSwipe);              lua_setfield(L, -2, "swipe");
    lua_pushinteger(L, NSEventTypeRotate);             lua_setfield(L, -2, "rotate");
    lua_pushinteger(L, NSEventTypeSmartMagnify);       lua_setfield(L, -2, "smartMagnify");
    lua_pushinteger(L, NSEventTypePressure);           lua_setfield(L, -2, "pressure");
    lua_pushinteger(L, NSEventTypeDirectTouch);        lua_setfield(L, -2, "directTouch");
    if (@available(macOS 10.15, *)) {
        lua_pushinteger(L, NSEventTypeChangeMode);         lua_setfield(L, -2, "changeMode");
    }

// // no longer generated as of 10.11+
//     lua_pushinteger(L, NSEventTypeBeginGesture);       lua_setfield(L, -2, "beginGesture");
//     lua_pushinteger(L, NSEventTypeEndGesture);         lua_setfield(L, -2, "endGesture");

}

/// hs.eventtap.event.properties -> table
/// Constant
/// A table containing property types for use with `hs.eventtap.event:getProperty()` and `hs.eventtap.event:setProperty()`.  The table supports forward (label to number) and reverse (number to label) lookups to increase its flexibility.
///
/// The constants defined in this table are as follows:
///    (I) in the description indicates that this property is returned or set as an integer
///    (N) in the description indicates that this property is returned or set as a number (floating point)
///
///   * eventSourceGroupID                                      -- (I) The event source Unix effective GID.
///   * eventSourceStateID                                      -- (I) The event source state ID used to create this event.
///   * eventSourceUnixProcessID                                -- (I) The event source Unix process ID.
///   * eventSourceUserData                                     -- (I) Event source user-supplied data, up to 64 bits.
///   * eventSourceUserID                                       -- (I) The event source Unix effective UID.
///   * eventTargetProcessSerialNumber                          -- (I) The event target process serial number. The value is a 64-bit long word.
///   * eventTargetUnixProcessID                                -- (I) The event target Unix process ID.
///   * eventUnacceleratedPointerMovementX                      -- Undocumented, assumed Integer
///   * eventUnacceleratedPointerMovementY                      -- Undocumented, assumed Integer
///   * keyboardEventAutorepeat                                 -- (I) Non-zero when this is an autorepeat of a key-down, and zero otherwise.
///   * keyboardEventKeyboardType                               -- (I) The keyboard type identifier.
///   * keyboardEventKeycode                                    -- (I) The virtual keycode of the key-down or key-up event.
///   * mouseEventButtonNumber                                  -- (I) The mouse button number. For information about the possible values, see Mouse Buttons.
///   * mouseEventClickState                                    -- (I) The mouse button click state. A click state of 1 represents a single click. A click state of 2 represents a double-click. A click state of 3 represents a triple-click.
///   * mouseEventDeltaX                                        -- (I) The horizontal mouse delta since the last mouse movement event.
///   * mouseEventDeltaY                                        -- (I) The vertical mouse delta since the last mouse movement event.
///   * mouseEventInstantMouser                                 -- (I) The value is non-zero if the event should be ignored by the Inkwell subsystem.
///   * mouseEventNumber                                        -- (I) The mouse button event number. Matching mouse-down and mouse-up events will have the same event number.
///   * mouseEventPressure                                      -- (N) The mouse button pressure. The pressure value may range from 0 to 1, with 0 representing the mouse being up. This value is commonly set by tablet pens mimicking a mouse.
///   * mouseEventSubtype                                       -- (I) Encoding of the mouse event subtype. 0 = mouse, 1 = tablet point, 2 = tablet proximity, 3 = touch
///   * mouseEventWindowUnderMousePointer                       -- (I) Window ID of window underneath mouse pointer (this corresponds to `hs.window:id()`)
///   * mouseEventWindowUnderMousePointerThatCanHandleThisEvent -- (I) Window ID of window underneath mouse pointer that can handle this event (this corresponds to `hs.window:id()`)
///   * scrollWheelEventDeltaAxis1                              -- (I) Scrolling data. This field typically contains the change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventDeltaAxis2                              -- (I) Scrolling data. This field typically contains the change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventDeltaAxis3                              -- (I) This field is not used.
///   * scrollWheelEventFixedPtDeltaAxis1                       -- (N) Contains scrolling data which represents a line-based or pixel-based change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventFixedPtDeltaAxis2                       -- (N) Contains scrolling data which represents a line-based or pixel-based change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventFixedPtDeltaAxis3                       -- (N) This field is not used.
///   * scrollWheelEventInstantMouser                           -- (I) Indicates whether the event should be ignored by the Inkwell subsystem. If the value is non-zero, the event should be ignored.
///   * scrollWheelEventIsContinuous                            -- (I) Indicates whether a scrolling event contains continuous, pixel-based scrolling data. The value is non-zero when the scrolling data is pixel-based and zero when the scrolling data is line-based (note that this is the opposite of what constants in CGEventTypes.h suggest, so test before relying on and let us know what you discover!).
///   * scrollWheelEventMomentumPhase                           -- (I) Indicates scroll momentum phase: 0 = none, 1 = begin, 2 = continue, 3 = end
///   * scrollWheelEventPointDeltaAxis1                         -- (I) Pixel-based scrolling data. The scrolling data represents the change in vertical position since the last scrolling event from a Mighty Mouse scroller or a single-wheel mouse scroller.
///   * scrollWheelEventPointDeltaAxis2                         -- (I) Pixel-based scrolling data. The scrolling data represents the change in horizontal position since the last scrolling event from a Mighty Mouse scroller.
///   * scrollWheelEventPointDeltaAxis3                         -- (I) This field is not used.
///   * scrollWheelEventScrollCount                             -- (I) The number of scroll gestures that have begun before the momentum phase of the initial gesture has ended (unverified, this is inferred from web comments).
///   * scrollWheelEventScrollPhase                             -- (I) Indicates scroll phase: 1 = began, 2 = changed, 4 = ended, 8 = cancelled, 128 = may begin.
///   * tabletEventDeviceID                                     -- (I) The system-assigned unique device ID.
///   * tabletEventPointButtons                                 -- (I) The tablet button state. Bit 0 is the first button, and a set bit represents a closed or pressed button. Up to 16 buttons are supported.
///   * tabletEventPointPressure                                -- (N) The tablet pen pressure. A value of 0.0 represents no pressure, and 1.0 represents maximum pressure.
///   * tabletEventPointX                                       -- (I) The absolute X coordinate in tablet space at full tablet resolution.
///   * tabletEventPointY                                       -- (I) The absolute Y coordinate in tablet space at full tablet resolution.
///   * tabletEventPointZ                                       -- (I) The absolute Z coordinate in tablet space at full tablet resolution.
///   * tabletEventRotation                                     -- (N) The tablet pen rotation.
///   * tabletEventTangentialPressure                           -- (N) The tangential pressure on the device. A value of 0.0 represents no pressure, and 1.0 represents maximum pressure.
///   * tabletEventTiltX                                        -- (N) The horizontal tablet pen tilt. A value of 0.0 represents no tilt, and 1.0 represents maximum tilt.
///   * tabletEventTiltY                                        -- (N) The vertical tablet pen tilt. A value of 0.0 represents no tilt, and 1.0 represents maximum tilt.
///   * tabletEventVendor1                                      -- (I) A vendor-specified value.
///   * tabletEventVendor2                                      -- (I) A vendor-specified value.
///   * tabletEventVendor3                                      -- (I) A vendor-specified value.
///   * tabletProximityEventCapabilityMask                      -- (I) The device capabilities mask.
///   * tabletProximityEventDeviceID                            -- (I) The system-assigned device ID.
///   * tabletProximityEventEnterProximity                      -- (I) Indicates whether the pen is in proximity to the tablet. The value is non-zero if the pen is in proximity to the tablet and zero when leaving the tablet.
///   * tabletProximityEventPointerID                           -- (I) The vendor-defined ID of the pointing device.
///   * tabletProximityEventPointerType                         -- (I) The pointer type.
///   * tabletProximityEventSystemTabletID                      -- (I) The system-assigned unique tablet ID.
///   * tabletProximityEventTabletID                            -- (I) The vendor-defined tablet ID, typically the USB product ID.
///   * tabletProximityEventVendorID                            -- (I) The vendor-defined ID, typically the USB vendor ID.
///   * tabletProximityEventVendorPointerSerialNumber           -- (I) The vendor-defined pointer serial number.
///   * tabletProximityEventVendorPointerType                   -- (I) The vendor-assigned pointer type.
///   * tabletProximityEventVendorUniqueID                      -- (I) The vendor-defined unique ID.
static void pushpropertiestable(lua_State* L) {
    lua_newtable(L);
    lua_pushinteger(L, kCGMouseEventNumber);                                         lua_setfield(L, -2, "mouseEventNumber");
    lua_pushinteger(L, kCGMouseEventClickState);                                     lua_setfield(L, -2, "mouseEventClickState");
    lua_pushinteger(L, kCGMouseEventPressure);                                       lua_setfield(L, -2, "mouseEventPressure");
    lua_pushinteger(L, kCGMouseEventButtonNumber);                                   lua_setfield(L, -2, "mouseEventButtonNumber");
    lua_pushinteger(L, kCGMouseEventDeltaX);                                         lua_setfield(L, -2, "mouseEventDeltaX");
    lua_pushinteger(L, kCGMouseEventDeltaY);                                         lua_setfield(L, -2, "mouseEventDeltaY");
    lua_pushinteger(L, kCGMouseEventInstantMouser);                                  lua_setfield(L, -2, "mouseEventInstantMouser");
    lua_pushinteger(L, kCGMouseEventSubtype);                                        lua_setfield(L, -2, "mouseEventSubtype");
    lua_pushinteger(L, kCGKeyboardEventAutorepeat);                                  lua_setfield(L, -2, "keyboardEventAutorepeat");
    lua_pushinteger(L, kCGKeyboardEventKeycode);                                     lua_setfield(L, -2, "keyboardEventKeycode");
    lua_pushinteger(L, kCGKeyboardEventKeyboardType);                                lua_setfield(L, -2, "keyboardEventKeyboardType");
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis1);                               lua_setfield(L, -2, "scrollWheelEventDeltaAxis1");
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis2);                               lua_setfield(L, -2, "scrollWheelEventDeltaAxis2");
    lua_pushinteger(L, kCGScrollWheelEventDeltaAxis3);                               lua_setfield(L, -2, "scrollWheelEventDeltaAxis3");
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis1);                        lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis1");
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis2);                        lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis2");
    lua_pushinteger(L, kCGScrollWheelEventFixedPtDeltaAxis3);                        lua_setfield(L, -2, "scrollWheelEventFixedPtDeltaAxis3");
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis1);                          lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis1");
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis2);                          lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis2");
    lua_pushinteger(L, kCGScrollWheelEventPointDeltaAxis3);                          lua_setfield(L, -2, "scrollWheelEventPointDeltaAxis3");
    lua_pushinteger(L, kCGScrollWheelEventInstantMouser);                            lua_setfield(L, -2, "scrollWheelEventInstantMouser");
    lua_pushinteger(L, kCGTabletEventPointX);                                        lua_setfield(L, -2, "tabletEventPointX");
    lua_pushinteger(L, kCGTabletEventPointY);                                        lua_setfield(L, -2, "tabletEventPointY");
    lua_pushinteger(L, kCGTabletEventPointZ);                                        lua_setfield(L, -2, "tabletEventPointZ");
    lua_pushinteger(L, kCGTabletEventPointButtons);                                  lua_setfield(L, -2, "tabletEventPointButtons");
    lua_pushinteger(L, kCGTabletEventPointPressure);                                 lua_setfield(L, -2, "tabletEventPointPressure");
    lua_pushinteger(L, kCGTabletEventTiltX);                                         lua_setfield(L, -2, "tabletEventTiltX");
    lua_pushinteger(L, kCGTabletEventTiltY);                                         lua_setfield(L, -2, "tabletEventTiltY");
    lua_pushinteger(L, kCGTabletEventRotation);                                      lua_setfield(L, -2, "tabletEventRotation");
    lua_pushinteger(L, kCGTabletEventTangentialPressure);                            lua_setfield(L, -2, "tabletEventTangentialPressure");
    lua_pushinteger(L, kCGTabletEventDeviceID);                                      lua_setfield(L, -2, "tabletEventDeviceID");
    lua_pushinteger(L, kCGTabletEventVendor1);                                       lua_setfield(L, -2, "tabletEventVendor1");
    lua_pushinteger(L, kCGTabletEventVendor2);                                       lua_setfield(L, -2, "tabletEventVendor2");
    lua_pushinteger(L, kCGTabletEventVendor3);                                       lua_setfield(L, -2, "tabletEventVendor3");
    lua_pushinteger(L, kCGTabletProximityEventVendorID);                             lua_setfield(L, -2, "tabletProximityEventVendorID");
    lua_pushinteger(L, kCGTabletProximityEventTabletID);                             lua_setfield(L, -2, "tabletProximityEventTabletID");
    lua_pushinteger(L, kCGTabletProximityEventPointerID);                            lua_setfield(L, -2, "tabletProximityEventPointerID");
    lua_pushinteger(L, kCGTabletProximityEventDeviceID);                             lua_setfield(L, -2, "tabletProximityEventDeviceID");
    lua_pushinteger(L, kCGTabletProximityEventSystemTabletID);                       lua_setfield(L, -2, "tabletProximityEventSystemTabletID");
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerType);                    lua_setfield(L, -2, "tabletProximityEventVendorPointerType");
    lua_pushinteger(L, kCGTabletProximityEventVendorPointerSerialNumber);            lua_setfield(L, -2, "tabletProximityEventVendorPointerSerialNumber");
    lua_pushinteger(L, kCGTabletProximityEventVendorUniqueID);                       lua_setfield(L, -2, "tabletProximityEventVendorUniqueID");
    lua_pushinteger(L, kCGTabletProximityEventCapabilityMask);                       lua_setfield(L, -2, "tabletProximityEventCapabilityMask");
    lua_pushinteger(L, kCGTabletProximityEventPointerType);                          lua_setfield(L, -2, "tabletProximityEventPointerType");
    lua_pushinteger(L, kCGTabletProximityEventEnterProximity);                       lua_setfield(L, -2, "tabletProximityEventEnterProximity");
    lua_pushinteger(L, kCGEventTargetProcessSerialNumber);                           lua_setfield(L, -2, "eventTargetProcessSerialNumber");
    lua_pushinteger(L, kCGEventTargetUnixProcessID);                                 lua_setfield(L, -2, "eventTargetUnixProcessID");
    lua_pushinteger(L, kCGEventSourceUnixProcessID);                                 lua_setfield(L, -2, "eventSourceUnixProcessID");
    lua_pushinteger(L, kCGEventSourceUserData);                                      lua_setfield(L, -2, "eventSourceUserData");
    lua_pushinteger(L, kCGEventSourceUserID);                                        lua_setfield(L, -2, "eventSourceUserID");
    lua_pushinteger(L, kCGEventSourceGroupID);                                       lua_setfield(L, -2, "eventSourceGroupID");
    lua_pushinteger(L, kCGEventSourceStateID);                                       lua_setfield(L, -2, "eventSourceStateID");
    lua_pushinteger(L, kCGScrollWheelEventIsContinuous);                             lua_setfield(L, -2, "scrollWheelEventIsContinuous");

    lua_pushinteger(L, kCGScrollWheelEventScrollPhase) ;                             lua_setfield(L, -2, "scrollWheelEventScrollPhase") ;
    lua_pushinteger(L, kCGScrollWheelEventScrollCount) ;                             lua_setfield(L, -2, "scrollWheelEventScrollCount") ;
    lua_pushinteger(L, kCGScrollWheelEventMomentumPhase) ;                           lua_setfield(L, -2, "scrollWheelEventMomentumPhase") ;
    lua_pushinteger(L, kCGMouseEventWindowUnderMousePointer) ;                       lua_setfield(L, -2, "mouseEventWindowUnderMousePointer") ;
    lua_pushinteger(L, kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent) ; lua_setfield(L, -2, "mouseEventWindowUnderMousePointerThatCanHandleThisEvent") ;
    lua_pushinteger(L, kCGEventUnacceleratedPointerMovementX) ;                      lua_setfield(L, -2, "eventUnacceleratedPointerMovementX") ;
    lua_pushinteger(L, kCGEventUnacceleratedPointerMovementY) ;                      lua_setfield(L, -2, "eventUnacceleratedPointerMovementY") ;
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
///  * deviceLeftAlternate       - Corresponds to the left alt key on the keyboard (if present)
///  * deviceLeftCommand         - Corresponds to the left cmd key on the keyboard (if present)
///  * deviceLeftControl         - Corresponds to the left ctrl key on the keyboard (if present)
///  * deviceLeftShift           - Corresponds to the left shift key on the keyboard (if present)
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
    {"getTouches",      eventtap_event_getTouches},
    {"getTouchDetails", eventtap_event_getTouchDetails},
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
    {"newGesture",        eventtap_event_newGesture},
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
            LuaSkin *skin = [LuaSkin sharedWithState:L];
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

static int NSTouch_toLua(lua_State *L, id obj) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L];
    NSTouch *touch = obj;

    lua_newtable(L);

    NSTouchType type = touch.type ;
    switch(type) {
        case NSTouchTypeDirect:   lua_pushstring(L, "direct") ; break ;
        case NSTouchTypeIndirect: lua_pushstring(L, "indirect") ; break ;
        default:
            lua_pushfstring(L, "** unrecognized type: %d", type) ;
    }
    lua_setfield(L, -2, "type") ;

    lua_pushfstring(L, "%p", touch.identity) ;    lua_setfield(L, -2, "identity") ;

    NSTouchPhase phase = touch.phase ;
    switch(phase) {
        case NSTouchPhaseBegan:      lua_pushstring(L, "began") ; break ;
        case NSTouchPhaseMoved:      lua_pushstring(L, "moved") ; break ;
        case NSTouchPhaseStationary: lua_pushstring(L, "stationary") ; break ;
        case NSTouchPhaseEnded:      lua_pushstring(L, "ended") ; break ;
        case NSTouchPhaseCancelled:  lua_pushstring(L, "cancelled") ; break ;

        case NSTouchPhaseTouching:
        case NSTouchPhaseAny:        lua_pushnil(L) ; break ;

        default:
            lua_pushfstring(L, "** unrecognized phase: %d", phase) ;
    }
    lua_setfield(L, -2, "phase") ;

    lua_pushboolean(L, ((phase & NSTouchPhaseTouching) > 0)) ; lua_setfield(L, -2, "touching") ;

    if (touch.type == NSTouchTypeIndirect) {
        [skin pushNSPoint:touch.normalizedPosition] ;         lua_setfield(L, -2, "normalizedPosition") ;
        [skin pushNSPoint:touch.previousNormalizedPosition] ; lua_setfield(L, -2, "previousNormalizedPosition") ;
    } else {
        [skin pushNSPoint:[touch locationInView:nil]] ;         lua_setfield(L, -2, "location") ;
        [skin pushNSPoint:[touch previousLocationInView:nil]] ; lua_setfield(L, -2, "previousLocation") ;
    }

    lua_pushnumber(L, touch.timestamp) ; lua_setfield(L, -2, "timestamp") ;

    double force = [touch _force] ;
    lua_pushnumber(L, force) ; lua_setfield(L, -2, "force") ;

    lua_pushboolean(L, touch.resting) ; lua_setfield(L, -2, "resting") ;

    lua_pushfstring(L, "%p", touch.device) ;    lua_setfield(L, -2, "device") ;

    [skin pushNSSize:touch.deviceSize] ; lua_setfield(L, -2, "deviceSize") ;

    return 1;
}


int luaopen_hs_libeventtapevent(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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

    // NOTE: @latenitefilms has tried to use `kCGEventSourceStateCombinedSessionState`
    //       and `kCGEventSourceStateHIDSystemState` as discussed in #2104
    //       however, it doesn't seem to be any different than `kCGEventSourceStatePrivate`
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
//     eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

    [skin registerPushNSHelper:NSTouch_toLua forClass:"NSTouch"];

    return 1;
}
