@import Cocoa ;
@import LuaSkin ;
@import CFNetwork ;
@import SystemConfiguration ;

@import Darwin.POSIX.netinet.in ;
@import Darwin.POSIX.netdb ;

#define USERDATA_TAG    "hs.network.reachability"
static LSRefTable       refTable          = LUA_NOREF;
static dispatch_queue_t reachabilityQueue = nil ;

#define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

typedef struct _reachability_t {
    SCNetworkReachabilityRef reachabilityObj;
    int                      callbackRef ;
    int                      selfRef ;
    BOOL                     watcherEnabled ;
    LSGCCanary                   lsCanary;
} reachability_t;

static int pushSCNetworkReachability(lua_State *L, SCNetworkReachabilityRef theRef) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    reachability_t* thePtr = lua_newuserdata(L, sizeof(reachability_t)) ;
    memset(thePtr, 0, sizeof(reachability_t)) ;

    thePtr->reachabilityObj = CFRetain(theRef) ;
    thePtr->callbackRef     = LUA_NOREF ;
    thePtr->selfRef         = LUA_NOREF ;
    thePtr->watcherEnabled  = NO ;
    thePtr->lsCanary     = [skin createGCCanary];

    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static void doReachabilityCallback(__unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    reachability_t *theRef = (reachability_t *)info ;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ((theRef->callbackRef != LUA_NOREF) && (theRef->selfRef != LUA_NOREF)) {
            LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
            lua_State *L    = [skin L] ;
            if (![skin checkGCCanary:theRef->lsCanary]) {
                return;
            }
            _lua_stackguard_entry(L);
            [skin pushLuaRef:refTable ref:theRef->callbackRef] ;
            [skin pushLuaRef:refTable ref:theRef->selfRef] ;
            lua_pushinteger(L, (lua_Integer)flags) ;
            [skin protectedCallAndError:@"hs.network.reachability" nargs:2 nresults:0];
            _lua_stackguard_exit(L);
        }
    }) ;
}

static NSString *statusString(SCNetworkReachabilityFlags flags) {
    return [NSString stringWithFormat:@"%c%c%c%c%c%c%c%c",
                (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
                (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
                (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
                (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
                (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
                (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'] ;
}

#pragma mark - Module Functions

/// hs.network.reachability.forAddress(address) -> reachabilityObject
/// Constructor
/// Returns a reachability object for the specified network address.
///
/// Parameters:
///  * address - a string or number representing an IPv4 or IPv6 network address to get or track reachability status for.  If the argument is a number, it is treated as the 32 bit numerical representation of an IPv4 address.
///
/// Returns:
///  * a reachability object for the specified network address.
///
/// Notes:
///  * this object will reflect reachability status for any interface available on the computer.  To check for reachability from a specific interface, use [hs.network.reachability.forAddressPair](#addressPair).
static int reachabilityForAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results);
    if (ecode != 0) {
        if (results) freeaddrinfo(results) ;
        return luaL_error(L, "address parse error: %s", gai_strerror(ecode)) ;
    }
    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (void *)results->ai_addr);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;
    if (results) freeaddrinfo(results) ;
    return 1 ;
}

/// hs.network.reachability.forAddressPair(localAddress, remoteAddress) -> reachabilityObject
/// Constructor
/// Returns a reachability object for the specified network address from the specified localAddress.
///
/// Parameters:
///  * localAddress - a string or number representing a local IPv4 or IPv6 network address. If the address specified is not present on the computer, the remote address will be unreachable.
///  * remoteAddress - a string or number representing an IPv4 or IPv6 network address to get or track reachability status for.  If the argument is a number, it is treated as the 32 bit numerical representation of an IPv4 address.
///
/// Returns:
///  * a reachability object for the specified network address.
///
/// Notes:
///  * this object will reflect reachability status for a specific interface on the computer.  To check for reachability from any interface, use [hs.network.reachability.forAddress](#address).
///  * this constructor can be used to test for a specific local network.
static int reachabilityForAddressPair(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;

    luaL_checkstring(L, 1) ; // force number to be a string
    struct addrinfo *results1 = NULL ;
    struct addrinfo hints = { AI_NUMERICHOST | AI_NUMERICSERV, PF_UNSPEC, 0, 0, 0, NULL, NULL, NULL } ;
    int ecode1 = getaddrinfo([[skin toNSObjectAtIndex:1] UTF8String], NULL, &hints, &results1);
    if (ecode1 != 0) {
        if (results1) freeaddrinfo(results1) ;
        return luaL_error(L, "local address parse error: %s", gai_strerror(ecode1)) ;
    }

    luaL_checkstring(L, 2) ; // force number to be a string
    struct addrinfo *results2 = NULL ;
    int ecode2 = getaddrinfo([[skin toNSObjectAtIndex:2] UTF8String], NULL, &hints, &results2);
    if (ecode2 != 0) {
        if (results1) freeaddrinfo(results1) ;
        if (results2) freeaddrinfo(results2) ;
        return luaL_error(L, "remote address parse error: %s", gai_strerror(ecode2)) ;
    }

    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithAddressPair(kCFAllocatorDefault, results1->ai_addr, results2->ai_addr);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;

    if (results1) freeaddrinfo(results1) ;
    if (results2) freeaddrinfo(results2) ;
    return 1 ;
}

/// hs.network.reachability.forHostName(hostName) -> reachabilityObject
/// Constructor
/// Returns a reachability object for the specified host.
///
/// Parameters:
///  * hostName - a string containing the hostname of a machine to check or track the reachability status for.
///
/// Returns:
///  * a reachability object for the specified host.
///
/// Notes:
///  * this object will reflect reachability status for any interface available on the computer.
///  * this constructor relies on the hostname being resolvable, possibly through DNS, Bonjour, locally defined, etc.
static int reachabilityForHostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    const char *internalName = [[skin toNSObjectAtIndex:1] UTF8String] ;
    SCNetworkReachabilityRef theRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, internalName);
    pushSCNetworkReachability(L, theRef) ;
    CFRelease(theRef) ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.network.reachability:status() -> number
/// Method
/// Returns the reachability status for the object
///
/// Parameters:
///  * None
///
/// Returns:
///  * a numeric representation of the reachability status
///
/// Notes:
///  * The numeric representation is made up from a combination of the flags defined in [hs.network.reachability.flags](#flags).
static int reachabilityStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags ; // = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    if (valid) {
        lua_pushinteger(L, flags) ;
    } else {
        return luaL_error(L, "unable to get reachability flags:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.reachability:statusString() -> string
/// Method
/// Returns a string representation of the reachability status for the object
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string representation of the reachability status for the object
///
/// Notes:
///  * This is included primarily for debugging, but may be more useful when you just want a quick look at the reachability status for display or testing.
///  * The string will be made up of the following flags:
///    * 't'|'-' indicates if the destination is reachable through a transient connection
///    * 'R'|'-' indicates if the destination is reachable
///    * 'c'|'-' indicates that a connection of some sort is required for the destination to be reachable
///    * 'C'|'-' indicates if the destination requires a connection which will be initiated when traffic to the destination is present
///    * 'i'|'-' indicates if the destination requires a connection which will require user activity to initiate
///    * 'D'|'-' indicates if the destination requires a connection which will be initiated on demand through the CFSocketStream interface
///    * 'l'|'-' indicates if the destination is actually a local address
///    * 'd'|'-' indicates if the destination is directly connected
static int reachabilityStatusString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags ; // = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    if (valid) {
        [skin pushNSObject:statusString(flags)] ;
    } else {
        return luaL_error(L, "unable to get reachability flags:%s", SCErrorString(SCError())) ;
    }
    return 1 ;
}

/// hs.network.reachability:setCallback(function) -> reachabilityObject
/// Method
/// Set or remove the callback function for a reachability object
///
/// Parameters:
///  * a function or nil to set or remove the reachability object callback function
///
/// Returns:
///  * the reachability object
///
/// Notes:
///  * The callback function will be invoked each time the status for the given reachability object changes.  The callback function should expect 2 arguments, the reachability object itself and a numeric representation of the reachability flags, and should not return anything.
///  * This method just sets the callback function.  You can start or stop the watcher with [hs.network.reachability:start](#start) or [hs.network.reachability:stop](#stop)
static int reachabilityCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;

    // in either case, we need to remove an existing callback, so...
    theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theRef->callbackRef = [skin luaRef:refTable];
        if (theRef->selfRef == LUA_NOREF) {               // make sure that we won't be __gc'd if a callback exists
            lua_pushvalue(L, 1) ;                         // but the user doesn't save us somewhere
            theRef->selfRef = [skin luaRef:refTable];
        }
    } else {
        theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.reachability:start() -> reachabilityObject
/// Method
/// Starts watching the reachability object for changes and invokes the callback function (if any) when a change occurs.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the reachability object
///
/// Notes:
///  * The callback function should be specified with [hs.network.reachability:setCallback](#setCallback).
static int reachabilityStartWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    if (!theRef->watcherEnabled) {
        SCNetworkReachabilityContext    context = { 0, NULL, NULL, NULL, NULL };
        context.info = (void *)theRef;
        if(SCNetworkReachabilitySetCallback(theRef->reachabilityObj, doReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, reachabilityQueue)) {
                theRef->watcherEnabled = YES ;
            } else {
                SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
                return luaL_error(L, "unable to set watcher dispatch queue:%s", SCErrorString(SCError())) ;
            }
        } else {
            return luaL_error(L, "unable to set watcher callback:%s", SCErrorString(SCError())) ;
        }
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.reachability:stop() -> reachabilityObject
/// Method
/// Stops watching the reachability object for changes.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the reachability object
static int reachabilityStopWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
    SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, NULL);
    theRef->watcherEnabled = NO ;
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Module Constants

/// hs.network.reachability.flags[]
/// Constant
/// A table containing the numeric value for the possible flags returned by the [hs.network.reachability:status](#status) method or in the `flags` parameter of the callback function.
///
/// * transientConnection  - indicates if the destination is reachable through a transient connection
/// * reachable            - indicates if the destination is reachable
/// * connectionRequired   - indicates that a connection of some sort is required for the destination to be reachable
/// * connectionOnTraffic  - indicates if the destination requires a connection which will be initiated when traffic to the destination is present
/// * interventionRequired - indicates if the destination requires a connection which will require user activity to initiate
/// * connectionOnDemand   - indicates if the destination requires a connection which will be initiated on demand through the CFSocketStream interface
/// * isLocalAddress       - indicates if the destination is actually a local address
/// * isDirect             - indicates if the destination is directly connected
static int pushReachabilityFlags(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsTransientConnection) ;  lua_setfield(L, -2, "transientConnection") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsReachable) ;            lua_setfield(L, -2, "reachable") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionRequired) ;   lua_setfield(L, -2, "connectionRequired") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionOnTraffic) ;  lua_setfield(L, -2, "connectionOnTraffic") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsInterventionRequired) ; lua_setfield(L, -2, "interventionRequired") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsConnectionOnDemand) ;   lua_setfield(L, -2, "connectionOnDemand") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsIsLocalAddress) ;       lua_setfield(L, -2, "isLocalAddress") ;
    lua_pushinteger(L, kSCNetworkReachabilityFlagsIsDirect) ;             lua_setfield(L, -2, "isDirect") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNetworkReachabilityRef theRef = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
    SCNetworkReachabilityFlags flags ; // = 0 ;
    Boolean valid = SCNetworkReachabilityGetFlags(theRef, &flags);
    NSString *flagString = @"** unable to get reachability flags*" ;
    if (valid)  flagString = statusString(flags) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, flagString, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        SCNetworkReachabilityRef theRef1 = get_structFromUserdata(reachability_t, L, 1)->reachabilityObj ;
        SCNetworkReachabilityRef theRef2 = get_structFromUserdata(reachability_t, L, 2)->reachabilityObj ;
        lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin logVerbose:@"Reachability GC"] ;
    reachability_t* theRef = get_structFromUserdata(reachability_t, L, 1) ;
    if (theRef->callbackRef != LUA_NOREF) {
        theRef->callbackRef = [skin luaUnref:refTable ref:theRef->callbackRef] ;
        SCNetworkReachabilitySetCallback(theRef->reachabilityObj, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(theRef->reachabilityObj, NULL);
    }
    theRef->selfRef = [skin luaUnref:refTable ref:theRef->selfRef] ;
    [skin destroyGCCanary:&(theRef->lsCanary)];

    CFRelease(theRef->reachabilityObj) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    reachabilityQueue = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"status",       reachabilityStatus},
    {"statusString", reachabilityStatusString},
    {"setCallback",  reachabilityCallback},
    {"start",        reachabilityStartWatcher},
    {"stop",         reachabilityStopWatcher},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"forAddressPair", reachabilityForAddressPair},
    {"forAddress",     reachabilityForAddress},
    {"forHostName",    reachabilityForHostName},
    {NULL,             NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_network_reachabilityinternal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // unlike dispatch_get_main_queue, this is concurrent... make sure to invoke lua part of callback
    // on main queue, though...
    reachabilityQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    pushReachabilityFlags(L) ; lua_setfield(L, -2, "flags") ;

    return 1;
}
