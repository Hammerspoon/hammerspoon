#import <Cocoa/Cocoa.h>
#import <lua/lauxlib.h>

NSPasteboard *lua_to_pasteboard(lua_State* L, int idx) {
    if (!lua_isnoneornil(L, 1)) {
        return [NSPasteboard pasteboardWithName:[NSString stringWithUTF8String:luaL_checkstring(L, idx)]];
    } else {
        return [NSPasteboard generalPasteboard];
    }

}

/// hs.pasteboard.getContents([name]) -> string or nil
/// Function
/// Gets the contents of the pasteboard
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * A string containing the contents of the pasteboard, or nil if an error occurred
static int pasteboard_getContents(lua_State* L) {
        lua_pushstring(L, [[lua_to_pasteboard(L, 1) stringForType:NSPasteboardTypeString] UTF8String]);
    return 1;
}

/// hs.pasteboard.setContents(contents[, name]) -> boolean
/// Function
/// Sets the contents of the pasteboard
///
/// Parameters:
///  * contents - A string to be placed in the pasteboard
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * True if the operation succeeded, otherwise false
static int pasteboard_setContents(lua_State* L) {
    NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 2);

    [thePasteboard clearContents];
    BOOL result = [thePasteboard setString:str forType:NSPasteboardTypeString];

    lua_pushboolean(L, result);
    return 1;
}

/// hs.pasteboard.clearContents([name]) -> boolean
/// Function
/// Clear the contents of the pasteboard
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * None
static int pasteboard_clearContents(lua_State* L) {
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);
    [thePasteboard clearContents];

    return 0;
}

/// hs.pasteboard.changeCount([name]) -> number
/// Function
/// Gets the number of times the pasteboard owner has changed
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * A number containing a count of the times the pasteboard owner has changed
///
/// Notes:
///  * This is useful for seeing if the pasteboard has been updated by another process
static int pasteboard_changeCount(lua_State* L) {
    lua_pushnumber(L, [lua_to_pasteboard(L, 1) changeCount]);
    return 1;
}

/// hs.pasteboard.deletePasteboard(name)
/// Function
/// Deletes a custom pasteboard
///
/// Parameters:
///  * name - A string containing the name of the pasteboard
///
/// Returns:
///  * None
///
/// Notes:
///  * You can not delete the system pasteboard, this function should only be called on custom pasteboards you have created
static int pasteboard_delete(lua_State* L) {
    NSPasteboard *thePasteboard = [NSPasteboard pasteboardWithName:[NSString stringWithUTF8String:luaL_checkstring(L, 1)]];
    [thePasteboard releaseGlobally];

    return 0;
}

// Functions for returned object when module loads
static const luaL_Reg pasteboardLib[] = {
    {"changeCount",  pasteboard_changeCount},
    {"getContents",  pasteboard_getContents},
    {"setContents",  pasteboard_setContents},
    {"clearContents", pasteboard_clearContents},
    {"deletePasteboard", pasteboard_delete},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L) {
    luaL_newlib(L, pasteboardLib);

    return 1;
}

