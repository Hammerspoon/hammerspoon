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
        id obj = [[LuaSkin sharedWithState:L] toNSObjectAtIndex:1] ;

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSData* data = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    if (data) {
        NSError* error;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];

		if (error) {
			return luaL_error(L, "%s", [[error localizedDescription] UTF8String]);
		} else if (obj) {
			[skin pushNSObject:obj] ;
			return 1;
		} else {
			return luaL_error(L, "json input returned nil") ;
		}

    } else {
        return luaL_error(L, "Unable to convert json input into data structure.") ;
    }
}

/// hs.json.write(data, path, [prettyprint], [replace]) -> boolean
/// Function
/// Encodes a table as JSON to a file
///
/// Parameters:
///  * data - A table containing data to be encoded as JSON
///  * path - The path and filename of the JSON file to write to
///  * prettyprint - An optional boolean, `true` to format the JSON for human readability, `false` to format the JSON for size efficiency. Defaults to `false`
///  * replace - An optional boolean, `true` to replace an existing file at the same path if one exists. Defaults to `false`
///
/// Returns:
///  * `true` if successful otherwise `false` if an error has occurred
static int json_write(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (!lua_istable(L, 1)) {
        [skin logError:[NSString stringWithFormat:@"Non-table object given to JSON encoder."]] ;
        lua_pushboolean(L, false);
        return 1;
    } else {
        id obj = [skin toNSObjectAtIndex:1] ;

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wassign-enum"
        NSJSONWritingOptions opts = 0;
        #pragma clang diagnostic pop

        if (lua_toboolean(L, 3)) {
            opts = NSJSONWritingPrettyPrinted;
        }

        if (![NSJSONSerialization isValidJSONObject:obj]) {
            [skin logError:[NSString stringWithFormat:@"Object cannot be encoded as a JSON string."]] ;
            lua_pushboolean(L, false);
            return 1;
        } else {

            NSError* error;
            NSData* data = [NSJSONSerialization dataWithJSONObject:obj options:opts error:&error];

            if (error) {
                [skin logError:[NSString stringWithFormat:@"%s", [[error localizedDescription] UTF8String]]] ;
                lua_pushboolean(L, false);
                return 1;
            } else if (data) {
                NSString *path = [[skin toNSObjectAtIndex:2] stringByExpandingTildeInPath];

                BOOL replace = NO;
                if (lua_type(L, 4) == LUA_TBOOLEAN) {
                    replace = lua_toboolean(L, 4);
                }

                BOOL writeStatus = [data writeToFile: path
                                               options: (replace ? NSDataWritingAtomic : NSDataWritingWithoutOverwriting)
                                                 error: &error];
                if (!writeStatus) {
                    [skin logError:[NSString stringWithFormat:@"Error writing to file: %@", error]] ;
                    lua_pushboolean(L, false);
                    return 1;
                }

                lua_pushboolean(L, true);
                return 1;

            } else {
                [skin logError:[NSString stringWithFormat:@"JSON output returned nil."]] ;
                lua_pushboolean(L, false);
                return 1;
            }
        }
    }
}

/// hs.json.read(path) -> table | nil
/// Function
/// Decodes JSON file into a table.
///
/// Parameters:
///  * path - The path and filename of the JSON file to read.
///
/// Returns:
///  * A table representing the supplied JSON data, or `nil` if an error occurs.
static int json_read(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *path = [[skin toNSObjectAtIndex:1] stringByExpandingTildeInPath];
    NSData *data = [NSData dataWithContentsOfFile:path];

    if (!data) {
        [skin logError:[NSString stringWithFormat:@"Unable to convert JSON input into data structure. Was the path valid?"]] ;
        lua_pushnil(L);
        return 1;
    } else {
        NSError* error;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];

        if (error) {
            [skin logError:[NSString stringWithFormat:@"%s", [[error localizedDescription] UTF8String]]] ;
            lua_pushnil(L);
            return 1;
        } else if (obj) {
            [skin pushNSObject:obj] ;
            return 1;
        } else {
            [skin logError:[NSString stringWithFormat:@"JSON input returned nil"]] ;
            lua_pushnil(L);
            return 1;
        }
    }
}

// Functions for returned object when module loads
static const luaL_Reg jsonLib[] = {
    {"encode",  json_encode},
    {"decode",  json_decode},
    {"read",    json_read},
    {"write",   json_write},
    {NULL,      NULL}
};

int luaopen_hs_json_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:jsonLib metaFunctions:nil];

    return 1;
}
