@import Cocoa ;
@import LuaSkin ;

// establish a unique context for identifying our observers
//static const char * const USERDATA_TAG = "hs.settings" ;
static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/
static LSRefTable refTable = LUA_NOREF ;

@interface HSUserDefaultKVOWatcher : NSObject ;
@property NSMutableDictionary *watchedKeys ;
@end

@implementation HSUserDefaultKVOWatcher
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _watchedKeys = [[NSMutableDictionary alloc] init] ;
    }
    return self ;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != myKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
//     [LuaSkin logWarn:[NSString stringWithFormat:@"in observeValueForKeyPath for %@ with %@", keyPath, change]] ;
    if (context == myKVOContext && _watchedKeys && _watchedKeys[keyPath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *fnCallbacks = self->_watchedKeys[keyPath] ;
            //         [LuaSkin logWarn:[NSString stringWithFormat:@"in callback for %@ with %@", keyPath, fnCallbacks]] ;
            LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
            _lua_stackguard_entry(skin.L);
            [fnCallbacks enumerateKeysAndObjectsUsingBlock:^(NSString *watcherID, NSNumber *refN, __unused BOOL *stop) {
                [skin pushLuaRef:refTable ref:refN.intValue] ;
                [skin pushNSObject:keyPath] ;
                [skin protectedCallAndError:[NSString stringWithFormat:@"hs.settings:watcher %@ callback", watcherID] nargs:1 nresults:0];
            }] ;
            _lua_stackguard_exit(skin.L);
        });
    }
}

@end

static HSUserDefaultKVOWatcher *watcherManager ;

/// hs.settings.set(key[, val])
/// Function
/// Saves a setting with common datatypes
///
/// Parameters:
///  * key - A string containing the name of the setting
///  * val - An optional value for the setting. Valid datatypes are:
///    * string
///    * number
///    * boolean
///    * nil
///    * table (which may contain any of the same valid datatypes)
///
/// Returns:
///  * None
///
/// Notes:
///  * If no val parameter is provided, it is assumed to be nil
///  * This function cannot set dates or raw data types, see `hs.settings.setDate()` and `hs.settings.setData()`
///  * Assigning a nil value is equivalent to clearing the value with `hs.settings.clear`
static int target_set(lua_State* L) {
    LuaSkin * skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if (!key) return luaL_error(L, "key must be a valid UTF8 string") ;

// Allow for missing second argument for backwards compatibility with pre-LuaSkin behavior
    id val = nil ;
    if (lua_gettop(L) == 2) {
        val = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly | LS_NSRawTables] ;
    }

    @try {
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:key];
    }
    @catch(NSException *theException) {
        [NSUserDefaults resetStandardUserDefaults] ;
        return luaL_error(L, [[NSString stringWithFormat:@"%@: %@", theException.name, theException.reason] UTF8String]);
    }
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
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
        if (!key) return luaL_error(L, "key must be a valid UTF8 string") ;
        if (lua_type(L,2) == LUA_TSTRING) {
        const char* data = lua_tostring(L,2) ;
        NSUInteger sz = lua_rawlen(L, 2) ;
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
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;

    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if (!key) return luaL_error(L, "key must be a valid UTF8 string") ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if (!key) return luaL_error(L, "key must be a valid UTF8 string") ;
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    [skin pushNSObject:val] ;
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
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString* key = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    if (!key) return luaL_error(L, "key must be a valid UTF8 string") ;
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
    LuaSkin * skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    NSString *mainID = [[NSBundle mainBundle] bundleIdentifier] ;
    NSArray *keys = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:mainID] allKeys];
    lua_newtable(L);
    for (unsigned long i = 0; i < keys.count; i++) {
        lua_pushinteger(L, (lua_Integer)i+1) ;
        [skin pushNSObject:[keys objectAtIndex:i]] ;
        lua_settable(L, -3);
        [skin pushNSObject:[keys objectAtIndex:i]] ;
        lua_pushboolean(L, YES) ;
        lua_settable(L, -3);
    }
    return 1;
}

/// hs.settings.watchKey(identifier, key, [fn]) -> identifier | current value
/// Function
/// Get or set a watcher to invoke a callback when the specified settings key changes
///
/// Parameters:
///  * identifier - a required string used as an identifier for this callback
///  * key        - the settings key to watch for changes to
///  * fn         - the callback function to be invoked when the specified key changes.  If this is an explicit nil, removes the existing callback.
///
/// Returns:
///  * if a callback is set or removed, returns the identifier; otherwise returns the current callback function or nil if no callback function is currently defined.
///
/// Notes:
///  * the identifier is required so that multiple callbacks for the same key can be registered by separate modules; it's value doesn't affect what is being watched but does need to be unique between multiple watchers of the same key.
///
///  * Does not work with keys that include a period (.) in the key name because KVO uses dot notation to specify a sequence of properties.  If you know of a way to escape periods so that they are watchable as NSUSerDefault key names, please file an issue and share!
static int target_watchKey(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *watcherID = [skin toNSObjectAtIndex:1] ;
    NSString *keyPath   = [skin toNSObjectAtIndex:2] ;

    if (!watcherManager.watchedKeys[keyPath]) {
        watcherManager.watchedKeys[keyPath] = [[NSMutableDictionary alloc] init] ;
        [[NSUserDefaults standardUserDefaults] addObserver:watcherManager forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:myKVOContext] ;
    }
    NSMutableDictionary *keyWatchers = watcherManager.watchedKeys[keyPath] ;
    NSNumber *refN = keyWatchers[watcherID] ;

    if (lua_gettop(L) == 2) {
        if (refN) {
            [skin pushLuaRef:refTable ref:refN.intValue] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (refN) [skin luaUnref:refTable ref:refN.intValue] ;
        keyWatchers[watcherID] = nil ;
        if (lua_type(L, 3) != LUA_TNIL) {
            lua_pushvalue(L, 3) ;
            keyWatchers[watcherID] = @([skin luaRef:refTable]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// for debugging, should probably be removed at some point
static int output_watchers(lua_State *L) {
    [[LuaSkin sharedWithState:L] pushNSObject:watcherManager.watchedKeys] ;
    return 1 ;
}

static int meta_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [watcherManager.watchedKeys enumerateKeysAndObjectsUsingBlock:^(NSString *keyPath, NSMutableDictionary *watchers, __unused BOOL *outterStop) {
        [[NSUserDefaults standardUserDefaults] removeObserver:watcherManager forKeyPath:keyPath context:myKVOContext] ;
        [watchers enumerateKeysAndObjectsUsingBlock:^(__unused NSString *watcherID, NSNumber *refN, __unused BOOL *innerStop) {
            [skin luaUnref:refTable ref:refN.intValue] ;
        }] ;
    }] ;
    watcherManager.watchedKeys = nil ;
    watcherManager = nil ;
    return 0 ;
}

// Functions for returned object when module loads
static const luaL_Reg settingslib[] = {
    {"set",         target_set},
    {"setData",     target_setData},
    {"setDate",     target_setDate},
    {"get",         target_get},
    {"clear",       target_clear},
    {"getKeys",     target_getKeys},
    {"watchKey",    target_watchKey},
    {"_watchers",   output_watchers},
    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_libsettings(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs.settings" functions:settingslib metaFunctions:module_metaLib];

    watcherManager = [[HSUserDefaultKVOWatcher alloc] init] ;

/// hs.settings.dateFormat
/// Constant
/// A string representing the expected format of date and time when presenting the date and time as a string to `hs.setDate()`.  e.g. `os.date(hs.settings.dateFormat)`
        lua_pushstring(skin.L, "!%Y-%m-%dT%H:%M:%SZ") ;
        lua_setfield(skin.L, -2, "dateFormat") ;

/// hs.settings.bundleID
/// Constant
/// A string representing the ID of the bundle Hammerspoon's settings are stored in . You can use this with the command line tool `defaults` or other tools which allow access to the `User Defaults` of applications, to access these outside of Hammerspoon
        lua_pushstring(skin.L, [[[NSBundle mainBundle] bundleIdentifier] UTF8String]) ;
        lua_setfield(skin.L, -2, "bundleID") ;

    return 1;
}
