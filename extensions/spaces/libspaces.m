@import Cocoa ;
@import LuaSkin ;

#import "private.h"

static const char * const USERDATA_TAG = "hs.spaces" ;
static LSRefTable refTable = LUA_NOREF;

static NSRegularExpression *regEx_UUID ;

static int g_connection ;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.spaces.screensHaveSeparateSpaces() -> bool
/// Function
/// Determine if the user has enabled the "Displays Have Separate Spaces" option within Mission Control.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true or false representing the status of the "Displays Have Separate Spaces" option within Mission Control.
static int spaces_screensHaveSeparateSpaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [NSScreen screensHaveSeparateSpaces]) ;
    return 1 ;
}

/// hs.spaces.data_managedDisplaySpaces() -> table | nil, error
/// Function
/// Returns a table containing information about the managed display spaces
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing information about all of the displays and spaces managed by the OS.
///
/// Notes:
///  * the format and detail of this table is too complex and varied to describe here; suffice it to say this is the workhorse for this module and a careful examination of this table may be informative, but is not required in the normal course of using this module.
static int spaces_managedDisplaySpaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    CFArrayRef managedDisplaySpaces = SLSCopyManagedDisplaySpaces(g_connection) ;
    if (managedDisplaySpaces) {
        [skin pushNSObject:(__bridge NSArray *)managedDisplaySpaces withOptions:LS_NSDescribeUnknownTypes] ;
        CFRelease(managedDisplaySpaces) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "SLSCopyManagedDisplaySpaces returned NULL") ;
        return 2 ;
    }
    return 1 ;
}


/// hs.spaces.focusedSpace() -> integer
/// Function
/// Returns the space ID of the currently focused space
///
/// Parameters:
///  * None
///
/// Returns:
///  * the space ID for the currently focused space. The focused space is the currently active space on the currently active screen (i.e. that the user is working on)
///
/// Notes:
///  * *usually* the currently active screen will be returned by `hs.screen.mainScreen()`; however some full screen applications may have focus without updating which screen is considered "main". You can use this function, and look up the screen UUID with [hs.spaces.spaceDisplay](#spaceDisplay) to determine the "true" focused screen if required.
static int spaces_getActiveSpace(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)SLSGetActiveSpace(g_connection)) ;
    return 1 ;
}

/// hs.spaces.displayIsAnimating(screen) -> boolean | nil, error
/// Function
/// Returns whether or not the specified screen is currently undergoing space change animation
///
/// Parameters:
///  * `screen` - an integer specifying the screen ID, an hs.screen object, or a string specifying the UUID of the screen to check for animation
///
/// Returns:
///  * true if the screen is currently in the process of animating a space change, or false if it is not
///
/// Notes:
///  * Non-space change animations are not captured by this function -- unfortunately this lack also includes the change to the Mission Control and App Exposé displays.
static int spaces_managedDisplayIsAnimating(lua_State *L) { // NOTE: wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *screenUUID = [skin toNSObjectAtIndex:1] ;

    if (regEx_UUID) {
        if ([regEx_UUID numberOfMatchesInString:screenUUID options:NSMatchingAnchored range:NSMakeRange(0, screenUUID.length)] != 1) {
            lua_pushnil(L) ;
            lua_pushstring(L, "not a valid UUID string") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to verify UUID") ;
        return 2 ;
    }

    lua_pushboolean(L, SLSManagedDisplayIsAnimating(g_connection, (__bridge CFStringRef)screenUUID)) ;
    return 1 ;
}

/// hs.spaces.windowsForSpace(spaceID) -> table | nil, error
/// Function
/// Returns a table containing the window IDs of *all* windows on the specified space
///
/// Parameters:
///  * `spaceID` - an integer specifying the ID of the space
///
/// Returns:
///  * a table containing the window IDs for *all* windows on the specified space
///
/// Notes:
///  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
///
///  * The list of windows includes all items which are considered "windows" by macOS -- this includes visual elements usually considered unimportant like overlays, tooltips, graphics, off-screen windows, etc. so expect a lot of false positives in the results.
///  * In addition, due to the way Accessibility objects work, only those window IDs that are present on the currently visible spaces will be finable with `hs.window` or exist within `hs.window.allWindows()`.
///
///  * This function *will* prune Hammerspoon canvas elements from the list because we "own" these and can identify their window ID's programmatically. This does not help with other applications, however.
///
///  * Reviewing how third-party applications have generally pruned this list, I believe it will be necessary to use `hs.window.filter` to prune the list and access `hs.window` objects that are on the non-visible spaces.
///    * as `hs.window.filter` is scheduled to undergo a re-write soon to (hopefully) dramatically speed it up, I am providing this function *as is* at present for those who wish to experiment with it; however, I hope to make it more useful in the coming months and the contents may change in the future (the format won't, but hopefully the useless extras will disappear requiring less pruning logic on your end).
static int spaces_windowsForSpace(lua_State *L) { // NOTE: wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    uint64_t sid              = (uint64_t)lua_tointeger(L, 1) ;
    BOOL     includeMinimized = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : YES ;

    uint32_t owner     = 0 ;
    uint32_t options   = includeMinimized ? 0x7 : 0x2 ;
    uint64_t setTags   = 0 ;
    uint64_t clearTags = 0 ;

    int type = SLSSpaceGetType(g_connection, sid) ;
    if (type != 0 && type != 4) {
        lua_pushnil(L) ;
        lua_pushstring(L, "not a user or fullscreen managed space") ;
        return 2 ;
    }

    NSArray *spacesList = @[ [NSNumber numberWithUnsignedLongLong:sid] ] ;

    CFArrayRef windowListRef = SLSCopyWindowsWithOptionsAndTags(g_connection, owner, (__bridge CFArrayRef)spacesList, options, &setTags, &clearTags) ;

    if (windowListRef) {
        [skin pushNSObject:(__bridge NSArray *)windowListRef] ;
        lua_newtable(L) ;
        [skin requireModule:"hs.inspect"] ; lua_setfield(L, -2, "__tostring") ;
        lua_setmetatable(L, -2) ;

        CFRelease(windowListRef) ;
    } else {
        lua_pushnil(L) ;
        lua_pushfstring(L, "SLSCopyWindowsWithOptionsAndTags returned NULL for %d", sid) ;
        return 2 ;
    }
    return 1 ;
}

/// hs.spaces.moveWindowToSpace(window, spaceID) -> true | nil, error
/// Function
/// Moves the window with the specified windowID to the space specified by spaceID.
///
/// Parameters:
///  * `window`  - an integer specifying the ID of the window, or an `hs.window` object
///  * `spaceID` - an integer specifying the ID of the space
///
/// Returns:
///  * true if the window was moved; otherwise nil and an error message.
///
/// Notes:
///  * a window can only be moved from a user space to another user space -- you cannot move the window of a full screen (or tiled) application to another space and you cannot move a window *to* the same space as a full screen application.
static int spaces_moveWindowToSpace(lua_State *L) { // NOTE: wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    uint32_t wid = (uint32_t)lua_tointeger(L, 1) ;
    uint64_t sid = (uint64_t)lua_tointeger(L, 2) ;

    if (SLSSpaceGetType(g_connection, sid) != 0) {
        lua_pushnil(L) ;
        lua_pushfstring(L, "target space ID %d does not refer to a user space", sid) ;
        return 2 ;
    }

    NSArray *windows = @[ [NSNumber numberWithUnsignedLong:wid] ] ;
    // 0x7 : kCGSAllSpacesMask = CGSSpaceIncludesUser | CGSSpaceIncludesOthers |  CGSSpaceIncludesCurrent
    //       from https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h
    CFArrayRef spacesList = SLSCopySpacesForWindows(g_connection, 0x7, (__bridge CFArrayRef)windows) ;
    if (spacesList) {
        if (![(__bridge NSArray *)spacesList containsObject:[NSNumber numberWithUnsignedLongLong:sid]]) {
            NSNumber *sourceSpace = [(__bridge NSArray *)spacesList firstObject] ;
            if (SLSSpaceGetType(g_connection, sourceSpace.unsignedLongLongValue) != 0) {
                lua_pushnil(L) ;
                lua_pushfstring(L, "source space for windowID %d is not a user space", wid) ;
                return 2 ;
            }
            SLSMoveWindowsToManagedSpace(g_connection, (__bridge CFArrayRef)windows, sid) ;
        }
        lua_pushboolean(L, true) ;
        CFRelease(spacesList) ;
    } else {
        lua_pushnil(L) ;
        lua_pushfstring(L, "SLSCopySpacesForWindows returned NULL for window ID %d", wid) ;
        return 2 ;
    }
    return 1 ;
}

/// hs.spaces.windowSpaces(window) -> table | nil, error
/// Function
/// Returns a table containing the space IDs for all spaces that the specified window is on.
///
/// Parameters:
///  * `window` - an integer specifying the ID of the window, or an `hs.window` object
///
/// Returns:
///  * a table containing the space IDs of all spaces the window is on, or nil and an error message if an error occurs.
///
/// Notes:
///  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
///
///  * If the window ID does not specify a valid window, then an empty array will be returned.
///  * For most windows, this will be a single element table; however some applications may create "sticky" windows that may appear on more than one space.
///    * For example, the container windows for `hs.canvas` objects which have the `canJoinAllSpaces` behavior set will appear on all spaces and the table returned by this function will contain all spaceIDs for the screen which displays the canvas.
static int spaces_windowSpaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    uint32_t wid = (uint32_t)lua_tointeger(L, 1) ;

    NSArray *windows = @[ [NSNumber numberWithUnsignedLong:wid] ] ;
    // 0x7 : kCGSAllSpacesMask = CGSSpaceIncludesUser | CGSSpaceIncludesOthers |  CGSSpaceIncludesCurrent
    //       from https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h
    CFArrayRef spacesList = SLSCopySpacesForWindows(g_connection, 0x7, (__bridge CFArrayRef)windows) ;
    if (spacesList) {
        [skin pushNSObject:(__bridge NSArray *)spacesList] ;
        lua_newtable(L) ;
        [skin requireModule:"hs.inspect"] ; lua_setfield(L, -2, "__tostring") ;
        lua_setmetatable(L, -2) ;

        CFRelease(spacesList) ;
    } else {
        lua_pushnil(L) ;
        lua_pushfstring(L, "SLSCopySpacesForWindows returned NULL for window ID %d", wid) ;
        return 2 ;
    }
    return 1 ;
}

static int spaces_coreDesktopSendNotification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *message = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)(CoreDockSendNotification((__bridge CFStringRef)message, 0))) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"screensHaveSeparateSpaces", spaces_screensHaveSeparateSpaces},
    {"data_managedDisplaySpaces", spaces_managedDisplaySpaces},
    {"displayIsAnimating",        spaces_managedDisplayIsAnimating},

    // hs.spaces.activeSpaceOnScreen(hs.screen.mainScreen()) wrong for full screen apps, so keep
    {"focusedSpace",              spaces_getActiveSpace},

    {"moveWindowToSpace",         spaces_moveWindowToSpace},
    {"windowsForSpace",           spaces_windowsForSpace},
    {"windowSpaces",              spaces_windowSpaces},

    {"_coreDesktopNotification",  spaces_coreDesktopSendNotification},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libspaces(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:nil] ; // or module_metaLib

    g_connection = SLSMainConnectionID() ;

    NSError *error = nil ;
    regEx_UUID = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
                                                           options:NSRegularExpressionCaseInsensitive
                                                             error:&error] ;
    if (error) {
        regEx_UUID = nil ;
        [skin logError:[NSString stringWithFormat:@"%s.luaopen - unable to create UUID regular expression: %@", USERDATA_TAG, error.localizedDescription]] ;
    }

    return 1;
}
