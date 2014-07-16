#import "helpers.h"

/// pasteboard
///
/// Interfacing with the pasteboard (aka clipboard)

/// pasteboard.stringcontents() -> string
/// Returns the contents of the pasteboard as a string, or nil if it can't be done
static int pasteboard_stringcontents(lua_State* L) {
    lua_pushstring(L, [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] UTF8String]);
    return 1;
}

static luaL_Reg pasteboardlib[] = {
    {"stringcontents", pasteboard_stringcontents},
    {NULL, NULL}
};

int luaopen_pasteboard(lua_State* L) {
    luaL_newlib(L, pasteboardlib);
    return 1;
}
