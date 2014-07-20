#import "helpers.h"

/// === json ===
///
/// Functions for converting between Lua values and JSON strings.


/// json.encode(val[, prettyprint?]) -> str
/// Returns a JSON string representing the given value; if prettyprint is true, the resulting string will be quite beautiful.
static int json_encode(lua_State* L) {
    id obj = hydra_nsobject_for_luavalue(L, 1);
    
    NSJSONWritingOptions opts = 0;
    if (lua_toboolean(L, 2))
        opts = NSJSONWritingPrettyPrinted;
    
    NSError* __autoreleasing error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:obj options:opts error:&error];
    
    if (data) {
        NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        lua_pushstring(L, [str UTF8String]);
        return 1;
    }
    else {
        lua_pushstring(L, [[error localizedDescription] UTF8String]);
        lua_error(L);
        return 0; // unreachable
    }
}

/// json.decode(str) -> val
/// Returns a Lua value representing the given JSON string.
static int json_decode(lua_State* L) {
    const char* s = luaL_checkstring(L, 1);
    NSData* data = [[NSString stringWithUTF8String:s] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError* __autoreleasing error;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    
    if (obj) {
        hydra_push_luavalue_for_nsobject(L, obj);
        return 1;
    }
    else {
        lua_pushstring(L, [[error localizedDescription] UTF8String]);
        lua_error(L);
        return 0; // unreachable
    }
}

static const luaL_Reg jsonlib[] = {
    {"encode", json_encode},
    {"decode", json_decode},
    {NULL, NULL}
};

int luaopen_json(lua_State* L) {
    luaL_newlib(L, jsonlib);
    return 1;
}
