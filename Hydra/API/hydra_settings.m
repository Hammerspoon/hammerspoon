#import "helpers.h"

/// === hydra.settings ===
///
/// Functions for user-defined settings that persist across Hydra launches.


/*
 
 encoding rules:
 
 nil = @{}
 number = NSNumber
 string = NSString
 boolean = @{@"bool", @(bool)}
 table = @[ k, v, ... ]
 
 */

static id nsobject_for_luavalue(lua_State* L, int idx) {
    switch (lua_type(L, idx)) {
        case LUA_TNIL: return @{};
        case LUA_TNUMBER: return @(lua_tonumber(L, idx));
        case LUA_TBOOLEAN: return @{@"bool": @(lua_toboolean(L, idx))};
        case LUA_TSTRING: return [NSString stringWithUTF8String: lua_tostring(L, idx)];
        case LUA_TTABLE: {
            NSMutableArray* list = [NSMutableArray array];
            lua_pushnil(L);
            while (lua_next(L, idx) != 0) {
                id key = nsobject_for_luavalue(L, -2);
                id val = nsobject_for_luavalue(L, -1);
                [list addObject: key];
                [list addObject: val];
                lua_pop(L, 1);
            }
            return [list copy];
        }
        default: {
            lua_pushliteral(L, "non-serializable object given to settings");
            lua_error(L);
        }
    }
    // unreachable
    return nil;
}

/// hydra.settings.set(key, val)
/// Saves the given value for the string key; value must be a string, number, boolean, nil, or a table of any of these, recursively.
static int settings_set(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    id val = nsobject_for_luavalue(L, 2);
    [[NSUserDefaults standardUserDefaults] setObject:val forKey:key];
    
    return 0;
}

/// hydra.settings.get(key) -> val
/// Gets the Lua value for the given string key.
static int settings_get(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    hydra_push_luavalue_for_nsobject(L, val);
    return 1;
}

static const luaL_Reg settingslib[] = {
    {"set", settings_set},
    {"get", settings_get},
    {NULL, NULL}
};

int luaopen_hydra_settings(lua_State* L) {
    luaL_newlib(L, settingslib);
    return 1;
}
