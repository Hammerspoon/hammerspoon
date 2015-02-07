#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

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
        else
            lua_pushnumber(L, [number doubleValue]);
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

/// hs.settings.set(key, val)
/// Function
/// Saves a setting with common datatypes
///
/// Parameters:
///  * key - A string containing the name of the setting
///  * val - A value for the setting. Valid datatypes are:
///   * string
///   * number
///   * boolean
///   * nil
///   * table (which may contain any of the same valid datatypes)
///
/// Returns:
///  * None
///
/// Notes:
///  * This function cannot set dates or raw data types, see `hs.settings.setDate()` and `hs.settings.setData()`
static int target_set(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    id val = lua_to_NSObject(L, 2);
    [[NSUserDefaults standardUserDefaults] setObject:val forKey:key];
    return 0;
}

/// hs.settings.setData(key, val)
/// Function
/// Saves a setting with raw binary data
///
/// Parameters:
///  * key - A string containing the name of the setting
///  * val - Some raw binary data
///
/// Returns:
///  * None
static int target_setData(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if (lua_type(L,2) == LUA_TSTRING) {
        const char* data = lua_tostring(L,2) ;
        int sz = lua_rawlen(L, 2) ;
        NSData* myData = [[NSData alloc] initWithBytes:data length:sz] ;
        [[NSUserDefaults standardUserDefaults] setObject:myData forKey:key];
    } else {
        luaL_error(L, "second argument not (binary data encapsulated as) a string") ;
    }

    return 0 ;
}

static NSDate* date_from_string(NSString* dateString) {
    // rfc3339 (Internet Date/Time) formated date.  More or less.
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSDate *date = [rfc3339DateFormatter dateFromString:dateString];
    return date;
}

/// hs.settings.setDate(key, val)
/// Function
/// Saves a setting with a date
///
/// Parameters:
///  * key - A string containing the name of the setting
///  * val - A number representing seconds since `1970-01-01 00:00:00 +0000` (e.g. `os.time()`), or a string containing a date in RFC3339 format (`YYYY-MM-DD[T]HH:MM:SS[Z]`)
///
/// Returns:
///  * None
///
/// Notes:
///  * See `hs.settings.dateFormat` for a convenient representation of the RFC3339 format, to use with other time/date related functions
static int target_setDate(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    NSDate* myDate = lua_isnumber(L, 2) ? [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval) lua_tonumber(L,2)] :
                     lua_isstring(L, 2) ? date_from_string([NSString stringWithUTF8String:lua_tostring(L, 2)]) : nil ;
    if (myDate) {
        [[NSUserDefaults standardUserDefaults] setObject:myDate forKey:key];
    } else {
        luaL_error(L, "Not a date type -- Number: # of seconds since 1970-01-01 00:00:00Z or String: in the format of 'YYYY-MM-DD[T]HH:MM:SS[Z]' (rfc3339)") ;
    }
    return 0 ;
}

/// hs.settings.get(key) -> string or boolean or number or nil or table or binary data
/// Function
/// Loads a setting
///
/// Parameters:
///  * key - A string containing the name of the setting
///
/// Returns:
///  * The value of the setting
///
/// Notes:
///  * This function can load all of the datatypes supported by `hs.settings.set()`, `hs.settings.setData()` and `hs.settings.setDate()`
static int target_get(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSObject_to_lua(L, val);
    return 1;
}

/// hs.settings.clear(key) -> bool
/// Function
/// Deletes a setting
///
/// Parameters:
///  * key - A string containing the name of a setting
///
/// Returns:
///  * A boolean, true if the setting was deleted, otherwise false
static int target_clear(lua_State* L) {
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:key] && ![[NSUserDefaults standardUserDefaults] objectIsForcedForKey:key]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        lua_pushboolean(L, YES) ;
    } else
        lua_pushboolean(L, NO) ;
    return 1;
}

/// hs.settings.getKeys() -> table
/// Function
/// Gets all of the previously stored setting names
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing all of the settings keys in Hammerspoon's settings
///
/// Notes:
///  * Use `ipairs(hs.settings.getKeys())` to iterate over all available settings
///  * Use `hs.settings.getKeys()["someKey"]` to test for the existance of a particular key
static int target_getKeys(lua_State* L) {
    NSArray *keys = [[[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] allKeys];
    lua_newtable(L);
    for (unsigned long i = 0; i < keys.count; i++) {
        lua_pushnumber(L, i+1) ;
        NSObject_to_lua(L, [keys objectAtIndex:i]);
        lua_settable(L, -3);
        NSObject_to_lua(L, [keys objectAtIndex:i]);
        lua_pushboolean(L, YES) ;
        lua_settable(L, -3);
    }
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg settingslib[] = {
    {"set",         target_set},
    {"setData",    target_setData},
    {"setDate",    target_setDate},
    {"get",         target_get},
    {"clear",       target_clear},
    {"getKeys",     target_getKeys},
    {NULL, NULL}
};

int luaopen_settings(lua_State* L) {
    // setup the module
    luaL_newlib(L, settingslib);

/// hs.settings.dateFormat
/// Constant
/// A string representing the expected format of date and time when presenting the date and time as a string to `hs.setDate()`.  e.g. `os.date(hs.settings.dateFormat)`
        lua_pushstring(L, "!%Y-%m-%dT%H:%M:%SZ") ;
        lua_setfield(L, -2, "dateFormat") ;

/// hs.settings.bundleID
/// Constant
/// A string representing the ID of the bundle Hammerspoon's settings are stored in . You can use this with the command line tool `defaults` or other tools which allow access to the `User Defaults` of applications, to access these outside of Hammerspoon
        lua_pushstring(L, [[[NSBundle mainBundle] bundleIdentifier] UTF8String]) ;
        lua_setfield(L, -2, "bundleID") ;

    return 1;
}
