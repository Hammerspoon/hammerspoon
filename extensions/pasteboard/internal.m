#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

/// hs.pasteboard.getcontents() -> string
/// Function
/// Returns the contents of the pasteboard as a string, or nil if it can't be done
static int pasteboard_getcontents(lua_State* L) {
    lua_pushstring(L, [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] UTF8String]);
    return 1;
}

/// hs.pasteboard.setcontents(string) -> boolean
/// Function
/// Sets the contents of the pasteboard to the string value passed in. Returns success status as true or false.
static int pasteboard_setcontents(lua_State* L) {
    NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    [[NSPasteboard generalPasteboard] clearContents];
    BOOL result = [[NSPasteboard generalPasteboard] setString:str forType:NSPasteboardTypeString];

    lua_pushboolean(L, result);
    return 1;
}

/// hs.pasteboard.changecount() -> number
/// Function
/// The number of times the pasteboard owner changed (useful to see if the pasteboard was updated, by seeing if the value of this function changes).
static int pasteboard_changecount(lua_State* L) {
    lua_pushnumber(L, [[NSPasteboard generalPasteboard] changeCount]);
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg pasteboardLib[] = {
    {"changecount",  pasteboard_changecount},
    {"getcontents",  pasteboard_getcontents},
    {"setcontents",  pasteboard_setcontents},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L) {
    luaL_newlib(L, pasteboardLib);

    return 1;
}

