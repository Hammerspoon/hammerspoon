// @import Cocoa ;
// @import LuaSkin ;

#import "Skin.h"

static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static void swapOutObjectInUserdata(lua_State *L, int idx, NSObject *obj, NSObject *newObj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    // change existing userdata: release old object and retain new one
    void** valuePtr = lua_touserdata(L, idx) ;
    NSObject *holding = (__bridge_transfer NSObject *)(*valuePtr) ;
    *valuePtr = (__bridge_retained void *)newObj ;
    holding = nil ;

    // get position in parent and change to newObj
    lua_getuservalue(L, idx) ;
    lua_getfield(L, -1, "_parent") ;
    if (luaL_testudata(L, -1, LuaSkin_UD_TAG)) {
        NSObject *parent = get_objectFromUserdata(__bridge NSObject, L, -1, LuaSkin_UD_TAG) ;
        if ([parent isKindOfClass:[NSMutableArray class]]) {
            NSUInteger arrayIndex = [(NSMutableArray *)parent indexOfObject:obj] ;
            if (arrayIndex != NSNotFound) {
                ((NSMutableArray *)parent)[arrayIndex] = newObj ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s.__newindex - original object '%@' not found in parent array", LuaSkin_UD_TAG, obj.description]] ;
            }
        } else if ([parent isKindOfClass:[NSMutableDictionary class]]) {
            NSArray *keyList = [(NSMutableDictionary *)parent allKeysForObject:obj] ;
            if (keyList.count > 0) {
                [keyList enumerateObjectsUsingBlock:^(NSObject *key, __unused NSUInteger klIdx, __unused BOOL *stop) {
                    ((NSMutableDictionary *)parent)[(id <NSCopying>)key] = newObj ;
                }] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s.__newindex - original object '%@' not found in parent dictionary", LuaSkin_UD_TAG, obj.description]] ;
            }
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s.__newindex - expected array or dictionary for parent; found %@", LuaSkin_UD_TAG, parent.className]] ;
        }
    }
    lua_pop(L, 2) ;
}

#pragma mark - Module Functions

static int obj_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSObject *obj = [skin toNSObjectAtIndex:1] ;
    LS_NSConversionOptions options = LS_WithObjectWrapper ;
    if (obj) {
        if ((lua_gettop(L) > 1) && lua_toboolean(L, 2)) options |= LS_OW_ReadWrite ;
        if ((lua_gettop(L) > 2) && lua_toboolean(L, 3)) options |= LS_OW_WithArrayConversion ;
    }
    [skin pushNSObject:obj withOptions:options] ;

    return 1 ;
}

#pragma mark - Module Methods

static int obj_isReadOnly(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TWRAPPEDOBJECT, LS_TBREAK] ;
    NSObject *obj = [skin toNSObjectAtIndex:1] ;

    BOOL isMutable = [obj isKindOfClass:[NSMutableArray class]] ||
                     [obj isKindOfClass:[NSMutableDictionary class]] ;

    lua_getuservalue(L, 1) ;
    lua_getfield(L, -1, "mutable") ;
    isMutable = isMutable && lua_toboolean(L, -1) ;
    lua_pop(L, 2) ;

    lua_pushboolean(L, !isMutable) ;
    return 1 ;
}

static int obj_children(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TWRAPPEDOBJECT, LS_TBREAK] ;
    NSObject *obj = [skin toNSObjectAtIndex:1] ;

    if ([obj isKindOfClass:[NSArray class]]) {
        lua_newtable(L) ;
        for (NSUInteger i = 0 ; i < [(NSArray *)obj count] ; i++) {
            lua_pushinteger(L, (lua_Integer)(i + 1)) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        [skin pushNSObject:[(NSDictionary *)obj allKeys]] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

static int obj_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TWRAPPEDOBJECT, LS_TBREAK] ;
    NSObject *obj = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:obj withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - objectWrapper metaFunctions

static int obj_ud_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSObject *obj = get_objectFromUserdata(__bridge NSObject, L, 1, LuaSkin_UD_TAG) ;
    NSObject *ans = nil ;

    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]]) {
        int type = lua_type(L, 2) ;
        if (type == LUA_TNUMBER && lua_isinteger(L, 2)) {
            lua_Integer lIdx = lua_tointeger(L, 2) ;
            if ([obj isKindOfClass:[NSArray class]]) {
                if (lIdx < 1 || lIdx > (lua_Integer)[(NSArray *)obj count]) {
                    ans = nil ;
                } else {
                    ans = [(NSArray *)obj objectAtIndex:(NSUInteger)(lIdx - 1)] ;
                }
            } else if ([obj isKindOfClass:[NSDictionary class]]) {
                ans = [(NSDictionary *)obj objectForKey:@(lIdx)] ;
            } else {
                ans = nil ;
            }
        } else if (type == LUA_TSTRING) {
            NSString *lKey = [skin toNSObjectAtIndex:2] ;
            if ([obj isKindOfClass:[NSDictionary class]]) {
                ans = [(NSDictionary *)obj objectForKey:lKey] ;
            } else {
                ans = nil ;
            }
        } else {
            ans = nil ;
        }
    } else if ([obj isKindOfClass:[NSString class]]) {
        // should be impossible for this implementation, but in case we copy this into something more
        // generic, lets include it since strings can apparently be index in lua, but always return nil
        ans = nil ;
    } else {
        return luaL_error(L, "attempt to index a %s value", obj.className.UTF8String) ;
    }

    [skin pushNSObject:ans withOptions:LS_WithObjectWrapper | LS_NSDescribeUnknownTypes] ;
    if (luaL_testudata(L, -1, LuaSkin_UD_TAG)) {
        lua_getuservalue(L, -1) ;
        lua_getuservalue(L, 1) ;
        lua_pushnil(L) ;
        while (lua_next(L, -2) != 0) {
            const char *key = lua_tostring(L, -2) ;
            if (strcmp("_parent", key)) { // i.e. does not equal
                lua_setfield(L, -4, key) ;
            } else {
                lua_pop(L, 1) ;
            }
        }
        lua_pop(L, 1) ;
        lua_pushvalue(L, 1) ;
        lua_setfield(L, -2, "_parent") ;
        lua_setuservalue(L, -2) ;
    }
    return 1 ;
}

static int obj_ud_newindex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSObject *obj = get_objectFromUserdata(__bridge NSObject, L, 1, LuaSkin_UD_TAG) ;
    BOOL isMutable = [obj isKindOfClass:[NSMutableArray class]] ||
                     [obj isKindOfClass:[NSMutableDictionary class]] ;
    BOOL arrayAutoConversion = NO ;

    lua_getuservalue(L, 1) ;
    lua_getfield(L, -1, "mutable") ;
    isMutable = isMutable && lua_toboolean(L, -1) ;
    lua_getfield(L, -2, "arrayAutoConversion") ;
    arrayAutoConversion = (BOOL)(lua_toboolean(L, -1)) ;
    lua_pop(L, 3) ;

    if (isMutable) {
//         return luaL_error(L, "modification of mutable objects not supported yet") ;

        if ([obj isKindOfClass:[NSMutableArray class]]) {
            NSObject *value = [skin toNSObjectAtIndex:3 withOptions:LS_NSDescribeUnknownTypes] ;

            if (lua_isinteger(L, 2)) {
                NSUInteger count = [(NSMutableArray *)obj count] ;
                lua_Integer idx = lua_tointeger(L, 2) ;
                if (idx > 0) {
                    if (value) {
                        while ((NSUInteger)idx > count) {
                            count++ ;
                            [(NSMutableArray *)obj addObject:[NSNull null]] ;
                        }
                        ((NSMutableArray *)obj)[(NSUInteger)(idx - 1)] = value ;
                    } else if ((NSUInteger)idx < count) {
                        ((NSMutableArray *)obj)[(NSUInteger)(idx - 1)] = [NSNull null] ;
                    } else if ((NSUInteger)idx == count) {
                        [(NSMutableArray *)obj removeLastObject] ;
                    }
                    return 0 ;
                } // if it's a float or < 1 then we fall through for conversion to dictionary, if allowed
            }

            if (value) {
                if (arrayAutoConversion) {
                    NSObject *key = [skin toNSObjectAtIndex:2] ;
                    NSMutableDictionary *newObj = [NSMutableDictionary dictionaryWithCapacity:[(NSMutableArray *)obj count] + 1] ;
                    newObj[(id <NSCopying>)key] = value ;
                    [(NSArray *)obj enumerateObjectsUsingBlock:^(NSObject *item, NSUInteger idx, __unused BOOL *stop) {
                        newObj[@(idx + 1)] = item ;
                    }] ;

                    swapOutObjectInUserdata(L, 1, obj, newObj) ;
                } else {
                    return luaL_error(L, "invalid key '%s'; expected integer equal to or greater than 1", obj.description.UTF8String) ;
                }
            } // else if value was nil, it doesn't really matter that the key type was invalid for an array
        } else if ([obj isKindOfClass:[NSMutableDictionary class]]) {
            NSObject *key = [skin toNSObjectAtIndex:2] ;
            NSObject *value = [skin toNSObjectAtIndex:3 withOptions:LS_NSDescribeUnknownTypes] ;
            if (key) {
                if (value) {
                    [(NSMutableDictionary *)obj setObject:value forKey:(id <NSCopying>)key] ;
                } else {
                    [(NSMutableDictionary *)obj removeObjectForKey:(id <NSCopying>)key] ;
                }
                if (arrayAutoConversion) {
                    NSUInteger totalKeys = [(NSMutableDictionary *)obj count] ;
                    NSUInteger count     = 0 ;
                    while (((NSDictionary *)obj)[@(count + 1)]) count++ ;
                    if (totalKeys == count) {
                        NSMutableArray *newObj = [NSMutableArray arrayWithCapacity:totalKeys] ;
                        count = 0 ;
                        while (((NSDictionary *)obj)[@(count + 1)]) {
                            NSObject *item = ((NSDictionary *)obj)[@(count + 1)] ;
                            [newObj addObject:item] ;
                            count++ ;
                        }

                        swapOutObjectInUserdata(L, 1, obj, newObj) ;
                    }
                }
            } else {
                return luaL_error(L, "invalid key; %s is not a valid key type", lua_typename(L, lua_type(L, 2))) ;
            }
        } else {
            return luaL_error(L, "expected array or dictionary; found %s", obj.className.UTF8String) ;
        }
    } else {
        return luaL_error(L, "read-only object") ;
    }
    return 0 ;
}

static int obj_ud_len(lua_State *L) {
    NSObject *obj = get_objectFromUserdata(__bridge NSObject, L, 1, LuaSkin_UD_TAG) ;
    if ([obj isKindOfClass:[NSArray class]]) {
        lua_pushinteger(L, (lua_Integer)[(NSArray *)obj count]) ;
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        lua_Integer len = 0 ;
        while (((NSDictionary *)obj)[@(len + 1)]) len++ ;
        lua_pushinteger(L, len) ;
    } else if ([obj isKindOfClass:[NSString class]]) {
        // should be impossible for this implementation, but in case we copy this into something more
        // generic, lets include it since strings can return a length in lua
        lua_pushinteger(L, (lua_Integer)[(NSString *)obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) ;
    } else {
        return luaL_error(L, "attempt to get length of a %s value", obj.className.UTF8String) ;
    }
    return 1 ;
}

static int obj_ud_tostring(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSObject *obj = get_objectFromUserdata(__bridge NSObject, L, 1, LuaSkin_UD_TAG) ;
    NSString *title = [(NSObject *)obj className] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", LuaSkin_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int obj_ud_eq(lua_State *L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, LuaSkin_UD_TAG) && luaL_testudata(L, 2, LuaSkin_UD_TAG)) {
        NSObject *obj1 = get_objectFromUserdata(__bridge NSObject, L, 1, LuaSkin_UD_TAG) ;
        NSObject *obj2 = get_objectFromUserdata(__bridge NSObject, L, 2, LuaSkin_UD_TAG) ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int obj_ud_gc(lua_State *L) {
    NSObject *obj = get_objectFromUserdata(__bridge_transfer NSObject, L, 1, LuaSkin_UD_TAG) ;
    obj = nil ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"children",   obj_children},
    {"value",      obj_value},
    {"isReadonly", obj_isReadOnly},

// __index will be set in LuaSkin registration, so wrap we'll wrap it in init.lua to call this
    {"__index2",   obj_ud_index},
    {"__newindex", obj_ud_newindex},
    {"__len",      obj_ud_len},
// wrapped in init.lua
//     {"__pairs",    obj_ud_pairs},
    {"__tostring", obj_ud_tostring},
    {"__eq",       obj_ud_eq},
    {"__gc",       obj_ud_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newObject", obj_new},
    {NULL,        NULL}
};

int luaopen_luaskin_internal(lua_State* L) {
// we can't use LuaSkin yet because we're still within createLuaState
    luaL_newlib(L, userdata_metaLib) ;
    lua_pushvalue(L, -1) ;
    lua_setfield(L, -2, "__index") ;
    lua_pushstring(L, LuaSkin_UD_TAG) ;
    lua_setfield(L, -2, "__type") ;
    lua_pushstring(L, LuaSkin_UD_TAG) ;
    lua_setfield(L, -2, "__name") ;
    lua_setfield(L, LUA_REGISTRYINDEX, LuaSkin_UD_TAG) ;

    luaL_newlib(L, moduleLib) ;
    lua_newtable(L) ;
    int tmpRefTable = luaL_ref(L, LUA_REGISTRYINDEX) ;
    lua_pushinteger(L, tmpRefTable) ;
    lua_setfield(L, -2, "__refTable") ;
    refTable = tmpRefTable ;

    lua_setglobal(L, "ls") ;

    return 0 ;
}
