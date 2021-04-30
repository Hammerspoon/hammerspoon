@import Cocoa ;
@import LuaSkin ;
@import SystemConfiguration ;
@import SystemConfiguration.SCDynamicStoreCopyDHCPInfo ;

#define USERDATA_TAG    "hs.network.configuration"
static LSRefTable       refTable          = LUA_NOREF;
static dispatch_queue_t dynamicStoreQueue = nil ;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _dynamicstore_t {
    SCDynamicStoreRef storeObject;
    int               callbackRef ;
    int               selfRef ;
    BOOL              watcherEnabled ;
    LSGCCanary            lsCanary;
} dynamicstore_t;

static void doDynamicStoreCallback(__unused SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    dynamicstore_t *thePtr = (dynamicstore_t *)info ;
    NSArray *nsChangedKeys = [(__bridge NSArray *)changedKeys copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ((thePtr->callbackRef != LUA_NOREF) && (thePtr->selfRef != LUA_NOREF)) {
            LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
            lua_State *L    = [skin L] ;
            if (![skin checkGCCanary:thePtr->lsCanary]) {
                return;
            }
            _lua_stackguard_entry(L);
            [skin pushLuaRef:refTable ref:thePtr->callbackRef] ;
            [skin pushLuaRef:refTable ref:thePtr->selfRef] ;
            if (changedKeys) {
                [skin pushNSObject:nsChangedKeys] ;
            } else {
                lua_pushnil(L) ;
            }
            [skin protectedCallAndError:@"hs.network.configuration callback" nargs:2 nresults:0];
            _lua_stackguard_exit(L);
        }
    }) ;
}

#pragma mark - Module Functions

/// hs.network.configuration.open() -> storeObject
/// Constructor
/// Opens a session to the dynamic store maintained by the System Configuration server.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the storeObject
static int newStoreObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    NSString *theName = [[NSUUID UUID] UUIDString] ;
    dynamicstore_t *thePtr = lua_newuserdata(L, sizeof(dynamicstore_t)) ;
    memset(thePtr, 0, sizeof(dynamicstore_t)) ;

    SCDynamicStoreContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (void *)thePtr;
    SCDynamicStoreRef theStore = SCDynamicStoreCreate(kCFAllocatorDefault, (__bridge CFStringRef)theName, doDynamicStoreCallback, &context );
    if (theStore) {
        thePtr->storeObject    = CFRetain(theStore) ;
        thePtr->callbackRef    = LUA_NOREF ;
        thePtr->selfRef        = LUA_NOREF ;
        thePtr->watcherEnabled = NO ;
        thePtr->lsCanary = [skin createGCCanary];

        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
//         SCDynamicStoreSetDispatchQueue(thePtr->storeObject, dynamicStoreQueue);
        CFRelease(theStore) ; // we retained it in the structure, so release it here
    } else {
        return luaL_error(L, "** unable to get dynamicStore reference:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.network.configuration:contents([keys], [pattern]) -> table
/// Method
/// Return the contents of the store for the specified keys or keys matching the specified pattern(s)
///
/// Parameters:
///  * keys    - a string or table of strings containing the keys or patterns of keys, if `pattern` is true.  Defaults to all keys.
///  * pattern - a boolean indicating wether or not the string(s) provided are to be considered regular expression patterns (true) or literal strings to match (false).  Defaults to false.
///
/// Returns:
///  * a table of key-value pairs from the dynamic store which match the specified keys or key patterns.
///
/// Notes:
///  * if no parameters are provided, then all key-value pairs in the dynamic store are returned.
static int dynamicStoreContents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 1) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            keys = [skin toNSObjectAtIndex:2] ;
        } else {
            keys = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
        }
        if (lua_gettop(L) == 3) keysIsPattern = (BOOL)lua_toboolean(L, 3) ;
    }

    CFDictionaryRef results ;
    if (keysIsPattern) {
        results = SCDynamicStoreCopyMultiple(theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        results = SCDynamicStoreCopyMultiple(theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get dynamicStore contents:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.configuration:keys([keypattern]) -> table
/// Method
/// Return the keys in the dynamic store which match the specified pattern
///
/// Parameters:
///  * keypattern - a regular expression specifying which keys to return (defaults to ".*", or all keys)
///
/// Returns:
///  * a table of keys from the dynamic store.
static int dynamicStoreKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSString *keys = (lua_gettop(L) == 1) ? @".*" : [skin toNSObjectAtIndex:2] ;
    CFArrayRef results = SCDynamicStoreCopyKeyList(theStore, (__bridge CFStringRef)keys);
    if (results) {
        [skin pushNSObject:(__bridge NSArray *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get dynamicStore keys:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.configuration:dhcpInfo([serviceID]) -> table
/// Method
/// Return the DHCP information for the specified service or the primary service if no parameter is specified.
///
/// Parameters:
///  * serviceID - an optional string contining the service ID of the interface for which to return DHCP info.  If this parameter is not provided, then the default (primary) service is queried.
///
/// Returns:
///  * a table containing DHCP information including lease time and DHCP options
///
/// Notes:
///  * a list of possible Service ID's can be retrieved with `hs.network.configuration:contents("Setup:/Network/Global/IPv4")`
///  * generates an error if the service ID is invalid or was not assigned an IP address via DHCP.
static int dynamicStoreDHCPInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSString *serviceID ;
    if (lua_gettop(L) == 2) {
        serviceID = [skin toNSObjectAtIndex:2] ;
    }

    CFDictionaryRef results = SCDynamicStoreCopyDHCPInfo(theStore, (__bridge CFStringRef)serviceID);
    if (results) {
        [skin pushNSObject:(__bridge NSDictionary *)results withOptions:(LS_NSDescribeUnknownTypes | LS_NSUnsignedLongLongPreserveBits)] ;
        CFRelease(results) ;
    } else {
        return luaL_error(L, "** unable to get DHCP info:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.configuration:computerName() -> name, encoding
/// Method
/// Returns the name of the computeras specified in the Sharing Preferences, and its string encoding
///
/// Parameters:
///  * None
///
/// Returns:
///  * name     - the computer name
///  * encoding - the encoding type
///
/// Notes:
///  * You can also retrieve this information as key-value pairs with `hs.network.configuration:contents("Setup:/System")`
static int dynamicStoreComputerName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringEncoding encoding ;
    CFStringRef computerName = SCDynamicStoreCopyComputerName(theStore, &encoding);
    if (computerName) {
        [skin pushNSObject:(__bridge NSString *)computerName] ;
        switch(encoding) {
            case kCFStringEncodingMacRoman:      [skin pushNSObject:@"MacRoman"] ; break ;
            case kCFStringEncodingWindowsLatin1: [skin pushNSObject:@"WindowsLatin1"] ; break ;
            case kCFStringEncodingISOLatin1:     [skin pushNSObject:@"ISOLatin1"] ; break ;
            case kCFStringEncodingNextStepLatin: [skin pushNSObject:@"NextStepLatin"] ; break ;
            case kCFStringEncodingASCII:         [skin pushNSObject:@"ASCII"] ; break ;
// alias for kCFStringEncodingUTF16; choose UTF16, since Unicode is not one specific encoding - all UTF
// types are more accurately a way to encode Unicode
//             case kCFStringEncodingUnicode:       [skin pushNSObject:@"Unicode"] ; break ;
            case kCFStringEncodingUTF8:          [skin pushNSObject:@"UTF8"] ; break ;
            case kCFStringEncodingNonLossyASCII: [skin pushNSObject:@"NonLossyASCII"] ; break ;
            case kCFStringEncodingUTF16:         [skin pushNSObject:@"UTF16"] ; break ;
            case kCFStringEncodingUTF16BE:       [skin pushNSObject:@"UTF16BE"] ; break ;
            case kCFStringEncodingUTF16LE:       [skin pushNSObject:@"UTF16LE"] ; break ;
            case kCFStringEncodingUTF32:         [skin pushNSObject:@"UTF32"] ; break ;
            case kCFStringEncodingUTF32BE:       [skin pushNSObject:@"UTF32BE"] ; break ;
            case kCFStringEncodingUTF32LE:       [skin pushNSObject:@"UTF32LE"] ; break ;
            case kCFStringEncodingInvalidId:     [skin pushNSObject:@"InvalidId"] ; break ;
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized encoding:%d", encoding]] ;
                break ;
        }
        CFRelease(computerName) ;
    } else {
        return luaL_error(L, "** error retrieving computer name:%s", SCErrorString(SCError())) ;
    }
    return 2 ;
}

/// hs.network.configuration:consoleUser() -> name, uid, gid
/// Method
/// Returns the name of the user currently logged into the system, including the users id and primary group id
///
/// Parameters:
///  * None
///
/// Returns:
///  * name - the user name
///  * uid  - the user ID for the user
///  * gid  - the user's primary group ID
///
/// Notes:
///  * You can also retrieve this information as key-value pairs with `hs.network.configuration:contents("State:/Users/ConsoleUser")`
static int dynamicStoreConsoleUser(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    uid_t uid ;
    gid_t gid ;
    CFStringRef consoleUser = SCDynamicStoreCopyConsoleUser(theStore, &uid, &gid);
    if (consoleUser) {
        [skin pushNSObject:(__bridge NSString *)consoleUser] ;
        lua_pushinteger(L, uid) ;
        lua_pushinteger(L, gid) ;
        CFRelease(consoleUser) ;
    } else {
        return luaL_error(L, "** error retrieving console user:%s", SCErrorString(SCError())) ;
    }
    return 3 ;
}

/// hs.network.configuration:hostname() -> name
/// Method
/// Returns the current local host name for the computer
///
/// Parameters:
///  * None
///
/// Returns:
///  * name - the local host name
///
/// Notes:
///  * You can also retrieve this information as key-value pairs with `hs.network.configuration:contents("Setup:/System")`
static int dynamicStoreLocalHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringRef localHostName = SCDynamicStoreCopyLocalHostName(theStore);
    if (localHostName) {
        [skin pushNSObject:(__bridge NSString *)localHostName] ;
        CFRelease(localHostName) ;
    } else {
        return luaL_error(L, "** error retrieving local host name:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

// internal stuff to make setLocation work
#define kSCPreferencesOptionChangeNetworkSet    CFSTR("change-network-set") // CFBooleanRef
SCPreferencesRef
SCPreferencesCreateWithOptions      (
                                     CFAllocatorRef      allocator,
                                     CFStringRef     name,
                                     CFStringRef     prefsID,
                                     AuthorizationRef    authorization,
                                     CFDictionaryRef options
                                     );

/// hs.network.configuration:setLocation(location) -> boolean
/// Method
/// Switches to a new location
///
/// Parameters:
///  * location - string containing name or UUID of new location
///
/// Returns:
///  * bool - true if the location was successfully changed, false if there was an error
static int dynamicStoreSetLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];

    NSString *target ;
    if (lua_gettop(L) == 2) {
        target = [skin toNSObjectAtIndex:2];
    }
    AuthorizationRef authorization = NULL;
    AuthorizationFlags flags = kAuthorizationFlagDefaults;
    OSStatus status = AuthorizationCreate(NULL,
                                          kAuthorizationEmptyEnvironment,
                                          flags,
                                          &authorization);

    if (status != errAuthorizationSuccess) {
        lua_pushboolean(L, 0);
        if(authorization) {
            AuthorizationFree(authorization, kAuthorizationFlagDestroyRights);
        }
        return 1;
    }

    CFMutableDictionaryRef options = CFDictionaryCreateMutable(NULL,
                                                               0,
                                                               &kCFTypeDictionaryKeyCallBacks,
                                                               &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(options, kSCPreferencesOptionChangeNetworkSet, kCFBooleanTrue);

    SCPreferencesRef prefs = SCPreferencesCreateWithOptions(NULL, CFSTR("SystemConfiguration"), NULL, authorization, options);
    if(!prefs) {
        lua_pushboolean(L, 0);
        AuthorizationFree(authorization, kAuthorizationFlagDestroyRights);
        CFRelease(options);
        return 1;
    }

    CFArrayRef locations = SCNetworkSetCopyAll(prefs);
    if(!locations) {
        lua_pushboolean(L, 0);
        AuthorizationFree(authorization, kAuthorizationFlagDestroyRights);
        CFRelease(options);
        CFRelease(prefs);
        return 1;
    }

    CFIndex i, c = CFArrayGetCount(locations);

    bool success=false;

    for (i=0; i<c; i++) {
        SCNetworkSetRef item = CFArrayGetValueAtIndex(locations, i);

        CFStringRef name = SCNetworkSetGetName((SCNetworkSetRef)item);
        CFStringRef uuid = SCNetworkSetGetSetID((SCNetworkSetRef)item);
        if ((CFStringCompare(name, (CFStringRef)target, 0) == kCFCompareEqualTo) || (CFStringCompare(uuid,(CFStringRef)target, 0) == kCFCompareEqualTo)) {
            bool res = SCNetworkSetSetCurrent((SCNetworkSetRef)item);
            bool res2 = SCPreferencesCommitChanges(prefs);
            bool res3 = SCPreferencesApplyChanges(prefs);
            success = res || res2 || res3;
            break;
        }
    }
    lua_pushboolean(L, success);
    AuthorizationFree(authorization, kAuthorizationFlagDestroyRights);
    CFRelease(options);
    CFRelease(prefs);
    CFRelease(locations);

    return 1;
}

/// hs.network.configuration:location() -> location
/// Method
/// Returns the current location identifier
///
/// Parameters:
///  * None
///
/// Returns:
///  * location - the UUID for the currently active network location
///
/// Notes:
///  * You can also retrieve this information as key-value pairs with `hs.network.configuration:contents("Setup:")`
///  * If you have different locations defined in the Network preferences panel, this can be used to determine the currently active location.
static int dynamicStoreLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFStringRef location = SCDynamicStoreCopyLocation(theStore);
    if (location) {
        [skin pushNSObject:(__bridge NSString *)location] ;
        CFRelease(location) ;
    } else {
        return luaL_error(L, "** error retrieving location:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.configuration:locations() -> table
/// Method
/// Returns all configured locations
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs mapping location UUIDs to their names
///
static int dynamicStoreLocations(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("Hammerspoon"), NULL);

    if(!prefs) { lua_pushnil(L); return 1; }

    CFArrayRef locations = SCNetworkSetCopyAll(prefs);
    if(!locations) { lua_pushnil(L); CFRelease(prefs); return 1; }

    CFIndex i, c = CFArrayGetCount(locations);
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    for (i=0; i<c; i++) {
        SCNetworkSetRef location = CFArrayGetValueAtIndex(locations, i);
        CFStringRef setID = SCNetworkSetGetSetID(location);
        CFStringRef name = SCNetworkSetGetName(location);
        dict[(__bridge NSString*) setID] = (__bridge NSString *)(name);
    }
    [skin pushNSObject:dict];

    CFRelease(prefs);
    CFRelease(locations);
    return 1 ;
}

/// hs.network.configuration:proxies() -> table
/// Method
/// Returns information about the currently active proxies, if any
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of key-value pairs describing the current proxies in effect, both globally, and scoped to specific interfaces.
///
/// Notes:
///  * You can also retrieve this information as key-value pairs with `hs.network.configuration:contents("State:/Network/Global/Proxies")`
static int dynamicStoreProxies(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    CFDictionaryRef proxies = SCDynamicStoreCopyProxies(theStore);
    if (proxies) {
        [skin pushNSObject:(__bridge NSDictionary *)proxies] ;
        CFRelease(proxies) ;
    } else {
        return luaL_error(L, "** error retrieving proxies:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.configuration:setCallback(function) -> storeObject
/// Method
/// Set or remove the callback function for a store object
///
/// Parameters:
///  * a function or nil to set or remove the store object callback function
///
/// Returns:
///  * the store object
///
/// Notes:
///  * The callback function will be invoked each time a monitored key changes value and the callback function should accept two parameters: the storeObject itself, and an array of the keys which contain values that have changed.
///  * This method just sets the callback function.  You specify which keys to watch with [hs.network.configuration:monitorKeys](#monitorKeys) and start or stop the watcher with [hs.network.configuration:start](#start) or [hs.network.configuartion:stop](#stop)
static int dynamicStoreSetCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;

    // in either case, we need to remove an existing callback, so...
    thePtr->callbackRef = [skin luaUnref:refTable ref:thePtr->callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        thePtr->callbackRef = [skin luaRef:refTable];
        if (thePtr->selfRef == LUA_NOREF) {               // make sure that we won't be __gc'd if a callback exists
            lua_pushvalue(L, 1) ;                         // but the user doesn't save us somewhere
            thePtr->selfRef = [skin luaRef:refTable];
        }
    } else {
        thePtr->selfRef = [skin luaUnref:refTable ref:thePtr->selfRef] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.configuration:start() -> storeObject
/// Method
/// Starts watching the store object for changes to the monitored keys and invokes the callback function (if any) when a change occurs.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the store object
///
/// Notes:
///  * The callback function should be specified with [hs.network.configuration:setCallback](#setCallback) and the keys to monitor should be specified with [hs.network.configuration:monitorKeys](#monitorKeys).
static int dynamicStoreStartWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (!thePtr->watcherEnabled) {
        if (SCDynamicStoreSetDispatchQueue(thePtr->storeObject, dynamicStoreQueue)) {
            thePtr->watcherEnabled = YES ;
        } else {
            return luaL_error(L, "unable to set watcher dispatch queue:%s", SCErrorString(SCError())) ;
        }
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.configuration:stop() -> storeObject
/// Method
/// Stops watching the store object for changes.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the store object
static int dynamicStoreStopWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (!SCDynamicStoreSetDispatchQueue(thePtr->storeObject, NULL)) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"%s:stop, error removing watcher from dispatch queue:%s",
                                                USERDATA_TAG, SCErrorString(SCError())]] ;
    }
    thePtr->watcherEnabled = NO ;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.configuration:monitorKeys([keys], [pattern]) -> storeObject
/// Method
/// Specify the key(s) or key pattern(s) to monitor for changes.
///
/// Parameters:
///  * keys    - a string or table of strings containing the keys or patterns of keys, if `pattern` is true.  Defaults to all keys.
///  * pattern - a boolean indicating wether or not the string(s) provided are to be considered regular expression patterns (true) or literal strings to match (false).  Defaults to false.
///
/// Returns:
///  * the store Object
///
/// Notes:
///  * if no parameters are provided, then all key-value pairs in the dynamic store are monitored for changes.
static int dynamicStoreMonitorKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TTABLE | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;

    NSArray *keys ;
    BOOL keysIsPattern = NO ;
    if (lua_gettop(L) == 1) {
        keys = @[ @".*" ] ;
        keysIsPattern = YES ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            keys = [skin toNSObjectAtIndex:2] ;
        } else {
            keys = [NSArray arrayWithObject:[skin toNSObjectAtIndex:2]] ;
        }
        if (lua_gettop(L) == 3) keysIsPattern = (BOOL)lua_toboolean(L, 3) ;
    }

    Boolean result ;
    if (keysIsPattern) {
        result = SCDynamicStoreSetNotificationKeys(theStore, NULL, (__bridge CFArrayRef)keys);
    } else {
        result = SCDynamicStoreSetNotificationKeys(theStore, (__bridge CFArrayRef)keys, NULL);
    }
    if (result) {
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_error(L, "** unable to set keys to monitor:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     SCDynamicStoreRef theStore = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCDynamicStoreRef theStore1 = get_structFromUserdata(dynamicstore_t, L, 1)->storeObject ;
        SCDynamicStoreRef theStore2 = get_structFromUserdata(dynamicstore_t, L, 2)->storeObject ;
        lua_pushboolean(L, CFEqual(theStore1, theStore2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin logDebug:@"dynamicstore GC"] ;
    dynamicstore_t* thePtr = get_structFromUserdata(dynamicstore_t, L, 1) ;
    if (thePtr->callbackRef != LUA_NOREF) {
        thePtr->callbackRef = [skin luaUnref:refTable ref:thePtr->callbackRef] ;
        if (!SCDynamicStoreSetDispatchQueue(thePtr->storeObject, NULL)) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"%s:__gc, error removing watcher from dispatch queue:%s",
                                                            USERDATA_TAG, SCErrorString(SCError())]] ;
        }
    }
    thePtr->selfRef = [skin luaUnref:refTable ref:thePtr->selfRef] ;
    [skin destroyGCCanary:&(thePtr->lsCanary)];

    CFRelease(thePtr->storeObject) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    dynamicStoreQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"contents",     dynamicStoreContents},
    {"keys",         dynamicStoreKeys},
    {"dhcpInfo",     dynamicStoreDHCPInfo},
    {"computerName", dynamicStoreComputerName},
    {"consoleUser",  dynamicStoreConsoleUser},
    {"hostname",     dynamicStoreLocalHostName},
    {"location",     dynamicStoreLocation},
    {"locations",    dynamicStoreLocations},
    {"proxies",      dynamicStoreProxies},
    {"monitorKeys",  dynamicStoreMonitorKeys},
    {"setCallback",  dynamicStoreSetCallback},
    {"setLocation",  dynamicStoreSetLocation},
    {"start",        dynamicStoreStartWatcher},
    {"stop",         dynamicStoreStopWatcher},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"open", newStoreObject},
    {NULL,   NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_network_configurationinternal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    dynamicStoreQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    return 1;
}
