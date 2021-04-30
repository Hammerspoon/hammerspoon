@import Cocoa ;
@import LuaSkin ;
@import CFNetwork ;
@import SystemConfiguration ;

@import Darwin.POSIX.netinet.in ;
@import Darwin.POSIX.netdb ;

#define USERDATA_TAG    "hs.network.host"
static LSRefTable       refTable          = LUA_NOREF;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _hshost_t {
    CFHostRef      theHostObj ;
    int            callbackRef ;
    CFHostInfoType resolveType ;
    int            selfRef ;
    BOOL           running ;
    LSGCCanary         lsCanary;
} hshost_t;

static int pushCFHost(lua_State *L, CFHostRef theHost, CFHostInfoType resolveType) {
    LuaSkin   *skin    = [LuaSkin sharedWithState:L] ;
    hshost_t* thePtr = lua_newuserdata(L, sizeof(hshost_t)) ;
    memset(thePtr, 0, sizeof(hshost_t)) ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
// CFRetain returns CFTypeRef (aka 'const void *'), while CFHostRef (aka 'struct __CFHost *'),
// a noticeably non-constant type...
// Probably an oversite on Apple's part since other CF type refs don't trigger a warning.
    thePtr->theHostObj  = CFRetain(theHost) ;
#pragma clang diagnostic pop
    thePtr->callbackRef = LUA_NOREF ;
    thePtr->resolveType = resolveType ;
    thePtr->selfRef     = LUA_NOREF ;
    thePtr->running     = NO ;
    thePtr->lsCanary = [skin createGCCanary];

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    // capture reference so __gc doesn't accidentally collect before callback if they don't save a reference to the object
    lua_pushvalue(L, -1) ;
    thePtr->selfRef = [skin luaRef:refTable] ;
    return 1 ;
}

static int pushQueryResults(lua_State *L, BOOL syncronous, CFHostRef theHost, CFHostInfoType typeInfo) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    Boolean available = false ;
    int argCount = syncronous ? 1 : 2 ;
    switch(typeInfo) {
        case kCFHostAddresses:
            if (!syncronous) lua_pushstring(L, "addresses") ;
            CFArrayRef theAddresses = CFHostGetAddressing(theHost, &available);
            if (available && theAddresses) {
                lua_newtable(L) ;
                for (CFIndex i = 0 ; i < CFArrayGetCount(theAddresses) ; i++) {
                    NSData *thisAddr = (__bridge NSData *)CFArrayGetValueAtIndex(theAddresses, i) ;
                    int  err;
                    char addrStr[NI_MAXHOST];
                    err = getnameinfo((const struct sockaddr *) [thisAddr bytes], (socklen_t) [thisAddr length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
                    if (err == 0) {
                        lua_pushstring(L, addrStr) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                    } else {
                        lua_pushfstring(L, "** error:%s", gai_strerror(err)) ;
                    }
                }
            } else {
                lua_pushnil(L) ;
            }
            break ;
        case kCFHostNames:
            if (!syncronous) lua_pushstring(L, "names") ;
            CFArrayRef theNames = CFHostGetNames(theHost, &available);
            if (available && theNames) {
                [skin pushNSObject:(__bridge NSArray *)theNames] ;
            } else {
                lua_pushnil(L) ;
            }
            break ;
        case kCFHostReachability:
            if (!syncronous) lua_pushstring(L, "reachability") ;
            CFDataRef theAvailability = CFHostGetReachability(theHost, &available);
            if (available && theAvailability) {
//                 SCNetworkConnectionFlags flags = *(SCNetworkConnectionFlags *)CFDataGetBytePtr(theAvailability) ;
//                 lua_pushinteger(L, *flags) ;
                SCNetworkConnectionFlags flags ;
                CFDataGetBytes(theAvailability, CFRangeMake(0, sizeof(flags)), (UInt8 *)&flags) ;
                lua_pushinteger(L, flags) ;
            } else {
                lua_pushnil(L) ;
            }
            break ;
        default:
            lua_pushfstring(L, "** unknown:%d", typeInfo) ;
            argCount = 1 ;
            break ;
    }
    return argCount ;
}

static NSString *expandCFStreamError(CFStreamErrorDomain domain, SInt32 errorNum) {
    NSString *ErrorString ;
    if (domain == kCFStreamErrorDomainNetDB) {
        ErrorString = [NSString stringWithFormat:@"Error domain:NetDB, message:%s", gai_strerror(errorNum)] ;
    } else if (domain == kCFStreamErrorDomainNetServices) {
        ErrorString = [NSString stringWithFormat:@"Error domain:NetServices, code:%d (see CFNetServices.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainMach) {
        ErrorString = [NSString stringWithFormat:@"Error domain:Mach, code:%d (see mach/error.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainFTP) {
        ErrorString = [NSString stringWithFormat:@"Error domain:FTP, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainHTTP) {
        ErrorString = [NSString stringWithFormat:@"Error domain:HTTP, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSOCKS) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SOCKS, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSystemConfiguration) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SystemConfiguration, code:%d (see SystemConfiguration.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainSSL) {
        ErrorString = [NSString stringWithFormat:@"Error domain:SSL, code:%d (see SecureTransport.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainWinSock) {
        ErrorString = [NSString stringWithFormat:@"Error domain:WinSock, code:%d (see winsock2.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainCustom) {
        ErrorString = [NSString stringWithFormat:@"Error domain:Custom, code:%d", errorNum] ;
    } else if (domain == kCFStreamErrorDomainPOSIX) {
        ErrorString = [NSString stringWithFormat:@"Error domain:POSIX, code:%d (see errno.h)", errorNum] ;
    } else if (domain == kCFStreamErrorDomainMacOSStatus) {
        ErrorString = [NSString stringWithFormat:@"Error domain:MacOSStatus, code:%d (see MacErrors.h)", errorNum] ;
    } else {
        ErrorString = [NSString stringWithFormat:@"Unknown domain:%ld, code:%d", domain, errorNum] ;
    }
    return ErrorString ;
}

void handleCallback(__unused CFHostRef theHost, __unused CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    hshost_t *theRef = (hshost_t *)info ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
    CFStreamErrorDomain domain = 0 ;
#pragma clang diagnostic pop
    SInt32              errorNum = 0 ;
    if (error) {
        domain   = error->domain ;
        errorNum = error->error ;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        if (theRef->callbackRef != LUA_NOREF) {
            lua_State *L = [skin L] ;
            if (![skin checkGCCanary:theRef->lsCanary]) {
                return;
            }
            _lua_stackguard_entry(L);
            int       argCount ;
            [skin pushLuaRef:refTable ref:theRef->callbackRef] ;
            if ((domain == 0) && (errorNum == 0)) {
                argCount = pushQueryResults(L, NO, theRef->theHostObj, theRef->resolveType) ;
            } else {
                [skin pushNSObject:[NSString stringWithFormat:@"resolution error:%@", expandCFStreamError(domain, errorNum)]] ;
                argCount = 1 ;
            }
            [skin protectedCallAndError:@"hs.network.host callback" nargs:argCount nresults:0];
            _lua_stackguard_exit(L);
        }
        CFHostSetClient(theRef->theHostObj, NULL, NULL );
        CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFHostCancelInfoResolution(theRef->theHostObj, theRef->resolveType);
        theRef->running = NO ;
        // allow __gc when their stored version goes away
        if (theRef->selfRef != LUA_NOREF) {
            theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
        }
    }) ;
}

static int commonConstructor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;

    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    CFStreamError streamError ;
    int argCount = 1 ;
    if (lua_type(L, 2) == LUA_TNIL) {
        theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ; // no need for hanging around - no function callback
        if (CFHostStartInfoResolution(theRef->theHostObj, theRef->resolveType, &streamError)) {
            argCount = pushQueryResults(L, YES, theRef->theHostObj, theRef->resolveType) ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"resolution error:%@", expandCFStreamError(streamError.domain, streamError.error)] UTF8String]) ;
        }
    } else {
        lua_pushvalue(L, 2);
        theRef->callbackRef = [skin luaRef:refTable];
        CFHostClientContext context = { 0, NULL, NULL, NULL, NULL };
        context.info = (void *)theRef;
        if (CFHostSetClient(theRef->theHostObj, handleCallback, &context)) {
            CFHostScheduleWithRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            if (CFHostStartInfoResolution(theRef->theHostObj, theRef->resolveType, &streamError)) {
                theRef->running = YES;
                lua_pushvalue(L, 1) ;
            } else {
                CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
                return luaL_error(L, [[NSString stringWithFormat:@"resolution error:%@", expandCFStreamError(streamError.domain, streamError.error)] UTF8String]) ;
            }
        } else {
            theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int commonForHostName(lua_State *L, CFHostInfoType resolveType) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL syncronous = lua_isnoneornil(L, 2) ;

    CFHostRef theHost = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)[skin toNSObjectAtIndex:1]);

    lua_pushcfunction(L, commonConstructor) ;
    pushCFHost(L, theHost, resolveType) ;
    CFRelease(theHost) ;
    if (!syncronous) {
        lua_pushvalue(L, 2) ;
    } else {
        lua_pushnil(L) ;
    }
    lua_call(L, 2, 1) ; // error as if the error occurred here
    return 1 ;
}

static int commonForAddress(lua_State *L, CFHostInfoType resolveType) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL syncronous = lua_isnoneornil(L, 2) ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV | AI_V4MAPPED_CFG, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results);
    if (ecode != 0) {
        if (results) freeaddrinfo(results) ;
        return luaL_error(L, "address parse error: %s", gai_strerror(ecode)) ;
    }

    CFDataRef theSocket =  CFDataCreate(kCFAllocatorDefault, (void *)results->ai_addr, results->ai_addrlen);
    CFHostRef theHost   = CFHostCreateWithAddress (kCFAllocatorDefault, theSocket);
    lua_pushcfunction(L, commonConstructor) ;
    pushCFHost(L, theHost, resolveType) ;
    CFRelease(theSocket) ;
    CFRelease(theHost) ;
    freeaddrinfo(results) ;
    if (!syncronous) {
        lua_pushvalue(L, 2) ;
    } else {
        lua_pushnil(L) ;
    }
    lua_call(L, 2, 1) ; // error as if the error occurred here
    return 1 ;
}

#pragma mark - Module Functions

/// hs.network.host.addressesForHostname(name[, fn]) -> table | hostObject
/// Function
/// Get IP addresses for the hostname specified.
///
/// Parameters:
///  * name - the hostname to lookup IP addresses for
///  * fn   - an optional callback function which, when provided, will perform the address resolution in an asynchronous, non-blocking manner.
///
/// Returns:
///  * If this function is called without a callback function, returns a table containing the IP addresses for the specified name.  If a callback function is specified, then a host object is returned.
///
/// Notes:
///  * If no callback function is provided, the resolution occurs in a blocking manner which may be noticeable when network access is slow or erratic.
///  * If a callback function is provided, this function acts as a constructor, returning a host object and the callback function will be invoked when resolution is complete.  The callback function should take two parameters: the string "addresses", indicating that an address resolution occurred, and a table containing the IP addresses identified.
///  * Generates an error if network access is currently disabled or the hostname is invalid.
static int getAddressesForHostName(lua_State *L) {
    return commonForHostName(L, kCFHostAddresses) ;
}

/// hs.network.host.hostnamesForAddress(address[, fn]) -> table | hostObject
/// Function
/// Get hostnames for the IP address specified.
///
/// Parameters:
///  * address - a string or number representing an IPv4 or IPv6 network address to lookup hostnames for.  If the argument is a number, it is treated as the 32 bit numerical representation of an IPv4 address.
///  * fn      - an optional callback function which, when provided, will perform the hostname resolution in an asynchronous, non-blocking manner.
///
/// Returns:
///  * If this function is called without a callback function, returns a table containing the hostnames for the specified address.  If a callback function is specified, then a host object is returned.
///
/// Notes:
///  * If no callback function is provided, the resolution occurs in a blocking manner which may be noticeable when network access is slow or erratic.
///  * If a callback function is provided, this function acts as a constructor, returning a host object and the callback function will be invoked when resolution is complete.  The callback function should take two parameters: the string "names", indicating that hostname resolution occurred, and a table containing the hostnames identified.
///  * Generates an error if network access is currently disabled or the IP address is invalid.
static int getNamesForAddress(lua_State *L) {
    return commonForAddress(L, kCFHostNames) ;
}

/// hs.network.host.reachabilityForAddress(address[, fn]) -> integer | hostObject
/// Function
/// Get the reachability status for the IP address specified.
///
/// Parameters:
///  * address - a string or number representing an IPv4 or IPv6 network address to check the reachability for.  If the argument is a number, it is treated as the 32 bit numerical representation of an IPv4 address.
///  * fn      - an optional callback function which, when provided, will determine the address reachability in an asynchronous, non-blocking manner.
///
/// Returns:
///  * If this function is called without a callback function, returns the numeric representation of the address reachability status.  If a callback function is specified, then a host object is returned.
///
/// Notes:
///  * If no callback function is provided, the resolution occurs in a blocking manner which may be noticeable when network access is slow or erratic.
///  * If a callback function is provided, this function acts as a constructor, returning a host object and the callback function will be invoked when resolution is complete.  The callback function should take two parameters: the string "reachability", indicating that reachability was determined, and the numeric representation of the address reachability status.
///  * Generates an error if network access is currently disabled or the IP address is invalid.
///  * The numeric representation is made up from a combination of the flags defined in `hs.network.reachability.flags`.
///  * Performs the same reachability test as `hs.network.reachability.forAddress`.
static int getReachabilityForAddress(lua_State *L) {
    return commonForAddress(L, kCFHostReachability) ;
}

/// hs.network.host.reachabilityForHostname(name[, fn]) -> integer | hostObject
/// Function
/// Get the reachability status for the IP address specified.
///
/// Parameters:
///  * name - the hostname to check the reachability for.  If the argument is a number, it is treated as the 32 bit numerical representation of an IPv4 address.
///  * fn   - an optional callback function which, when provided, will determine the address reachability in an asynchronous, non-blocking manner.
///
/// Returns:
///  * If this function is called without a callback function, returns the numeric representation of the hostname reachability status.  If a callback function is specified, then a host object is returned.
///
/// Notes:
///  * If no callback function is provided, the resolution occurs in a blocking manner which may be noticeable when network access is slow or erratic.
///  * If a callback function is provided, this function acts as a constructor, returning a host object and the callback function will be invoked when resolution is complete.  The callback function should take two parameters: the string "reachability", indicating that reachability was determined, and the numeric representation of the hostname reachability status.
///  * Generates an error if network access is currently disabled or the IP address is invalid.
///  * The numeric representation is made up from a combination of the flags defined in `hs.network.reachability.flags`.
///  * Performs the same reachability test as `hs.network.reachability.forHostName`.
static int getReachabilityForHostName(lua_State *L) {
    return commonForHostName(L, kCFHostReachability) ;
}

#pragma mark - Module Methods

/// hs.network.host:isRunning() -> boolean
/// Method
/// Returns whether or not resolution is still in progress for an asynchronous query.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true, if resolution is still in progress, or false if resolution has already completed.
static int resolutionIsRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    lua_pushboolean(L, theRef->running) ;
    return 1 ;
}

/// hs.network.host:cancel() -> hostObject
/// Method
/// Cancels an in-progress asynchronous host resolution.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the hostObject
///
/// Notes:
///  * This method has no effect if the resolution has already completed.
static int cancelResolution(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    if (theRef->running) {
        CFHostSetClient(theRef->theHostObj, NULL, NULL );
        CFHostCancelInfoResolution(theRef->theHostObj, theRef->resolveType);
        CFHostUnscheduleFromRunLoop(theRef->theHostObj, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        theRef->running = NO ;
    }
    // allow __gc when their stored version goes away
    theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     CFHostRef theHost = get_structFromUserdata(hshost_t, L, 1)->theHostObj ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        CFHostRef theHost1 = get_structFromUserdata(hshost_t, L, 1)->theHostObj ;
        CFHostRef theHost2 = get_structFromUserdata(hshost_t, L, 2)->theHostObj ;
        lua_pushboolean(L, CFEqual(theHost1, theHost2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin logVerbose:@"in hosts __gc"] ;
    hshost_t* theRef = get_structFromUserdata(hshost_t, L, 1) ;
    theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef] ;
    // in case __gc forced by reload
    theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
    [skin destroyGCCanary:&(theRef->lsCanary)];

    lua_pushcfunction(L, cancelResolution) ;
    lua_pushvalue(L, 1) ;
    lua_pcall(L, 1, 1, 0) ;
    lua_pop(L, 1) ;

    CFRelease(theRef->theHostObj) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"isRunning",  resolutionIsRunning},
    {"cancel",     cancelResolution},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"addressesForHostname",    getAddressesForHostName},
    {"hostnamesForAddress",     getNamesForAddress},
    {"reachabilityForHostname", getReachabilityForHostName},
    {"reachabilityForAddress",  getReachabilityForAddress},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_network_hostinternal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    return 1;
}
