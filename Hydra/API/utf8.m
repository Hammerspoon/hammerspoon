#import "helpers.h"

/// === utf8 ===
///
/// Utilities for handling UTF-8 strings 'correctly'.

/// utf8.count(str) -> int
/// Returns the number of characters as humans would count them.
static int utf8_count(lua_State* L) {
    NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    NSInteger len = 0;
    for (NSInteger i = 0; i < [str length]; i++, len++) {
        NSRange r = [str rangeOfComposedCharacterSequenceAtIndex:i];
        i = NSMaxRange(r) - 1;
    }

    lua_pushnumber(L, len);
    return 1;
}


/// utf8.chars(str) -> {str, ...}
/// Splits the string into groups of (UTF-8 encoded) strings representing what humans would consider individual characters.
///
/// The result is a sequential table, such that table.concat(result) produces the original string.
static int utf8_chars(lua_State* L) {
    NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    lua_newtable(L);
    int pos = 0;

    for (NSInteger i = 0; i < [str length]; i++) {
        NSRange r = [str rangeOfComposedCharacterSequenceAtIndex:i];
        i = NSMaxRange(r) - 1;

        NSString* substr = [str substringWithRange:r];
        lua_pushstring(L, [substr UTF8String]);
        lua_rawseti(L, -2, ++pos);
    }

    return 1;
}

static const luaL_Reg utf8lib[] = {
    {"count", utf8_count},
    {"chars", utf8_chars},
    {NULL, NULL}
};

int luaopen_utf8(lua_State* L) {
    luaL_newlib(L, utf8lib);
    return 1;
}
