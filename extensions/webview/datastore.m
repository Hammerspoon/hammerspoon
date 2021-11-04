#import "webview.h"

/// === hs.webview.datastore ===
///
/// Provides methods to list and purge the various types of data used by websites visited with `hs.webview`.
///
/// This module is only available under OS X 10.11 and later.
///
/// This module allows you to list and selectively purge the types of data stored locally for the websites visited with the `hs.webview` module.  It also adds support for non-persistent datastores to `hs.webview` (private browsing) and allows a non-persistent datastore to be shared among multiple instances of `hs.webview` objects.
///
/// The datastore for a webview contains various types of data including cookies, disk and memory caches, and persistent data such as WebSQL, IndexedDB databases, and local storage.  You can use methods in this module to selectively or completely purge the common datastore (used by all Hammerspoon `hs.webview` instances that do not use a non-persistent datastore).
static LSRefTable refTable = LUA_NOREF;

static NSMutableSet *backgroundCallbacks ;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.webview.datastore.websiteDataTypes() -> table
/// Function
/// Returns a list of the currently available data types within a datastore.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a list of strings where each string is a specific data type stored in a datastore.
///
/// Notes:
///  * As of the writing of this module, the following data types are defined and returned by this function:
///    * `WKWebsiteDataTypeDiskCache`                  - On-disk caches.
///    * `WKWebsiteDataTypeOfflineWebApplicationCache` - HTML offline web application caches.
///    * `WKWebsiteDataTypeMemoryCache`                - In-memory caches.
///    * `WKWebsiteDataTypeLocalStorage`               - HTML local storage.
///    * `WKWebsiteDataTypeCookies`                    - Cookies.
///    * `WKWebsiteDataTypeSessionStorage`             - HTML session storage.
///    * `WKWebsiteDataTypeIndexedDBDatabases`         - WebSQL databases.
///    * `WKWebsiteDataTypeWebSQLDatabases`            - IndexedDB databases.
static int datastore_allWebsiteDataTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[WKWebsiteDataStore allWebsiteDataTypes]] ;
    return 1 ;
}

/// hs.webview.datastore.default() -> datastoreObject
/// Constructor
/// Returns an object representing the default datastore for Hammerspoon `hs.webview` instances.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a datastoreObject
///
/// Notes:
///  * this is the datastore used unless otherwise specified when creating an `hs.webview` instance.
static int datastore_newDefaultDataStore(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[WKWebsiteDataStore defaultDataStore]];
    return 1 ;
}

/// hs.webview.datastore.newPrivate() -> datastoreObject
/// Constructor
/// Returns an object representing a newly created non-persistent (private) datastore for use with a Hammerspoon `hs.webview` instance.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a datastoreObject
///
/// Notes:
///  * The datastore represented by this object will be initially empty.  You can use this function to create a non-persistent datastore that you wish to share among multiple `hs.webview` instances.  Once a datastore is created, you assign it to a `hs.webview` instance by including the `datastore` key in the `hs.webvew.new` constructor's preferences table and setting it equal to this key.  All webview instances created with this datastore object will share web caches, cookies, etc. but will still be isolated from the default datastore and it will be purged from memory when the webviews are deleted, or Hammerspoon is restarted.
///
///  * Using the `datastore` key in the webview's constructor differs from the `private` key -- use of the `private` key will override the `datastore` key and will create a separate non-persistent datastore for the webview instance.  See `hs.webview.new` for more information.
static int datastore_newPrivateDataStore(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[WKWebsiteDataStore nonPersistentDataStore]];
    return 1 ;
}

/// hs.webview.datastore.fromWebview(webview) -> datastoreObject
/// Constructor
/// Returns an object representing the datastore for the specified `hs.webview` instance.
///
/// Parameters:
///  * `webview` - an `hs.webview` instance (webviewObject)
///
/// Returns:
///  * a datastoreObject
///
/// Notes:
///  * When running on a system with OS X 10.11 or later, this method will also be added to the metatable for `hs.webview` objects so that you can retrieve a webview's datastore with `hs.webview:datastore()`.
///
///  * This method can be used to identify the datastore in use for a webview if you wish to create a new instance using the same datastore.
static int datastore_fromWebview(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs.webview", LS_TBREAK] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, "hs.webview") ;
    HSWebViewView          *theView = theWindow.contentView ;
    WKWebViewConfiguration *theConfiguration = [theView configuration] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    [skin pushNSObject:[theConfiguration websiteDataStore]] ;
#pragma clang diagnostic pop

    return 1 ;
}

#pragma mark - Module Methods

/// hs.webview.datastore:fetchRecords([dataTypes], callback) -> datastoreObject
/// Method
/// Generates a list of the datastore records of the specified type, and invokes the callback function with the list.
///
/// Parameters:
///  * `dataTypes` - an optional string or table specifying the data types to fetch from the datastore.  If this parameter is not specified, it defaults to the list returned by [hs.webview.datastore.websiteDataTypes](#websiteDataTypes).
///  * `callback`  - a function which accepts as it's argument an array-table containing tables with the following key-value pairs:
///    * `displayName` - a string containing the site's display name.  Typically, the display name is the domain name with suffix taken from the resource’s security origin (website name).
///    * `dataTypes`   - a table containing strings representing the types of data stored for the website specified by `displayName`.
///
/// Returns:
///  * the datastore object
///
/// Notes:
///  * only those sites with one or more of the specified data types are returned
///  * for the sites returned, only those data types that were present in the query will be included in the list, even if the site has data of another type in the datastore.
static int datastore_fetchRecords(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_DS_TAG,
                    LS_TSTRING | LS_TTABLE | LS_TFUNCTION,
                    LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;

    WKWebsiteDataStore *dataStore = [skin toNSObjectAtIndex:1] ;
    NSArray            *dataTypes = [[WKWebsiteDataStore allWebsiteDataTypes] allObjects] ;

    lua_pushvalue(L, lua_gettop(L)) ;
    int fnRef = [skin luaRef:refTable] ;
    [backgroundCallbacks addObject:@(fnRef)] ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        dataTypes = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
    } else if (lua_type(L, 2) == LUA_TTABLE) {
        dataTypes = [skin toNSObjectAtIndex:2] ;
        BOOL isGood = YES ;
        if ([dataTypes isKindOfClass:[NSArray class]]) {
            for (NSString *obj in dataTypes) {
                if (![obj isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
        } else {
            isGood = NO ;
        }
        if (!isGood) return luaL_argerror(L, 2, "expected a string or an array of string values") ;
    }

    NSSet *typeSet = [NSSet setWithArray:dataTypes] ;
    if (![typeSet isSubsetOfSet:[WKWebsiteDataStore allWebsiteDataTypes]]) {
        return luaL_argerror(L, 3, "invalid datastore data type specified") ;
    }

    [dataStore fetchDataRecordsOfTypes:typeSet completionHandler:^(NSArray *records){
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([backgroundCallbacks containsObject:@(fnRef)]) {
                LuaSkin *_skin = [LuaSkin sharedWithState:NULL] ;
                [_skin pushLuaRef:refTable ref:fnRef] ;
                [_skin pushNSObject:records] ;
                [_skin protectedCallAndError:@"hs.webview.datastore:fetchRecords callback" nargs:1 nresults:0];
                [_skin luaUnref:refTable ref:fnRef] ;
                [backgroundCallbacks removeObject:@(fnRef)] ;
            }
        }) ;
    }] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.datastore:removeRecordsFor(displayNames, dataTypes, [callback]) -> datastoreObject
/// Method
/// Remove data from the datastore of the specified type(s) for the specified site(s).
///
/// Parameters:
///  * `displayNames` - a string or array of strings specifying the display names (sites) to remove records for.
///  * `dataTypes`    - a string or array of strings specifying the types of data to remove from the datastore for the specified sites.
///  * `callback`     - an optional function, which should expect no arguments, that will be called when the specified items have been removed from the datastore.
///
/// Returns:
///  * the datastore object
///
/// Notes:
///  * to specify that all data types that qualify should be removed, specify the function  [hs.webview.datastore.websiteDataTypes()](#websiteDataTypes). as the second argument.
static int datastore_removeRecords(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_DS_TAG,
                    LS_TTABLE | LS_TSTRING,
                    LS_TTABLE | LS_TSTRING,
                    LS_TFUNCTION | LS_TOPTIONAL,
                    LS_TBREAK] ;
    WKWebsiteDataStore *dataStore = [skin toNSObjectAtIndex:1] ;

    NSArray *recordNames ;
    NSArray *recordTypes ;
    int     fnRef = LUA_NOREF ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        recordNames = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
    } else {
        recordNames = [skin toNSObjectAtIndex:2] ;
        BOOL isGood = YES ;
        if ([recordNames isKindOfClass:[NSArray class]]) {
            for (NSString *obj in recordNames) {
                if (![obj isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
        } else {
            isGood = NO ;
        }
        if (!isGood) return luaL_argerror(L, 2, "expected a single string or an array of string values") ;
    }

    if (lua_type(L, 3) == LUA_TSTRING) {
        recordTypes = [NSArray arrayWithObject:[skin toNSObjectAtIndex:3]] ;
    } else {
        recordTypes = [skin toNSObjectAtIndex:3] ;
        BOOL isGood = YES ;
        if ([recordTypes isKindOfClass:[NSArray class]]) {
            for (NSString *obj in recordTypes) {
                if (![obj isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
        } else {
            isGood = NO ;
        }
        if (!isGood) return luaL_argerror(L, 3, "expected a single string or an array of string values") ;
    }

    NSSet *typeSet = [NSSet setWithArray:recordTypes] ;
    if (![typeSet isSubsetOfSet:[WKWebsiteDataStore allWebsiteDataTypes]]) {
        return luaL_argerror(L, 3, "invalid datastore data type specified") ;
    }

    if (lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4) ;
        fnRef = [skin luaRef:refTable] ;
        [backgroundCallbacks addObject:@(fnRef)] ;
    }

    [dataStore fetchDataRecordsOfTypes:typeSet completionHandler:^(NSArray *records){
        NSMutableArray *targets = [[NSMutableArray alloc] init] ;
        NSArray        *names   = [records valueForKey:@"displayName"] ;

        for (NSUInteger i = 0 ; i < [records count] ; i++) {
            if ([recordNames containsObject:names[i]]) {
                [targets addObject:records[i]] ;
            }
        }

        [dataStore removeDataOfTypes:typeSet forDataRecords:targets completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (fnRef != LUA_NOREF && [backgroundCallbacks containsObject:@(fnRef)]) {
                    LuaSkin *_skin = [LuaSkin sharedWithState:NULL] ;
                    [_skin pushLuaRef:refTable ref:fnRef] ;
                    [_skin protectedCallAndError:@"hs.webview.datastore:removeRecordsFor callback" nargs:0 nresults:0];
                    [_skin luaUnref:refTable ref:fnRef] ;
                    [backgroundCallbacks removeObject:@(fnRef)] ;
                }
            }) ;
        }] ;
    }] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.datastore:removeRecordsAfter(date, dataTypes, [callback]) -> datastoreObject
/// Method
/// Removes the specified types of data from the datastore if the data was added or changed since the given date.
///
/// Parameters:
///  * `date`         - an integer representing seconds since `1970-01-01 00:00:00 +0000` (e.g. `os.time()`), or a string containing a date in RFC3339 format (`YYYY-MM-DD[T]HH:MM:SS[Z]`).
///  * `dataTypes`    - a string or array of strings specifying the types of data to remove from the datastore for the specified sites.
///  * `callback`     - an optional function, which should expect no arguments, that will be called when the specified items have been removed from the datastore.
///
/// Returns:
///  * the datastore object
///
/// Notes:
///  * Yes, you read the description correctly -- removes data *newer* then the date specified.  I've not yet found a way to remove data *older* then the date specified (to expire old data, for example) but updates or suggestions are welcome in the Hammerspoon Google group or Github web site.
///
///  * to specify that all data types that qualify should be removed, specify the function  [hs.webview.datastore.websiteDataTypes()](#websiteDataTypes). as the second argument.
///
///  * For example, to purge the Hammerspoon default datastore of all data, you can do the following:
/// ~~~
/// hs.webview.datastore.default():removeRecordsAfter(0, hs.webview.datastore.websiteDataTypes())
/// ~~~
static int datastore_removeDataFrom(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_DS_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TSTRING,
                    LS_TTABLE | LS_TSTRING,
                    LS_TFUNCTION | LS_TOPTIONAL,
                    LS_TBREAK] ;
    WKWebsiteDataStore *dataStore = [skin toNSObjectAtIndex:1] ;

    NSDate  *theDate ;
    NSArray *recordTypes ;
    int     fnRef = LUA_NOREF ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init] ;
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] ;
        [rfc3339DateFormatter setLocale:enUSPOSIXLocale] ;
        [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"] ;
        [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]] ;
        theDate = [rfc3339DateFormatter dateFromString:[skin toNSObjectAtIndex:2]] ;
        if (!theDate) {
            return luaL_argerror(L, 2, "invalid date format") ;
        }
    } else {
        theDate = [NSDate dateWithTimeIntervalSince1970:lua_tointeger(L, 2)] ;
    }

    if (lua_type(L, 3) == LUA_TSTRING) {
        recordTypes = [NSArray arrayWithObject:[skin toNSObjectAtIndex:3]] ;
    } else {
        recordTypes = [skin toNSObjectAtIndex:3] ;
        BOOL isGood = YES ;
        if ([recordTypes isKindOfClass:[NSArray class]]) {
            for (NSString *obj in recordTypes) {
                if (![obj isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
        } else {
            isGood = NO ;
        }
        if (!isGood) return luaL_argerror(L, 3, "expected a single string or an array of string values") ;
    }

    NSSet *typeSet = [NSSet setWithArray:recordTypes] ;
    if (![typeSet isSubsetOfSet:[WKWebsiteDataStore allWebsiteDataTypes]]) {
        return luaL_argerror(L, 3, "invalid datastore data type specified") ;
    }

    if (lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4) ;
        fnRef = [skin luaRef:refTable] ;
        [backgroundCallbacks addObject:@(fnRef)] ;
    }


    [dataStore removeDataOfTypes:typeSet modifiedSince:theDate completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fnRef != LUA_NOREF && [backgroundCallbacks containsObject:@(fnRef)]) {
                LuaSkin *_skin = [LuaSkin sharedWithState:NULL] ;
                [_skin pushLuaRef:refTable ref:fnRef] ;
                [_skin protectedCallAndError:@"hs.webview.datastore:removeRecordsAfter callback" nargs:0 nresults:0];
                [_skin luaUnref:refTable ref:fnRef] ;
                [backgroundCallbacks removeObject:@(fnRef)] ;
            }
        }) ;
    }] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.datastore:persistent() -> bool
/// Method
/// Returns whether or not the datastore is persistent.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not the datastore is persistent (true) or private (false)
///
/// Notes:
///  * Note that this value is the inverse of `hs.webview:privateBrowsing()`, since private browsing uses a non-persistent datastore.
static int datastore_persistent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_DS_TAG, LS_TBREAK] ;
    WKWebsiteDataStore *dataStore = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, dataStore.persistent) ;
    return 1;
}
#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushWKWebsiteDataStore(lua_State *L, id obj) {
    WKWebsiteDataStore *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(WKWebsiteDataStore *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_DS_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushWKWebsiteDataRecord(lua_State *L, id obj) {
    LuaSkin             *skin  = [LuaSkin sharedWithState:L] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    WKWebsiteDataRecord *value = obj;
#pragma clang diagnostic pop


    lua_newtable(L) ;
    [skin pushNSObject:[value displayName]] ; lua_setfield(L, -2, "displayName") ;
    [skin pushNSObject:[value dataTypes]] ;   lua_setfield(L, -2, "dataTypes") ;

    return 1;
}

static id toWKWebsiteDataStoreFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKWebsiteDataStore *value ;
    if (luaL_testudata(L, idx, USERDATA_DS_TAG)) {
        value = get_objectFromUserdata(__bridge WKWebsiteDataStore, L, idx, USERDATA_DS_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_DS_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKWebsiteDataStore *obj = [skin luaObjectAtIndex:1 toClass:"WKWebsiteDataStore"] ;
    NSString *title = [obj isPersistent] ? @"persistent" : @"non-persistent" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_DS_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_DS_TAG) && luaL_testudata(L, 2, USERDATA_DS_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        WKWebsiteDataStore *obj1 = [skin luaObjectAtIndex:1 toClass:"WKWebsiteDataStore"] ;
        WKWebsiteDataStore *obj2 = [skin luaObjectAtIndex:2 toClass:"WKWebsiteDataStore"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    WKWebsiteDataStore *obj = get_objectFromUserdata(__bridge_transfer WKWebsiteDataStore, L, 1, USERDATA_DS_TAG) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [backgroundCallbacks enumerateObjectsUsingBlock:^(NSNumber *ref, __unused BOOL *stop) {
        [skin luaUnref:refTable ref:ref.intValue] ;
    }] ;
    [backgroundCallbacks removeAllObjects] ;
    return 0;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"fetchRecords",       datastore_fetchRecords},
    {"removeRecordsFor",   datastore_removeRecords},
    {"removeRecordsAfter", datastore_removeDataFrom},
    {"persistent",         datastore_persistent},

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"websiteDataTypes", datastore_allWebsiteDataTypes},
    {"default",          datastore_newDefaultDataStore},
    {"newPrivate",       datastore_newPrivateDataStore},
    {"fromWebview",      datastore_fromWebview},

    {NULL,               NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_libwebviewdatastore(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (!NSClassFromString(@"WKWebsiteDataStore")) {
        [skin logError:[NSString stringWithFormat:@"%s requires WKWebsiteDataStore support, found in OS X 10.11 or newer", USERDATA_DS_TAG]] ;
        // nil gets interpreted as "nothing" and thus "true" by require...
        lua_pushboolean(L, NO) ;
    } else {
        refTable = [skin registerLibraryWithObject:USERDATA_DS_TAG
                                         functions:moduleLib
                                     metaFunctions:module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:pushWKWebsiteDataStore         forClass:"WKWebsiteDataStore"];
        [skin registerPushNSHelper:pushWKWebsiteDataRecord        forClass:"WKWebsiteDataRecord"] ;

        [skin registerLuaObjectHelper:toWKWebsiteDataStoreFromLua forClass:"WKWebsiteDataStore"
                                                 withUserdataMapping:USERDATA_DS_TAG];
    }
    backgroundCallbacks = [NSMutableSet set] ;
    return 1;
}
