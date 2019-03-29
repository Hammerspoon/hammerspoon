@import Cocoa ;
@import LuaSkin ;

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
        id obj = [[LuaSkin shared] toNSObjectAtIndex:1] ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
        NSJSONWritingOptions opts = 0;
#pragma clang diagnostic pop

        if (lua_toboolean(L, 2))
            opts = NSJSONWritingPrettyPrinted;

        if ([NSJSONSerialization isValidJSONObject:obj]) {
            NSError* error;
            NSData* data = [NSJSONSerialization dataWithJSONObject:obj options:opts error:&error];

			if (error) {
				return luaL_error(L, "%s", [[error localizedDescription] UTF8String]);
			} else if (data) {
				NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                lua_pushstring(L, [str UTF8String]);
                return 1;
			} else {
				return luaL_error(L, "json output returned nil") ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSData* data = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    if (data) {
        NSError* error;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];

		if (error) {
			return luaL_error(L, "%s", [[error localizedDescription] UTF8String]);
		} else if (obj) {
			[[LuaSkin shared] pushNSObject:obj] ;
			return 1;
		} else {
			return luaL_error(L, "json input returned nil") ;
		}

    } else {
        return luaL_error(L, "Unable to convert json input into data structure.") ;
    }
}

// Functions for returned object when module loads
static const luaL_Reg jsonLib[] = {
    {"encode",  json_encode},
    {"decode",  json_decode},
    {NULL,      NULL}
};

int luaopen_hs_json_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:jsonLib metaFunctions:nil];

    return 1;
}
