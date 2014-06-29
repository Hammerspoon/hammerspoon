#import "helpers.h"

static BOOL is_sequential_table(lua_State* L, int idx) {
    NSMutableIndexSet* iset = [NSMutableIndexSet indexSet];
    
    lua_pushnil(L);
    while (lua_next(L, idx) != 0) {
        if (lua_isnumber(L, -2)) {
            double i = lua_tonumber(L, -2);
            if (i >= 1 && i <= NSNotFound - 1)
                [iset addIndex:i];
        }
        lua_pop(L, 1);
    }
    
    return [iset containsIndexesInRange:NSMakeRange([iset firstIndex], [iset lastIndex] - [iset firstIndex] + 1)];
}

static id nsobject_for_luavalue(lua_State* L, int idx) {
    idx = lua_absindex(L,idx);
    
    switch (lua_type(L, idx)) {
        case LUA_TNIL: return [NSNull null];
        case LUA_TNUMBER: return @(lua_tonumber(L, idx));
        case LUA_TBOOLEAN: return lua_toboolean(L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
        case LUA_TSTRING: return [NSString stringWithUTF8String: lua_tostring(L, idx)];
        case LUA_TTABLE: {
            if (is_sequential_table(L, idx)) {
                NSMutableArray* array = [NSMutableArray array];
                
                for (int i = 0; i < lua_rawlen(L, idx); i++) {
                    lua_rawgeti(L, idx, i+1);
                    id item = nsobject_for_luavalue(L, -1);
                    lua_pop(L, 1);
                    
                    [array addObject:item];
                }
                return array;
            }
            else {
                NSMutableDictionary* dict = [NSMutableDictionary dictionary];
                lua_pushnil(L);
                while (lua_next(L, idx) != 0) {
                    if (!lua_isstring(L, -2)) {
                        lua_pushliteral(L, "json map key must be a string");
                        lua_error(L);
                    }
                    
                    id key = nsobject_for_luavalue(L, -2);
                    id val = nsobject_for_luavalue(L, -1);
                    [dict setObject:val forKey:key];
                    lua_pop(L, 1);
                }
                return dict;
            }
        }
        default: {
            lua_pushliteral(L, "non-serializable object given to json");
            lua_error(L);
        }
    }
    // unreachable
    return nil;
}

static void push_luavalue_for_nsobject(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) {
        lua_pushnil(L);
    }
    else if ([obj isKindOfClass: [NSDictionary class]]) {
        lua_newtable(L);
        NSDictionary* dict = obj;
        
        for (id key in dict) {
            push_luavalue_for_nsobject(L, key);
            push_luavalue_for_nsobject(L, [dict objectForKey:key]);
            lua_settable(L, -3);
        }
    }
    else if ([obj isKindOfClass: [NSNumber class]]) {
        if (obj == (id)kCFBooleanTrue)
            lua_pushboolean(L, YES);
        else if (obj == (id)kCFBooleanFalse)
            lua_pushboolean(L, NO);
        else
            lua_pushnumber(L, [(NSNumber*)obj doubleValue]);
    }
    else if ([obj isKindOfClass: [NSString class]]) {
        NSString* string = obj;
        lua_pushstring(L, [string UTF8String]);
    }
    else if ([obj isKindOfClass: [NSArray class]]) {
        lua_newtable(L);
        
        int i = 0;
        NSArray* list = obj;
        
        for (id item in list) {
            push_luavalue_for_nsobject(L, item);
            lua_rawseti(L, -2, ++i);
        }
    }
}

static hydradoc doc_json_encode = {
    "json", "encode", "json.encode(val[, prettyprint?]) -> str",
    "Returns a JSON string representing the given value; if prettyprint is true, the resulting string will be quite beautiful."
};

static int json_encode(lua_State* L) {
    id obj = nsobject_for_luavalue(L, 1);
    
    NSJSONWritingOptions opts = 0;
    if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
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

static hydradoc doc_json_decode = {
    "json", "decode", "json.decode(str) -> val",
    "Returns a Lua value representing the given JSON string."
};

static int json_decode(lua_State* L) {
    const char* s = lua_tostring(L, 1);
    NSData* data = [[NSString stringWithUTF8String:s] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError* __autoreleasing error;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    
    if (obj) {
        push_luavalue_for_nsobject(L, obj);
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
    hydra_add_doc_group(L, "json", "Functions for converting between Lua values and JSON strings.");
    hydra_add_doc_item(L, &doc_json_encode);
    hydra_add_doc_item(L, &doc_json_decode);
    
    luaL_newlib(L, jsonlib);
    return 1;
}
