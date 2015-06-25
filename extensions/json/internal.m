#import <Cocoa/Cocoa.h>
#import <lua/lauxlib.h>

// The following two functions will go away someday (soon I hope) and be found in the core
// app of hammerspoon because they are just so darned useful in so many contexts... but they
// have serious limitations as well, and I need to work to clear those... it's an absolute
// requirement for this module, and the way this module is being used *shouldn't* trip the
// issues unless someone absolutely tries to screw them up... and all it does is
// crash Hammerspoon when it happens, so...

static id lua_to_NSObject(lua_State* L, int idx) {
    idx = lua_absindex(L,idx);
    switch (lua_type(L, idx)) {
        case LUA_TNUMBER: return @(lua_tonumber(L, idx));
        case LUA_TSTRING: return [NSString stringWithUTF8String: lua_tostring(L, idx)];
        case LUA_TNIL: return [NSNull null];
        case LUA_TBOOLEAN: return lua_toboolean(L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
        case LUA_TTABLE: {
            NSMutableDictionary* numerics = [NSMutableDictionary dictionary];
            NSMutableDictionary* nonNumerics = [NSMutableDictionary dictionary];
            NSMutableIndexSet*   numericKeys = [NSMutableIndexSet indexSet];
            NSMutableArray*      numberArray = [NSMutableArray array];
            lua_pushnil(L);
            while (lua_next(L, idx) != 0) {
                id key = lua_to_NSObject(L, -2);
                id val = lua_to_NSObject(L, lua_gettop(L));
                if ([key isKindOfClass: [NSNumber class]]) {
                    [numericKeys addIndex:[key intValue]];
                    [numerics setValue:val forKey:key];
                } else {
                    [nonNumerics setValue:val forKey:key];
                }
                lua_pop(L, 1);
            }
            if (numerics.count > 0) {
                for (unsigned long i = 1; i <= [numericKeys lastIndex]; i++) {
                    [numberArray addObject:(
                        [numerics objectForKey:[NSNumber numberWithInteger:i]] ?
                            [numerics objectForKey:[NSNumber numberWithInteger:i]] : [NSNull null]
                    )];
                }
                if (nonNumerics.count == 0)
                    return [numberArray copy];
            } else {
                return [nonNumerics copy];
            }
            NSMutableDictionary* unionBlob = [NSMutableDictionary dictionary];
            [unionBlob setValue:[NSArray arrayWithObjects:numberArray, nonNumerics, nil] forKey:@"MJ_LUA_TABLE"];
            return [unionBlob copy];
        }
        default: { lua_pushliteral(L, "non-serializable object"); lua_error(L); }
    }
    return nil;
}

static void NSObject_to_lua(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) { lua_pushnil(L); }
    else if ([obj isKindOfClass: [NSDictionary class]]) {
        BOOL handled = NO;
        if ([obj count] == 1) {
            if ([obj objectForKey:@"MJ_LUA_NIL"]) {
                lua_pushnil(L);
                handled = YES;
            } else
            if ([obj objectForKey:@"MJ_LUA_TABLE"]) {
                NSArray* parts = [obj objectForKey:@"MJ_LUA_TABLE"] ;
                NSArray* numerics = [parts objectAtIndex:0] ;
                NSDictionary* nonNumerics = [parts objectAtIndex:1] ;
                lua_newtable(L);
                int i = 0;
                for (id item in numerics) {
                    NSObject_to_lua(L, item);
                    lua_rawseti(L, -2, ++i);
                }
                NSArray *keys = [nonNumerics allKeys];
                NSArray *values = [nonNumerics allValues];
                for (unsigned long i = 0; i < keys.count; i++) {
                    NSObject_to_lua(L, [keys objectAtIndex:i]);
                    NSObject_to_lua(L, [values objectAtIndex:i]);
                    lua_settable(L, -3);
                }
                handled = YES;
            }
        }
        if (!handled) {
            NSArray *keys = [obj allKeys];
            NSArray *values = [obj allValues];
            lua_newtable(L);
            for (unsigned long i = 0; i < keys.count; i++) {
                NSObject_to_lua(L, [keys objectAtIndex:i]);
                NSObject_to_lua(L, [values objectAtIndex:i]);
                lua_settable(L, -3);
            }
        }
    } else if ([obj isKindOfClass: [NSNumber class]]) {
        NSNumber* number = obj;
        if (number == (id)kCFBooleanTrue)
            lua_pushboolean(L, YES);
        else if (number == (id)kCFBooleanFalse)
            lua_pushboolean(L, NO);
        else if (CFNumberIsFloatType((CFNumberRef)number))
            lua_pushnumber(L, [number doubleValue]);
        else
            lua_pushinteger(L, [number intValue]);
    } else if ([obj isKindOfClass: [NSString class]]) {
        NSString* string = obj;
        lua_pushstring(L, [string UTF8String]);
    } else if ([obj isKindOfClass: [NSArray class]]) {
        int i = 0;
        NSArray* list = obj;
        lua_newtable(L);
        for (id item in list) {
            NSObject_to_lua(L, item);
            lua_rawseti(L, -2, ++i);
        }
    } else if ([obj isKindOfClass: [NSDate class]]) {
        lua_pushnumber(L, [(NSDate *) obj timeIntervalSince1970]);
    } else if ([obj isKindOfClass: [NSData class]]) {
        lua_pushlstring(L, [obj bytes], [obj length]) ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"<Object> : %@", obj] UTF8String]) ;
    }
}

/// hs.json.encode(val[, prettyprint]) -> string
/// Function
/// Encodes a table as JSON
///
/// Parameters:
///  * val - A table containing data to be encoded as JSON
///  * prettyprint - An optional boolean, true to format the JSON for human readability, false to format the JSON for size efficiency. Defaults to false
///
/// Returns:
///  * A string containing a JSON representation of the supplied table
///
/// Notes:
///  * This is useful for storing some of the more complex lua table structures as a persistent setting (see `hs.settings`)
static int json_encode(lua_State* L) {
    if lua_istable(L, 1) {
        id obj = lua_to_NSObject(L, 1);

        NSJSONWritingOptions opts = 0;
        if (lua_toboolean(L, 2))
            opts = NSJSONWritingPrettyPrinted;

        if ([NSJSONSerialization isValidJSONObject:obj]) {
            NSError* error;
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
        } else {
            luaL_error(L, "object cannot be encoded as a json string") ;
            return 0;
        }
    } else {
        lua_pop(L, 1) ;
        luaL_error(L, "non-table object given to json encoder");
        return 0;
    }
}

/// hs.json.decode(jsonString) -> table
/// Function
/// Decodes JSON into a table
///
/// Parameters:
///  * jsonString - A string containing some JSON data
///
/// Returns:
///  * A table representing the supplied JSON data
///
/// Notes:
///  * This is useful for retrieving some of the more complex lua table structures as a persistent setting (see `hs.settings`)
static int json_decode(lua_State* L) {
    const char* s = luaL_checkstring(L, 1);
    NSData* data = [[NSString stringWithUTF8String:s] dataUsingEncoding:NSUTF8StringEncoding];

    NSError* error;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];

    if (obj) {
        NSObject_to_lua(L, obj);
        return 1;
    }
    else {
        lua_pushstring(L, [[error localizedDescription] UTF8String]);
        lua_error(L);
        return 0; // unreachable
    }
}

// Functions for returned object when module loads
static const luaL_Reg jsonLib[] = {
    {"encode",  json_encode},
    {"decode",  json_decode},
    {NULL,      NULL}
};

int luaopen_json(lua_State* L) {
    // setup the module
    luaL_newlib(L, jsonLib);
    return 1;
}
