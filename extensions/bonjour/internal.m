@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.bonjour" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static NSString *netServiceErrorToString(NSDictionary *error) {
    NSString *message = [NSString stringWithFormat:@"unrecognized error dictionary:%@", error] ;

    NSNumber *errorCode   = error[NSNetServicesErrorCode] ;
//     NSNumber *errorDomain = error[NSNetServicesErrorDomain] ;
    if (errorCode) {
        switch (errorCode.intValue) {
            case NSNetServicesActivityInProgress:
                message = @"activity in progress; cannot process new request" ;
                break ;
            case NSNetServicesBadArgumentError:
                message = @"invalid argument" ;
                break ;
            case NSNetServicesCancelledError:
                message = @"request was cancelled" ;
                break ;
            case NSNetServicesCollisionError:
                message = @"name already in use" ;
                break ;
            case NSNetServicesInvalidError:
                message = @"service improperly configured" ;
                break ;
            case NSNetServicesNotFoundError:
                message = @"service could not be found" ;
                break ;
            case NSNetServicesTimeoutError:
                message = @"timed out" ;
                break ;
            case NSNetServicesUnknownError:
                message = @"an unknown error has occurred" ;
                break ;
            default:
                message = [NSString stringWithFormat:@"unrecognized error code:%@", errorCode] ;
        }
    }
    return message ;
}

@interface HSNetServiceBrowser : NSNetServiceBrowser <NSNetServiceBrowserDelegate>
@property int  callbackRef ;
@property int  selfRefCount ;
@end

@implementation HSNetServiceBrowser

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef  = LUA_NOREF ;
        _selfRefCount = 0 ;

        self.delegate = self ;
    }
    return self ;
}

- (void)stopWithState:(lua_State *)L {
    [super stop] ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    _callbackRef = [skin luaUnref:refTable ref:_callbackRef] ;
}

- (void)performCallbackWith:(id)argument {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int argCount    = 1 ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        if (argument) {
            if ([(NSObject *)argument isKindOfClass:[NSArray class]]) {
                NSArray *args = (NSArray *)argument ;
                for (id obj in args) [skin pushNSObject:obj withOptions:LS_NSDescribeUnknownTypes] ;
                argCount += args.count ;
            } else {
                [skin pushNSObject:argument withOptions:LS_NSDescribeUnknownTypes] ;
                argCount++ ;
            }
        }
        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, -1) ;
        }
    }
}

#pragma mark * Delegate Methods

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
            didFindDomain:(NSString *)domainString
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"domain", @(YES), domainString, @(moreComing)]] ;
}
- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
          didRemoveDomain:(NSString *)domainString
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"domain", @(NO), domainString, @(moreComing)]] ;
}

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
             didNotSearch:(NSDictionary *)errorDict {
    [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]] ;
}

- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"service", @(YES), service, @(moreComing)]] ;
}
- (void)netServiceBrowser:(__unused NSNetServiceBrowser *)browser
         didRemoveService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    [self performCallbackWith:@[@"service", @(NO), service, @(moreComing)]] ;
}

// - (void)netServiceBrowserDidStopSearch:(__unused NSNetServiceBrowser *)browser {
//     [self performCallbackWith:@"stop"] ;
// }
//
// - (void)netServiceBrowserWillSearch:(__unused NSNetServiceBrowser *)browser {
//     [self performCallbackWith:@"start"] ;
// }

@end

#pragma mark - Module Functions

/// hs.bonjour.new() -> browserObject
/// Constructor
/// Creates a new network service browser that finds published services on a network using multicast DNS.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new browserObject or nil if an error occurs
static int browser_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSNetServiceBrowser *browser = [[HSNetServiceBrowser alloc] init] ;
    if (browser) {
        [skin pushNSObject:browser] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.bonjour:includesPeerToPeer([value]) -> current value | browserObject
/// Method
/// Get or set whether to also browse over peer-to-peer Bluetooth and Wi-Fi, if available.
///
/// Parameters:
///  * `value` - an optional boolean, default false, value specifying whether to also browse over peer-to-peer Bluetooth and Wi-Fi, if available.
///
/// Returns:
///  * if `value` is provided, returns the browserObject; otherwise returns the current value for this property
///
/// Notes:
///  * This property must be set before initiating a search to have an effect.
static int browser_includesPeerToPeer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, browser.includesPeerToPeer) ;
    } else {
        browser.includesPeerToPeer = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.bonjour:findBrowsableDomains(callback) -> browserObject
/// Method
/// Return a list of zero-conf and bonjour domains visibile to the users computer.
///
/// Parameters:
///  * `callback` - a function which will be invoked as visible domains are discovered. The function should accept the following parameters and return none:
///    * `browserObject`    - the userdata object for the browserObject which initiated the search
///    * `type`             - a string which will be 'domain' or 'error'
///      * if `type` == 'domain', the remaining arguments will be:
///        * `added`        - a boolean value indicating whether this callback invocation represents a newly discovered or added domain (true) or that the domain has been removed from the network (false)
///        * `domain`       - a string specifying the name of the domain discovered or removed
///        * `moreExpected` - a boolean value indicating whether or not the browser expects to discover additional domains or not.
///      * if `type` == 'error', the remaining arguments will be:
///        * `errorString`  - a string specifying the error which has occurred
///
/// Returns:
///  * the browserObject
///
/// Notes:
///  * This method returns domains which are visible to your machine; however, your machine may or may not be able to access or publish records within the returned domains. See  [hs.bonjour:findRegistrationDomains](#findRegistrationDomains)
///
///  * For most non-coporate network users, it is likely that the callback will only be invoked once for the `local` domain. This is normal. Corporate networks or networks including Linux machines using additional domains defined with Avahi may see additional domains as well, though most Avahi installations now use only 'local' by default unless specifically configured to do otherwise.
///
///  * When `moreExpected` becomes false, it is the macOS's best guess as to whether additional records are available.
///    * Generally macOS is fairly accurate in this regard concerning domain searchs, so to reduce the impact on system resources, it is recommended that you use [hs.bonjour:stop](#stop) when this parameter is false
//     * If any of your network interfaces are particularly slow or if a host on the network is slow to respond and you are concerend that additional records *may* still be forthcoming, you can use this flag to initiate additional logic or timers to determine how long to remain searching for additional domains.
static int browser_searchForBrowsableDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    HSNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (browser.callbackRef != LUA_NOREF) [browser stopWithState:L] ;
    lua_pushvalue(L, 2) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForBrowsableDomains] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour:findRegistrationDomains(callback) -> browserObject
/// Method
/// Return a list of zero-conf and bonjour domains this computer can register services in.
///
/// Parameters:
///  * `callback` - a function which will be invoked as domains are discovered. The function should accept the following parameters and return none:
///    * `browserObject`    - the userdata object for the browserObject which initiated the search
///    * `type`             - a string which will be 'domain' or 'error'
///      * if `type` == 'domain', the remaining arguments will be:
///        * `added`        - a boolean value indicating whether this callback invocation represents a newly discovered or added domain (true) or that the domain has been removed from the network (false)
///        * `domain`       - a string specifying the name of the domain discovered or removed
///        * `moreExpected` - a boolean value indicating whether or not the browser expects to discover additional domains or not.
///      * if `type` == 'error', the remaining arguments will be:
///        * `errorString`  - a string specifying the error which has occurred
///
/// Returns:
///  * the browserObject
///
/// Notes:
///  * This is the preferred method for accessing domains as it guarantees that the host machine can connect to services in the returned domains. Access to domains outside this list may be more limited. See also [hs.bonjour:findBrowsableDomains](#findBrowsableDomains)
///
///  * For most non-coporate network users, it is likely that the callback will only be invoked once for the `local` domain. This is normal. Corporate networks or networks including Linux machines using additional domains defined with Avahi may see additional domains as well, though most Avahi installations now use only 'local' by default unless specifically configured to do otherwise.
///
///  * When `moreExpected` becomes false, it is the macOS's best guess as to whether additional records are available.
///    * Generally macOS is fairly accurate in this regard concerning domain searchs, so to reduce the impact on system resources, it is recommended that you use [hs.bonjour:stop](#stop) when this parameter is false
//     * If any of your network interfaces are particularly slow or if a host on the network is slow to respond and you are concerend that additional records *may* still be forthcoming, you can use this flag to initiate additional logic or timers to determine how long to remain searching for additional domains.
static int browser_searchForRegistrationDomains(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
    HSNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    if (browser.callbackRef != LUA_NOREF) [browser stopWithState:L] ;
    lua_pushvalue(L, 2) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForRegistrationDomains] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// hs.bonjour:findServices is documented with its wrapper in init.lua
static int browser_searchForServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    NSString *service = @"_services._dns-sd._udp." ;
    NSString *domain  = @"" ;
    switch(lua_gettop(L)) {
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TBREAK] ;
            break ;
        case 3:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
            service = [skin toNSObjectAtIndex:2] ;
            break ;
//         case 4: // if it's less than 2 or greater than 4, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
            service = [skin toNSObjectAtIndex:2] ;
            domain  = [skin toNSObjectAtIndex:3] ;
            break ;
    }
    if (browser.callbackRef != LUA_NOREF) [browser stopWithState:L] ;
    lua_pushvalue(L, -1) ;
    browser.callbackRef = [skin luaRef:refTable] ;
    [browser searchForServicesOfType:service inDomain:domain] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour:stop() -> browserObject
/// Method
/// Stops a currently running search or resolution for the browser object
///
/// Parameters:
///  * None
///
/// Returns:
///  * the browserObject
///
/// Notes:
///  * This method should be invoked when you have identified the services or hosts you require to reduce the consumption of system resources.
///  * Invoking this method on an already idle browser will do nothing
///
///  * In general, when your callback function for [hs.bonjour:findBrowsableDomains](#findBrowsableDomains), [hs.bonjour:findRegistrationDomains](#findRegistrationDomains), or [hs.bonjour:findServices](#findServices) receives false for the `moreExpected` paramter, you should invoke this method on the browserObject unless there are specific reasons not to. Possible reasons you might want to extend the life of the browserObject are documented within each method.
static int browser_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceBrowser *browser = [skin toNSObjectAtIndex:1] ;
    [browser stopWithState:L] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNetServiceBrowser(lua_State *L, id obj) {
    HSNetServiceBrowser *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSNetServiceBrowser *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSNetServiceBrowserFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNetServiceBrowser *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNetServiceBrowser, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSNetServiceBrowser *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNetServiceBrowser"] ;
        HSNetServiceBrowser *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNetServiceBrowser"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNetServiceBrowser *obj = get_objectFromUserdata(__bridge_transfer HSNetServiceBrowser, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj.delegate = nil ;
            [obj stopWithState:L] ; // stop does this for us: [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"includesPeerToPeer",      browser_includesPeerToPeer},
    {"findBrowsableDomains",    browser_searchForBrowsableDomains},
    {"findRegistrationDomains", browser_searchForRegistrationDomains},
    {"findServices",            browser_searchForServices},
    {"stop",                    browser_stop},

    {"__tostring",              userdata_tostring},
    {"__eq",                    userdata_eq},
    {"__gc",                    userdata_gc},
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", browser_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_bonjour_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSNetServiceBrowser         forClass:"HSNetServiceBrowser"];
    [skin registerLuaObjectHelper:toHSNetServiceBrowserFromLua forClass:"HSNetServiceBrowser"
                                                    withUserdataMapping:USERDATA_TAG];

    return 1;
}
