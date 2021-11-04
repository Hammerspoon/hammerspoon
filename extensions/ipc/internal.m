@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.ipc" ;
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSIPCMessagePort : NSObject
@property CFMessagePortRef   messagePort ;
@property int                callbackRef ;
@property int                selfRef ;
@end

static CFDataRef ipc_callback(__unused CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    LuaSkin          *skin   = [LuaSkin sharedWithState:NULL];
    HSIPCMessagePort *port   = (__bridge HSIPCMessagePort *)info ;
    CFDataRef        outdata = NULL ;

    _lua_stackguard_entry(skin.L);
    if (port.callbackRef != LUA_NOREF) {
        lua_State *L = skin.L ;
        [skin pushLuaRef:refTable ref:port.callbackRef] ;
        [skin pushNSObject:port] ;
        lua_pushinteger(L, msgid) ;
        [skin pushNSObject:(__bridge NSData *)data] ;
        BOOL status = [skin protectedCallAndTraceback:3 nresults:1] ;

        luaL_tolstring(L, -1, NULL) ;                   // make sure it's a string
        [skin logDebug:[NSString stringWithFormat:@"%s", lua_tostring(L, -1)]] ;
        NSMutableData *result = [[NSMutableData alloc] init] ;
        [result appendData:[skin toNSObjectAtIndex:-1 withOptions:LS_NSLuaStringAsDataOnly]] ;
        if (!status) {
            [skin logError:[NSString stringWithFormat:@"%s:callback - error during callback for %@: %s", USERDATA_TAG, (__bridge NSString *)CFMessagePortGetName(port.messagePort), lua_tostring(L, -2)]] ;
        }
        lua_pop(L, 2) ;                                 // remove the result and the luaL_tostring() version

        if (result) outdata = (__bridge_retained CFDataRef)result ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:callback - no callback function defined for %@", USERDATA_TAG, (__bridge NSString *)CFMessagePortGetName(port.messagePort)]] ;
    }
    _lua_stackguard_exit(skin.L);
    return outdata ;
}

@implementation HSIPCMessagePort

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _selfRef     = 0 ;
        _messagePort = NULL ;
        _callbackRef = LUA_NOREF ;
    }
    return self ;
}

@end

#pragma mark - Module Functions

/// hs.ipc.localPort(name, fn) -> ipcObject
/// Constructor
/// Create a new local ipcObject for receiving and responding to messages from a remote port
///
/// Parameters:
///  * name - a string acting as the message port name.
///  * fn   - the callback function which will receive messages.
///
/// Returns:
///  * the ipc object
///
/// Notes:
///  * a remote port can send messages at any time to a local port; a local port can only respond to messages from a remote port
static int ipc_localPort(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
    NSString *portName = [skin toNSObjectAtIndex:1] ;

    HSIPCMessagePort *port = [[HSIPCMessagePort alloc] init] ;
    if (port) {
        lua_pushvalue(L, 2) ;
        port.callbackRef = [skin luaRef:refTable] ;

        CFMessagePortContext ctx = { 0, (__bridge void *)port, NULL, NULL, NULL } ;
        Boolean error = false ;
        port.messagePort = CFMessagePortCreateLocal(NULL, (__bridge CFStringRef)portName, ipc_callback, &ctx, &error) ;

        if (error) {
            NSString *errorMsg = port.messagePort ? @"local port name already in use" : @"failed to create new local port" ;
            if (port.messagePort) CFRelease(port.messagePort) ;
            port.messagePort = NULL ;
            return luaL_error(L, errorMsg.UTF8String) ;
        }

        CFRunLoopSourceRef runLoop = CFMessagePortCreateRunLoopSource(NULL, port.messagePort, 0) ;
        if (runLoop) {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoop, kCFRunLoopCommonModes);
            CFRelease(runLoop) ;
        } else {
            CFRelease(port.messagePort) ;
            port.messagePort = nil ;
            return luaL_error(L, "unable to create runloop source for local port") ;
        }
    } else {
        return luaL_error(L, "failed to create new local port") ;
    }
    [skin pushNSObject:port] ;
    return 1 ;
}

/// hs.ipc.remotePort(name) -> ipcObject
/// Constructor
/// Create a new remote ipcObject for sending messages asynchronously to a local port
///
/// Parameters:
///  * name - a string acting as the message port name.
///
/// Returns:
///  * the ipc object
///
/// Notes:
///  * a remote port can send messages at any time to a local port; a local port can only respond to messages from a remote port
static int ipc_remotePort(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *portName = [skin toNSObjectAtIndex:1] ;

    HSIPCMessagePort *port = [[HSIPCMessagePort alloc] init] ;
    if (port) port.messagePort = CFMessagePortCreateRemote(NULL, (__bridge CFStringRef)portName) ;
    if (!(port && port.messagePort)) {
        return luaL_error(L, "failed to create new remote port") ;
    }
    [skin pushNSObject:port] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.ipc:name() -> string
/// Method
/// Returns the name the ipcObject uses for its port when active
///
/// Parameters:
///  * None
///
/// Returns:
///  * the port name as a string
static int ipc_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSIPCMessagePort *port = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:(__bridge NSString *)CFMessagePortGetName(port.messagePort)] ;
    return 1 ;
}

/// hs.ipc:isRemote() -> boolean
/// Method
/// Returns whether or not the ipcObject represents a remote or local port
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the object is a remote port, otherwise false
///
/// Notes:
///  * a remote port can send messages at any time to a local port; a local port can only respond to messages from a remote port
static int ipc_isRemote(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSIPCMessagePort *port = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, CFMessagePortIsRemote(port.messagePort)) ;
    return 1 ;
}

/// hs.ipc:isValid() -> boolean
/// Method
/// Returns whether or not the ipcObject port is still valid or not
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the object is a valid port, otherwise false
static int ipc_isValid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSIPCMessagePort *port = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, CFMessagePortIsValid(port.messagePort)) ;
    return 1 ;
}

/// hs.ipc:sendMessage(data, msgID, [waitTimeout], [oneWay]) -> status, response
/// Method
/// Sends a message from a remote port to a local port
///
/// Parameters:
///  * data        - any data type which is to be sent to the local port.  The data will be converted into its string representation
///  * msgID       - an integer message ID
///  * waitTimeout - an optional number, default 2.0, representing the number of seconds the method will wait to send the message and then wait for a response.  The method *may* block up to twice this number of seconds, though usually it will be shorter.
///  * oneWay      -  an optional boolean, default false, indicating whether or not to wait for a response.  It this is true, the second returned argument will be nil.
///
/// Returns:
///  * status   - a boolean indicathing whether or not the local port responded before the timeout (true) or if an error or timeout occurred waiting for the response (false)
///  * response - the response from the local port, usually a string, but may be nil if there was no response returned.  If status is false, will contain an error message describing the error.
static int ipc_sendMessage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TNUMBER | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSIPCMessagePort *port = [skin toNSObjectAtIndex:1] ;
    if (!CFMessagePortIsValid(port.messagePort)) { return luaL_error(L, "ipc port is no longer valid"); }
    if (!CFMessagePortIsRemote(port.messagePort)) { return luaL_error(L, "not a remote port") ; }

    luaL_tolstring(L, 2, NULL) ; // make sure it's a string
    NSData *data = [skin toNSObjectAtIndex:-1 withOptions:LS_NSLuaStringAsDataOnly] ;
    lua_pop(L, 1) ;

    lua_Integer msgID = lua_tointeger(L, 3) ;

    CFTimeInterval waitTimeout = ((lua_gettop(L) >= 4) && lua_isnumber(L, 4)) ? lua_tonumber(L, 4) : 2.0 ;

    BOOL oneWay = lua_isboolean(L, -1) ? (BOOL)lua_toboolean(L, -1) : NO ;

    CFDataRef returnedData;
    SInt32 code = CFMessagePortSendRequest(
                                            port.messagePort,
                                            (SInt32)msgID,
                                            (__bridge CFDataRef)data,
                                            waitTimeout,
                                            (oneWay ? 0.0 : waitTimeout),
                                            (oneWay ? NULL : kCFRunLoopDefaultMode),
                                            &returnedData
                                          );
    BOOL status = (code == kCFMessagePortSuccess) ;

    NSData *response ;
    if (status) {
        if (!oneWay) {
            response = returnedData ? (__bridge_transfer NSData *)returnedData : nil ;
        }
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"unrecognized error: %d", code] ;
        switch(code) {
            case kCFMessagePortSendTimeout:        errMsg = @"send timeout" ; break ;
            case kCFMessagePortReceiveTimeout:     errMsg = @"receive timeout" ; break ;
            case kCFMessagePortIsInvalid:          errMsg = @"message port invalid" ; break ;
            case kCFMessagePortTransportError:     errMsg = @"error during transport" ; break ;
            case kCFMessagePortBecameInvalidError: errMsg = @"message port was invalidated" ; break ;
        }
        response = [errMsg dataUsingEncoding:NSUTF8StringEncoding] ;
    }

    lua_pushboolean(L, status) ;
    [skin pushNSObject:response] ;
    return 2 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSIPCMessagePort(lua_State *L, id obj) {
    HSIPCMessagePort *value = obj;
    value.selfRef++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSIPCMessagePort *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSIPCMessagePortFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSIPCMessagePort *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSIPCMessagePort, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSIPCMessagePort *obj = [skin luaObjectAtIndex:1 toClass:"HSIPCMessagePort"] ;
    NSString *title = [NSString stringWithFormat:@"%@, %@", (__bridge NSString *)CFMessagePortGetName(obj.messagePort), (CFMessagePortIsRemote(obj.messagePort) ? @"remote" : @"local")] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSIPCMessagePort *obj1 = [skin luaObjectAtIndex:1 toClass:"HSIPCMessagePort"] ;
        HSIPCMessagePort *obj2 = [skin luaObjectAtIndex:2 toClass:"HSIPCMessagePort"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs.ipc:delete() -> None
/// Method
/// Deletes the ipcObject, stopping it as well if necessary
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int userdata_gc(lua_State* L) {
    HSIPCMessagePort *obj = get_objectFromUserdata(__bridge_transfer HSIPCMessagePort, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRef-- ;
        if (obj.selfRef == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.messagePort) {
                CFMessagePortInvalidate(obj.messagePort) ;
                CFRelease(obj.messagePort) ;
                obj.messagePort = NULL ;
            }
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
    {"name",        ipc_name},
    {"delete",      userdata_gc},
    {"isRemote",    ipc_isRemote},
    {"isValid",     ipc_isValid},
    {"sendMessage", ipc_sendMessage},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"localPort",  ipc_localPort},
    {"remotePort", ipc_remotePort},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libipc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSIPCMessagePort         forClass:"HSIPCMessagePort"];
    [skin registerLuaObjectHelper:toHSIPCMessagePortFromLua forClass:"HSIPCMessagePort"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
