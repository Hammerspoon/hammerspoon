@import Cocoa ;
@import LuaSkin ;

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <stdint.h>
#import <string.h>

#import "private.h"

static const char * const USERDATA_TAG = "hs.spaces" ;
static LSRefTable refTable = LUA_NOREF;

static NSRegularExpression *regEx_UUID ;

static int g_connection ;

typedef int64_t (*SLSPerformAsyncWMOperationFn)(void *operation) ;
static SLSPerformAsyncWMOperationFn g_performAsyncWMOperation = NULL ;

@interface NSObject (HSSpacesBridgedMoveOperation)
- (instancetype)initWithWindows:(NSArray *)windows spaceID:(uint64_t)spaceID ;
@end

static const char * const SKYLIGHT_PATH = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight" ;
static const char * const ASYNC_MOVE_SYMBOL = "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation" ;

static struct mach_header_64 *spaces_findImageHeader(const char *targetName, intptr_t *slideOut) {
    uint32_t imageCount = _dyld_image_count() ;
    for (uint32_t i = 0 ; i < imageCount ; ++i) {
        const char *imageName = _dyld_get_image_name(i) ;
        if (imageName && strcmp(imageName, targetName) == 0) {
            *slideOut = _dyld_get_image_vmaddr_slide(i) ;
            return (struct mach_header_64 *)_dyld_get_image_header(i) ;
        }
    }
    return NULL ;
}

static struct segment_command_64 *spaces_findLinkeditSegment(struct mach_header_64 *header) {
    uint8_t *cursor = (uint8_t *)header + sizeof(struct mach_header_64) ;
    for (uint32_t i = 0 ; i < header->ncmds ; ++i) {
        struct load_command *command = (struct load_command *)cursor ;
        if (command->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *segment = (struct segment_command_64 *)command ;
            if (strncmp(segment->segname, SEG_LINKEDIT, sizeof(segment->segname)) == 0) return segment ;
        }
        cursor += command->cmdsize ;
    }
    return NULL ;
}

static struct symtab_command *spaces_findSymtabCommand(struct mach_header_64 *header) {
    uint8_t *cursor = (uint8_t *)header + sizeof(struct mach_header_64) ;
    for (uint32_t i = 0 ; i < header->ncmds ; ++i) {
        struct load_command *command = (struct load_command *)cursor ;
        if (command->cmd == LC_SYMTAB) return (struct symtab_command *)command ;
        cursor += command->cmdsize ;
    }
    return NULL ;
}

static void *spaces_findLocalMachOSymbol(const char *imagePath, const char *symbolName) {
    intptr_t slide = 0 ;
    struct mach_header_64 *header = spaces_findImageHeader(imagePath, &slide) ;
    if (!header) return NULL ;

    struct segment_command_64 *linkedit = spaces_findLinkeditSegment(header) ;
    struct symtab_command *symtab = spaces_findSymtabCommand(header) ;
    if (!linkedit || !symtab) return NULL ;

    uintptr_t linkeditBase = (uintptr_t)slide + (uintptr_t)linkedit->vmaddr - (uintptr_t)linkedit->fileoff ;
    const char *strings = (const char *)(linkeditBase + symtab->stroff) ;
    const struct nlist_64 *symbols = (const struct nlist_64 *)(linkeditBase + symtab->symoff) ;

    for (uint32_t i = 0 ; i < symtab->nsyms ; ++i) {
        if (symbols[i].n_un.n_strx == 0) continue ;
        const char *name = strings + symbols[i].n_un.n_strx ;
        if (strcmp(name, symbolName) == 0) {
            return (void *)((uintptr_t)slide + (uintptr_t)symbols[i].n_value) ;
        }
    }
    return NULL ;
}

static BOOL spaces_moveWindowsWithBridgedOperation(NSArray *windows, uint64_t sid) {
    if (!g_performAsyncWMOperation) return NO ;

    Class cls = NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation") ;
    if (!cls || ![cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)]) return NO ;

    id operation = [[cls alloc] initWithWindows:windows spaceID:sid] ;
    if (!operation) return NO ;

    g_performAsyncWMOperation((__bridge void *)operation) ;
    return YES ;
}

#pragma mark - Support Functions and Classes

// https://github.com/koekeishiya/yabai/commit/7bacdd59bdf39b53012e024b442d61913095794e#diff-fab09245ac7f0bacbd4b3648bdd51eff6c41dc937f5dbaaf7459ff9ea70d3557R17-R27
static bool workspace_is_macos_sonoma14_5_or_newer(void) {
    NSOperatingSystemVersion os_version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (os_version.majorVersion > 14) return true;
    if (os_version.majorVersion == 14 && os_version.minorVersion >= 5) return true;
    return false;
}

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
///  * The list of windows includes all items which are considered "windows" by macOS -- this includes visual elements usually considered unimportant like overlays, tooltips, graphics, off-screen windows, etc. so expect a lot of false positives in the results.
///  * In addition, due to the way Accessibility objects work, only those window IDs that are present on the currently visible spaces will be finable with `hs.window` or exist within `hs.window.allWindows()`.
///  * This function *will* prune Hammerspoon canvas elements from the list because we "own" these and can identify their window ID's programmatically. This does not help with other applications, however.
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

/// hs.spaces.moveWindowToSpace(window, spaceID[, force]) -> true | nil, error
/// Function
/// Moves the window with the specified windowID to the space specified by spaceID.
///
/// Parameters:
///  * `window`  - an integer specifying the ID of the window, or an `hs.window` object
///  * `spaceID` - an integer specifying the ID of the space
///  * `force` - an optional boolean specifying whether the window should be tried to move even if the spaces aren't compatible
///
/// Returns:
///  * true if the window was moved; otherwise nil and an error message.
///
/// Notes:
///  * a window can only be moved from a user space to another user space -- you cannot move the window of a full screen (or tiled) application to another space. you also cannot move a window *to* the same space as a full screen application unless `force` is set to true and even then it works for floating windows only.
///  * on macOS versions which provide the bridged WindowServer operation, the move is asynchronous; `true` means the operation was successfully submitted, not that WindowServer has already completed it.
static int spaces_moveWindowToSpace(lua_State *L) { // NOTE: wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    uint32_t wid = (uint32_t)lua_tointeger(L, 1) ;
    uint64_t sid = (uint64_t)lua_tointeger(L, 2) ;
    BOOL     force = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : NO ;

    if (SLSSpaceGetType(g_connection, sid) != 0 && force == NO) {
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
            if (SLSSpaceGetType(g_connection, sourceSpace.unsignedLongLongValue) != 0 && force == NO) {
                lua_pushnil(L) ;
                lua_pushfstring(L, "source space for windowID %d is not a user space", wid) ;
                CFRelease(spacesList);
                return 2 ;
            }

// Prefer the bridged WindowServer move operation when the private symbol is available.
// Fall back to the existing implementations on systems where it is absent.
            if (g_performAsyncWMOperation) {
                if (!spaces_moveWindowsWithBridgedOperation(windows, sid)) {
                    lua_pushnil(L) ;
                    lua_pushstring(L, "unable to create bridged window-to-space operation") ;
                    CFRelease(spacesList) ;
                    return 2 ;
                }
// https://github.com/koekeishiya/yabai/commit/98bbdbd1363f27d35f09338cded0de1ec010d830
            } else if (workspace_is_macos_sonoma14_5_or_newer()) {
                SLSSpaceSetCompatID(g_connection, sid, 0x79616265);
                SLSSetWindowListWorkspace(g_connection, &wid, 1, 0x79616265);
                SLSSpaceSetCompatID(g_connection, sid, 0x0);
            } else {
                SLSMoveWindowsToManagedSpace(g_connection, (__bridge CFArrayRef)windows, sid) ;
            }
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

    g_performAsyncWMOperation = (SLSPerformAsyncWMOperationFn)spaces_findLocalMachOSymbol(SKYLIGHT_PATH, ASYNC_MOVE_SYMBOL) ;

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
