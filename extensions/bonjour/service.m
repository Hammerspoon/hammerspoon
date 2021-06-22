@import Cocoa ;
@import LuaSkin ;

@import Darwin.POSIX.netinet.in ;
@import Darwin.POSIX.netdb ;

static const char * const USERDATA_TAG = "hs.bonjour.service" ;
static LSRefTable refTable = LUA_NOREF;

static NSMapTable *serviceUDRecords ;

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

@interface HSNetServiceWrapper : NSObject <NSNetServiceDelegate>
@property NSNetService *service ;
@property int          callbackRef ;
@property int          monitorCallbackRef ;
@property int          selfRefCount ;
@property int          selfRef ;

// stupid macOS API will cause an exception if we try to publish a discovered service (or one created to
// be resolved) but won't give us a method telling us which it is, so we'll have to track on our own and
// assume that if this module didn't create it, we can't publish it.
@property BOOL         canPublish ;
@end

@implementation HSNetServiceWrapper

- (instancetype)initWithService:(NSNetService *)service {
    self = [super init] ;
    if (self && service) {
        _service            = service ;
        _callbackRef        = LUA_NOREF ;
        _monitorCallbackRef = LUA_NOREF ;
        _selfRef            = LUA_NOREF ;
        _selfRefCount       = 0 ;
        _canPublish         = NO ;

        service.delegate = self ;
    }
    return self ;
}

- (void)performCallbackWith:(id)argument usingCallback:(int)fnRef {
    if (fnRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int argCount    = 1 ;
        [skin pushLuaRef:refTable ref:fnRef] ;
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

- (void)netServiceDidPublish:(__unused NSNetService *)sender {
    [self performCallbackWith:@"published" usingCallback:_callbackRef] ;
}

- (void)netService:(__unused NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    if (_callbackRef != LUA_NOREF) {
        [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]
                    usingCallback:_callbackRef] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:publish error:%@", USERDATA_TAG, netServiceErrorToString(errorDict)]] ;
    }
}

- (void)netServiceDidResolveAddress:(__unused NSNetService *)sender {
    [self performCallbackWith:@"resolved" usingCallback:_callbackRef] ;
}

- (void)netService:(__unused NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    if (_callbackRef != LUA_NOREF) {
        [self performCallbackWith:@[@"error", netServiceErrorToString(errorDict)]
                    usingCallback:_callbackRef] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:resolve error:%@", USERDATA_TAG, netServiceErrorToString(errorDict)]] ;
    }
}

// we clear the callback before stopping, but resolveWithTimeout uses this for indicating that the
// timeout has been reached.
- (void)netServiceDidStop:(__unused NSNetService *)sender {
    [self performCallbackWith:@"stop" usingCallback:_callbackRef] ;
}

// - (void)netServiceWillPublish:(__unused NSNetService *)sender {
//     [self performCallbackWith:@"publish" usingCallback:_callbackRef] ;
// }
//
// - (void)netServiceWillResolve:(__unused NSNetService *)sender {
//     [self performCallbackWith:@"resolve" usingCallback:_callbackRef] ;
// }
//
// - (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream
//                                                                 outputStream:(NSOutputStream *)outputStream;

- (void)netService:(__unused NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    NSDictionary *dataDictionary = [NSNetService dictionaryFromTXTRecordData:data] ;
    if (!dataDictionary) dataDictionary = (NSDictionary *)[NSNull null] ;

    [self performCallbackWith:@[@"txtRecord", dataDictionary] usingCallback:_monitorCallbackRef] ;
}

@end

#pragma mark - Module Functions

// - (instancetype)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;
// - (instancetype)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name port:(int)port;

// hs.bonjour.service.remote is documented with its wrapper in init.lua
static int service_newForResolve(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name   = [skin toNSObjectAtIndex:1] ;
    NSString *type   = [skin toNSObjectAtIndex:2] ;
    NSString *domain = (lua_gettop(L) > 2) ? [skin toNSObjectAtIndex:3] : @"" ;
    NSNetService *service = [[NSNetService alloc] initWithDomain:domain type:type name:name] ;
    if (service) {
        HSNetServiceWrapper *wrapper = [[HSNetServiceWrapper alloc] initWithService:service] ;
        if (wrapper) {
            [skin pushNSObject:wrapper] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// hs.bonjour.service.new is documented with its wrapper in init.lua
static int service_newForPublish(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TNUMBER | LS_TINTEGER, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name   = [skin toNSObjectAtIndex:1] ;
    NSString *type   = [skin toNSObjectAtIndex:2] ;
    int      port    = (int)lua_tointeger(L, 3) ;
    NSString *domain = (lua_gettop(L) > 3) ? [skin toNSObjectAtIndex:4] : @"" ;
    NSNetService *service = [[NSNetService alloc] initWithDomain:domain type:type name:name port:port] ;
    if (service) {
        HSNetServiceWrapper *wrapper = [[HSNetServiceWrapper alloc] initWithService:service] ;
        if (wrapper) {
            wrapper.canPublish = YES ;
            [skin pushNSObject:wrapper] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.bonjour.service:addresses() -> table
/// Method
/// Returns a table listing the addresses for the service represented by the serviceObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array table of strings representing the IPv4 and IPv6 address of the machine which provides the services represented by the serviceObject
///
/// Notes:
///  * for remote serviceObjects, the table will be empty if this method is invoked before [hs.bonjour.service:resolve](#resolve).
///  * for local (published) serviceObjects, this table will always be empty.
static int service_addresses(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    NSArray *addresses = wrapper.service.addresses ;
    if (addresses) {
        for (NSData *thisAddr in addresses) {
            int  err;
            char addrStr[NI_MAXHOST];
            err = getnameinfo((const struct sockaddr *) [thisAddr bytes], (socklen_t) [thisAddr length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
            if (err == 0) {
                lua_pushstring(L, addrStr) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            } else {
                lua_pushfstring(L, "** error:%s", gai_strerror(err)) ;
            }
        }
    }
    return 1 ;
}

/// hs.bonjour.service:domain() -> string
/// Method
/// Returns the domain the service represented by the serviceObject belongs to.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the domain the service represented by the serviceObject belongs to.
///
/// Notes:
///  * for remote serviceObjects, this domain will be the domain the service was discovered in.
///  * for local (published) serviceObjects, this domain will be the domain the service is published in; if you did not specify a domain with [hs.bonjour.service.new](#new) then this will be an empty string until [hs.bonjour.service:publish](#publish) is invoked.
static int service_domain(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.domain] ;
    return 1 ;
}

/// hs.bonjour.service:name() -> string
/// Method
/// Returns the name of the service represented by the serviceObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the name of the service represented by the serviceObject.
static int service_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.name] ;
    return 1 ;
}

/// hs.bonjour.service:hostname() -> string
/// Method
/// Returns the hostname of the machine the service represented by the serviceObject belongs to.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the hostname of the machine the service represented by the serviceObject belongs to.
///
/// Notes:
///  * for remote serviceObjects, this will be nil if this method is invoked before [hs.bonjour.service:resolve](#resolve).
///  * for local (published) serviceObjects, this method will always return nil.
static int service_hostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.hostName] ;
    return 1 ;
}

/// hs.bonjour.service:type() -> string
/// Method
/// Returns the type of service represented by the serviceObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the type of service represented by the serviceObject.
static int service_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.service.type] ;
    return 1 ;
}

/// hs.bonjour.service:port() -> integer
/// Method
/// Returns the port the service represented by the serviceObject is available on.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a number specifying the port the service represented by the serviceObject is available on.
///
/// Notes:
///  * for remote serviceObjects, this will be -1 if this method is invoked before [hs.bonjour.service:resolve](#resolve).
///  * for local (published) serviceObjects, this method will always return the number specified when the serviceObject was created with the [hs.bonjour.service.new](#new) constructor.
static int service_port(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, wrapper.service.port) ;
    return 1 ;
}

/// hs.bonjour.service:txtRecord([records]) -> table | serviceObject | false
/// Method
/// Get or set the text records associated with the serviceObject.
///
/// Parameters:
///  * `records` - an optional table specifying the text record for the advertised service as a series of key-value entries. All keys and values must be specified as strings.
///
/// Returns:
///  * if an argument is provided to this method, returns the serviceObject or false if there was a problem setting the text record for this service. If no argument is provided, returns the current table of text records.
///
/// Notes:
///  * for remote serviceObjects, this method will return nil if invoked before [hs.bonjour.service:resolve](#resolve)
///  * setting the text record for a service replaces the existing records for the serviceObject. If the serviceObject is remote, this change is only visible on the local machine. For a service you are advertising, this change will be advertised to other machines.
///
///  * Text records are usually used to provide additional information concerning the service and their purpose and meanings are service dependant; for example, when advertising an `_http._tcp.` service, you can specify a specific path on the server by specifying a table of text records containing the "path" key.
static int service_TXTRecordData(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        NSData *txtRecord = wrapper.service.TXTRecordData ;
        if (txtRecord) {
            [skin pushNSObject:[NSNetService dictionaryFromTXTRecordData:txtRecord] withOptions:LS_NSDescribeUnknownTypes] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        NSData *txtRecord = nil ;
        if (lua_type(L, 2) == LUA_TTABLE) {
            NSDictionary *dict   = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly] ;
            NSString     *errMsg = nil ;
            if ([dict isKindOfClass:[NSDictionary class]]) {
                for (NSString* key in dict) {
                    id value = [dict objectForKey:key] ;
                    if (![key isKindOfClass:[NSString class]]) {
                        errMsg = [NSString stringWithFormat:@"table key %@ is not a string", key] ;
                    } else if (!([(NSObject *)value isKindOfClass:[NSString class]] || [(NSObject *)value isKindOfClass:[NSData class]])) {
                        errMsg = [NSString stringWithFormat:@"value for key %@ must be a string", key] ;
                    }
                }
            } else {
                errMsg = @"expected table of key-value pairs" ;
            }
            if (errMsg) return luaL_argerror(L, 2, errMsg.UTF8String) ;
            txtRecord = [NSNetService dataFromTXTRecordDictionary:dict] ;
        }
        if ([wrapper.service setTXTRecordData:txtRecord]) {
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    }
    return 1 ;
}

/// hs.bonjour.service:includesPeerToPeer([value]) -> boolean | serviceObject
/// Method
/// Get or set whether the service represented by the service object should be published or resolved over peer-to-peer Bluetooth and Wi-Fi, if available.
///
/// Parameters:
///  * `value` - an optional boolean, default false, specifying whether advertising and resoloving should occur over peer-to-peer Bluetooth and Wi-Fi, if available.
///
/// Returns:
///  * if `value` is provided, returns the serviceObject; otherwise returns the current value.
///
/// Notes:
///  * if you are changing the value of this property, you must call this method before invoking [hs.bonjour.service:publish](#publish] or [hs.bonjour.service:resolve](#resolve), or after stopping publishing or resolving with [hs.bonjour.service:stop](#stop).
///
///  * for remote serviceObjects, this flag determines if resolution and text record monitoring should occur over peer-to-peer network interfaces.
///  * for local (published) serviceObjects, this flag determines if advertising should occur over peer-to-peer network interfaces.
static int service_includesPeerToPeer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, wrapper.service.includesPeerToPeer) ;
    } else {
        wrapper.service.includesPeerToPeer = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// - (BOOL)getInputStream:(out NSInputStream * _Nullable *)inputStream outputStream:(out NSOutputStream * _Nullable *)outputStream;

/// hs.bonjour.service:publish([allowRename], [callback]) -> serviceObject
/// Method
/// Begin advertising the specified local service.
///
/// Parameters:
///  * `allowRename` - an optional boolean, default true, specifying whether to automatically rename the service if the name and type combination is already being published in the service's domain. If renaming is allowed and a conflict occurs, the service name will have `-#` appended to it where `#` is an increasing integer starting at 2.
///  * `callback`    - an optional callback function which should expect 2 or 3 arguments and return none. The arguments to the callback function will be one of the following sets:
///    * on successfull publishing:
///      * the serviceObject userdata
///      * the string "published"
///    * if an error occurs during publishing:
///      * the serviceObject userdata
///      * the string "error"
///      * a string specifying the specific error that occurred
///
/// Returns:
///  * the serviceObject
///
/// Notes:
///  * this method should only be called on serviceObjects which were created with [hs.bonjour.service.new](#new).
static int service_publish(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (!wrapper.canPublish) return luaL_error(L, "can't publish a service created for resolution") ;

    BOOL allowRename = YES ;
    BOOL hasFunction = NO ;
    switch(lua_gettop(L)) {
        case 1:
            break ;
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TBOOLEAN, LS_TBREAK] ;
            hasFunction = (BOOL)(lua_type(L, 2) != LUA_TBOOLEAN) ;
            if (!hasFunction) allowRename = (BOOL)lua_toboolean(L, 2) ;
            break ;
//      case 3: // if it's less than 2 or greater than 3, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TFUNCTION, LS_TBREAK] ;
            hasFunction = YES ;
            allowRename = (BOOL)lua_toboolean(L, 2) ;
            break ;
    }

    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    if (hasFunction) {
        lua_pushvalue(L, -1) ;
        wrapper.callbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service publishWithOptions:(allowRename ? 0 : NSNetServiceNoAutoRename)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour.service:resolve([timeout], [callback]) -> serviceObject
/// Method
/// Resolve the address and details for a discovered service.
///
/// Parameters:
///  * `timeout`  - an optional number, default 0.0, specifying the maximum number of seconds to attempt to resolve the details for this service. Specifying 0.0 means that the resolution should not timeout and that resolution should continue indefinately.
///  * `callback` - an optional callback function which should expect 2 or 3 arguments and return none.
///    * on successfull resolution:
///      * the serviceObject userdata
///      * the string "resolved"
///    * if an error occurs during resolution:
///      * the serviceObject userdata
///      * the string "error"
///      * a string specifying the specific error that occurred
///    * if `timeout` is specified and is any number other than 0.0, the following will be sent to the callback when the timeout has been reached:
///      * the serviceObject userdata
///      * the string "stop"
///
/// Returns:
///  * the serviceObject
///
/// Notes:
///  * this method should only be called on serviceObjects which were returned by an `hs.bonjour` browserObject or created with [hs.bonjour.service.remote](#remote).
///
///  * For a remote service, this method must be called in order to retrieve the [addresses](#addresses), the [port](#port), the [hostname](#hostname), and any the associated [text records](#txtRecord) for the service.
///  * To reduce the usage of system resources, you should generally specify a timeout value or make sure to invoke [hs.bonjour.service:stop](#stop) after you have verified that you have received the details you require.
static int service_resolveWithTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    if (wrapper.canPublish) return luaL_error(L, "can't resolve a service created for publishing") ;
    // well, technically it won't crash like publishing a service created for resolving will, but
    // it will either timeout/fail because there is nothing out there, or it will get *our* address
    // if we published and then stopped because we're still in someone's cache. The result is
    // not useful, either way.

    NSTimeInterval duration = 0.0 ;
    BOOL           hasFunction = false ;
    switch(lua_gettop(L)) {
        case 1:
            break ;
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNUMBER, LS_TBREAK] ;
            hasFunction = (BOOL)(lua_type(L, 2) != LUA_TNUMBER) ;
            if (!hasFunction) duration = lua_tonumber(L, 2) ;
            break ;
//      case 3: // if it's less than 2 or greater than 3, this will error out, so... it's the default
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TFUNCTION, LS_TBREAK] ;
            hasFunction = YES ;
            duration = lua_tonumber(L, 2) ;
            break ;
    }

    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    if (hasFunction) {
        lua_pushvalue(L, -1) ;
        wrapper.callbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service resolveWithTimeout:duration] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour.service:monitor([callback]) -> serviceObject
/// Method
/// Monitor the service for changes to its associated text records.
///
/// Parameters:
///  * `callback` - an optional callback function which should expect 3 arguments:
///    * the serviceObject userdata
///    * the string "txtRecord"
///    * a table containing key-value pairs specifying the new text records for the service
///
/// Returns:
///  * the serviceObject
///
/// Notes:
///  * When monitoring is active, [hs.bonjour.service:txtRecord](#txtRecord) will return the most recent text records observed. If this is the only method by which you check the text records, but you wish to ensure you have the most recent values, you should invoke this method without specifying a callback.
///
///  * When [hs.bonjour.service:resolve](#resolve) is invoked, the text records at the time of resolution are captured for retrieval with [hs.bonjour.service:txtRecord](#txtRecord). Subsequent changes to the text records will not be reflected by [hs.bonjour.service:txtRecord](#txtRecord) unless this method has been invoked (with or without a callback function) and is currently active.
///
///  * You *can* monitor for text changes on local serviceObjects that were created by [hs.bonjour.service.new](#new) and that you are publishing. This can be used to invoke a callback when one portion of your code makes changes to the text records you are publishing and you need another portion of your code to be aware of this change.
static int service_startMonitoring(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TOPTIONAL, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    wrapper.monitorCallbackRef = [skin luaUnref:refTable ref:wrapper.monitorCallbackRef] ;
    [wrapper.service stopMonitoring] ;
    if (lua_gettop(L) == 2) {
        lua_pushvalue(L, -1) ;
        wrapper.monitorCallbackRef = [skin luaRef:refTable] ;
    }

    [wrapper.service startMonitoring] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour.service:stop() -> serviceObject
/// Method
/// Stop advertising or resolving the service specified by the serviceObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * the serviceObject
///
/// Notes:
///  * this method will stop the advertising of a service which has been published with [hs.bonjour.service:publish](#publish) or is being resolved with [hs.bonjour.service:resolve](#resolve).
///
///  * To reduce the usage of system resources, you should make sure to use this method when resolving a remote service if you did not specify a timeout for [hs.bonjour.service:resolve](#resolve) or specified a timeout of 0.0 once you have verified that you have the details you need.
static int service_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    [wrapper.service stop] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.bonjour.service:stopMonitoring() -> serviceObject
/// Method
/// Stop monitoring a service for changes to its text records.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the serviceObject
///
/// Notes:
///  * This method will stop updating [hs.bonjour.service:txtRecord](#txtRecord) and invoking the callback, if any, assigned with [hs.bonjour.service:monitor](#monitor).
static int service_stopMonitoring(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSNetServiceWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    wrapper.monitorCallbackRef = [skin luaUnref:refTable ref:wrapper.monitorCallbackRef] ;
    [wrapper.service stopMonitoring] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSNetServiceWrapper(lua_State *L, id obj) {
    LuaSkin *skin  = [LuaSkin sharedWithState:L] ;
    HSNetServiceWrapper *value = obj;
    if (value.selfRefCount == 0) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSNetServiceWrapper *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
        [serviceUDRecords setObject:@(value.selfRef) forKey:value] ;
    }
    value.selfRefCount++ ;
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toHSNetServiceWrapperFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNetServiceWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSNetServiceWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSNetService(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSNumber *valueRef         = nil ;
    HSNetServiceWrapper *value = nil ;

    NSEnumerator *enumerator = [serviceUDRecords keyEnumerator] ;
    HSNetServiceWrapper *key = [enumerator nextObject] ;
    while (key) {
        if ([key.service isEqualTo:obj]) {
            valueRef = [serviceUDRecords objectForKey:key] ;
            break ;
        }
        key = [enumerator nextObject] ;
    }

    if (valueRef) {
        [skin pushLuaRef:refTable ref:valueRef.intValue] ;
        value = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;
    } else {
        value = [[HSNetServiceWrapper alloc] initWithService:obj] ;
    }

    if (value) {
        [skin pushNSObject:value] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSNetServiceWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSNetServiceWrapper"] ;
    NSString *title = [NSString stringWithFormat:@"%@ (%@%@)", obj.service.name, obj.service.type, obj.service.domain] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSNetServiceWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSNetServiceWrapper"] ;
        HSNetServiceWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSNetServiceWrapper"] ;

        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSNetServiceWrapper *obj = get_objectFromUserdata(__bridge_transfer HSNetServiceWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.monitorCallbackRef = [skin luaUnref:refTable ref:obj.monitorCallbackRef] ;
            obj.service.delegate = nil ;
            [obj.service stop] ;
            [obj.service stopMonitoring] ;

            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
            [serviceUDRecords removeObjectForKey:obj] ;

            obj.service = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    [serviceUDRecords removeAllObjects] ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"addresses",          service_addresses},          // will be empty table before resolve()
    {"domain",             service_domain},
    {"name",               service_name},
    {"hostname",           service_hostName},           // will be nil before resolve()
    {"type",               service_type},
    {"port",               service_port},               // will be -1 before resolve()
    {"txtRecord",          service_TXTRecordData},      // will be nil before resolve()
    {"includesPeerToPeer", service_includesPeerToPeer},
    {"resolve",            service_resolveWithTimeout},
    {"monitor",            service_startMonitoring},
    {"stop",               service_stop},
    {"stopMonitoring",     service_stopMonitoring},
    {"publish",            service_publish},

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"remote", service_newForResolve},
    {"new",    service_newForPublish},
    {NULL,     NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_bonjour_service(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    serviceUDRecords = [NSMapTable strongToStrongObjectsMapTable] ;

    [skin registerPushNSHelper:pushHSNetServiceWrapper         forClass:"HSNetServiceWrapper"];
    [skin registerLuaObjectHelper:toHSNetServiceWrapperFromLua forClass:"HSNetServiceWrapper"
                                                    withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSNetService forClass:"NSNetService"];

    return 1;
}
