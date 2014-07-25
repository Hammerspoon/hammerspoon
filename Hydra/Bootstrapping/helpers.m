#import "helpers.h"

// stack in:  [..., error]
// stack out: [...]
void hydra_handle_error(lua_State* L) {
    // original error is at top of stack
    lua_getglobal(L, "hydra"); // pop this at the end
    lua_getfield(L, -1, "tryhandlingerror");
    lua_pushvalue(L, -3);
    lua_pcall(L, 1, 0, 0); // trust me
    lua_pop(L, 2);
}

NSSize hydra_tosize(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakeSize(w, h);
}

NSRect hydra_torect(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    CGFloat w = (lua_getfield(L, idx, "w"), luaL_checknumber(L, -1));
    CGFloat h = (lua_getfield(L, idx, "h"), luaL_checknumber(L, -1));
    lua_pop(L, 4);
    return NSMakeRect(x, y, w, h);
}

NSPoint hydra_topoint(lua_State* L, int idx) {
    luaL_checktype(L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, idx, "x"), luaL_checknumber(L, -1));
    CGFloat y = (lua_getfield(L, idx, "y"), luaL_checknumber(L, -1));
    lua_pop(L, 2);
    return NSMakePoint(x, y);
}

void hydra_pushsize(lua_State* L, NSSize size) {
    lua_newtable(L);
    lua_pushnumber(L, size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, size.height); lua_setfield(L, -2, "h");
}

void hydra_pushpoint(lua_State* L, NSPoint point) {
    lua_newtable(L);
    lua_pushnumber(L, point.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, point.y); lua_setfield(L, -2, "y");
}

void hydra_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

void hydra_setup_handler_storage(lua_State* L) {
    lua_newtable(L);
    lua_setglobal(L, "_registry");
}

int hydra_store_handler(lua_State* L, int idx) {
    idx = lua_absindex(L, idx);
    lua_getglobal(L, "_registry");
    lua_pushvalue(L, idx);
    int next = luaL_ref(L, -2);
    lua_pop(L, 1);
    return next;
}

void hydra_remove_handler(lua_State* L, int ref) {
    lua_getglobal(L, "_registry");
    luaL_unref(L, -1, ref);
    lua_pop(L, 1);
}

void* hydra_get_stored_handler(lua_State* L, int ref, const char* type) {
    lua_getglobal(L, "_registry");
    lua_rawgeti(L, -1, ref);
    if (!luaL_testudata(L, -1, type))
        luaL_error(L, "expected event handler to be of type %s, but wasn't.", type);
    void* handler = lua_touserdata(L, -1);
    lua_pop(L, 2);
    return handler;
}

// assumes stop-function is on top; leaves it there
void hydra_remove_all_handlers(lua_State* L, const char* type) {
    int stopfn = lua_absindex(L, -1);
    
    lua_newtable(L);
    int filteredtable = lua_absindex(L, -1);
    int filteredtable_count = 0;
    
    // filter registry
    lua_getglobal(L, "_registry");
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        if (lua_isuserdata(L, -1) && luaL_testudata(L, -1, type))
            lua_rawseti(L, filteredtable, ++filteredtable_count);
        else
            lua_pop(L, 1);
    }
    lua_pop(L, 1); // pop _registry, leaving table
    
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        lua_pushvalue(L, stopfn);
        lua_pushvalue(L, -2);
        
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
        
        lua_pop(L, 1);
    }
    lua_pop(L, 1); // pop filtered table
}

void hydra_push_luavalue_for_nsobject(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) {
        lua_pushnil(L);
    }
    else if ([obj isKindOfClass: [NSDictionary class]]) {
        lua_newtable(L);
        NSDictionary* dict = obj;
        
        for (id key in dict) {
            hydra_push_luavalue_for_nsobject(L, key);
            hydra_push_luavalue_for_nsobject(L, [dict objectForKey:key]);
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
    else if ([obj isKindOfClass: [NSDate class]]) {
        // not used for json, only in applistener; this should probably be moved to helpers
        NSDate* string = obj;
        lua_pushstring(L, [[string description] UTF8String]);
    }
    else if ([obj isKindOfClass: [NSArray class]]) {
        lua_newtable(L);
        
        int i = 0;
        NSArray* list = obj;
        
        for (id item in list) {
            hydra_push_luavalue_for_nsobject(L, item);
            lua_rawseti(L, -2, ++i);
        }
    }
}



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

id hydra_nsobject_for_luavalue(lua_State* L, int idx) {
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
                    id item = hydra_nsobject_for_luavalue(L, -1);
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
                    
                    id key = hydra_nsobject_for_luavalue(L, -2);
                    id val = hydra_nsobject_for_luavalue(L, -1);
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


