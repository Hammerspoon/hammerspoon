#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

/// hs.pasteboard.getContents() -> string or nil
/// Function
/// Gets the contents of the pasteboard
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the contents of the pasteboard, or nil if an error occurred
static int pasteboard_getContents(lua_State* L) {
    lua_pushstring(L, [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] UTF8String]);
    return 1;
}

/// hs.pasteboard.setContents(contents) -> boolean
/// Function
/// Sets the contents of the pasteboard
///
/// Parameters:
///  * contents - A string to be placed in the pasteboard
///
/// Returns:
///  * True if the operation succeeded, otherwise false
static int pasteboard_setContents(lua_State* L) {
    NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    [[NSPasteboard generalPasteboard] clearContents];
    BOOL result = [[NSPasteboard generalPasteboard] setString:str forType:NSPasteboardTypeString];

    lua_pushboolean(L, result);
    return 1;
}

/// hs.pasteboard.changeCount() -> number
/// Function
/// Gets the number of times the pasteboard owner has changed
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing a count of the times the pasteboard owner has changed
///
/// Notes:
///  * This is useful for seeing if the pasteboard has been updated by another process
static int pasteboard_changeCount(lua_State* L) {
    lua_pushnumber(L, [[NSPasteboard generalPasteboard] changeCount]);
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg pasteboardLib[] = {
    {"changeCount",  pasteboard_changeCount},
    {"getContents",  pasteboard_getContents},
    {"setContents",  pasteboard_setContents},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L) {
    luaL_newlib(L, pasteboardLib);

    return 1;
}

