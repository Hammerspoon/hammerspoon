#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#include <IOKit/hidsystem/event_status_driver.h>
#import <IOKit/hidsystem/IOHIDParameter.h>
#import <IOKit/hidsystem/IOHIDLib.h>

/// hs.mouse.getAbsolutePosition() -> point
/// Function
/// Gets the absolute co-ordinates of the mouse pointer
///
/// Parameters:
///  * None
///
/// Returns:
///  * A point-table containing the absolute x and y co-ordinates of the mouse pointer
///
/// Notes:
///  * The co-ordinates returned by this function are in relation to the full size of your desktop. If you have multiple monitors, the desktop is a large virtual rectangle that contains them all (e.g. if you have two 1920x1080 monitors and the mouse is in the middle of the second monitor, the returned table would be `{ x=2879, y=540 }`)
///  * Multiple monitors of different sizes can cause the co-ordinates of some areas of the desktop to be negative. This is perfectly normal. 0,0 in the co-ordinates of the desktop is the top left of the primary monitor
static int mouse_get(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK];

    CGEventRef ourEvent = CGEventCreate(NULL);
    [skin pushNSPoint:CGEventGetLocation(ourEvent)];
    CFRelease(ourEvent);
    return 1;
}

/// hs.mouse.setAbsolutePosition(point)
/// Function
/// Sets the absolute co-ordinates of the mouse pointer
///
/// Parameters:
///  * point - A point-table containing the absolute x and y co-ordinates to move the mouse pointer to
///
/// Returns:
///  * None
///
/// Notes:
///  * The co-ordinates given to this function must be in relation to the full size of your desktop. See the notes for `hs.mouse.getAbsolutePosition` for more information
static int mouse_set(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];

    CGWarpMouseCursorPosition([skin tableToPointAtIndex:1]);
    return 0;
}

static int mouseTrackpadAcceleration(lua_State *L, CFStringRef key) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    NXEventHandle handle;
    kern_return_t result;
    double mouseAcc;

    handle = NXOpenEventStatus();
    if (!handle) {
        [skin logError:@"Unable to get kernel handle for mouse/trackpad acceleration data"];
        lua_pushnumber(L, -1);
        return 1;
    }

    if (lua_type(L, 1) == LUA_TNUMBER) {
        mouseAcc = (double)lua_tonumber(L, 1);
        result = IOHIDSetAccelerationWithKey(handle, CFSTR(kIOHIDMouseAccelerationType), mouseAcc);
        if (result != KERN_SUCCESS) {
            NXCloseEventStatus(handle);
            [skin logError:[NSString stringWithFormat:@"Unable to set mouse/trackpad acceleration to %f: %d", mouseAcc, result]];
            lua_pushnumber(L, -1);
            return 1;
        }
    }

    result = IOHIDGetAccelerationWithKey(handle, CFSTR(kIOHIDMouseAccelerationType), &mouseAcc);

    if (result != KERN_SUCCESS) {
        [skin logError:[NSString stringWithFormat:@"Unable to get mouse/trackpad acceleration: %d", result]];
        mouseAcc = -1;
    }

    NXCloseEventStatus(handle);

    lua_pushnumber(L, mouseAcc);
    return 1;
}

/// hs.mouse.trackingSpeed([speed]) -> number
/// Function
/// Gets/Sets the current system mouse tracking speed setting
///
/// Parameters:
///  * speed - An optional number containing the new tracking speed to set. If this is ommitted, the current setting is returned
///
/// Returns:
///  * A number (currently between 0.0 and 3.0) indicating the current tracking speed setting for mice, or -1 if an error occurred
///
/// Notes:
///  * This is represented in the System Preferences as the "Tracking speed" setting for mice
///  * Note that not all values will work, they should map to the steps defined in the System Preferences app
static int mouse_mouseAcceleration(lua_State *L) {
    return mouseTrackpadAcceleration(L, CFSTR(kIOHIDMouseAccelerationType));
}

/// hs.mouse.scrollDirection() -> string
/// Function
/// Gets the system-wide direction of scolling
///
/// Paramters:
///  * None
///
/// Returns:
///  * A string, either "natural" or "normal"
static int mouse_scrollDirection(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK];

    NSString *scrollDirection = [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.apple.swipescrolldirection"] boolValue]? @"natural" : @"normal";
    [skin pushNSObject:scrollDirection];
    return 1;
}

//Note to future authors, there is no function to use kIOHIDTrackpadAccelerationType because it doesn't appear to do anything on modern systems.

static const luaL_Reg mouseLib[] = {
// Note that .get and .set are no longer documented. They should stick around for now, as they are used by our init.lua
    {"getAbsolutePosition", mouse_get},
    {"setAbsolutePosition", mouse_set},
    {"trackingSpeed", mouse_mouseAcceleration},
    {"scrollDirection", mouse_scrollDirection},
    {NULL, NULL}
};

int luaopen_hs_mouse_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:mouseLib metaFunctions:nil];

    return 1;
}
