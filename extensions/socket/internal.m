#import "socket.h"
#import "CocoaAsyncSocket/GCDAsyncSocket.h"


// Userdata for hs.socket objects
#define getUserData(L, idx) (__bridge HSAsyncTcpSocket *)((asyncSocketUserData *)lua_touserdata(L, idx))->asyncSocket;
static const char *USERDATA_TAG = "hs.socket";


// TCP socket class declaration
@interface HSAsyncTcpSocket : GCDAsyncSocket <GCDAsyncSocketDelegate>
@property int readCallback;
@property int writeCallback;
@property int connectCallback;
@property NSTimeInterval timeout;
@property NSMutableArray* connectedSockets;
@property NSString* unixSocketPath;
@end


// Lua callbacks
static void connectCallback(HSAsyncTcpSocket *asyncSocket) {
    mainThreadDispatch(
    	if (asyncSocket.connectCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL];
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:asyncSocket.connectCallback];
			asyncSocket.connectCallback = [skin luaUnref:refTable ref:asyncSocket.connectCallback];
			[skin protectedCallAndError:@"hs.socket:connect callback" nargs:0 nresults:0];
			_lua_stackguard_exit(skin.L);
		}
    );
}

static void writeCallback(HSAsyncTcpSocket *asyncSocket, long tag) {
    mainThreadDispatch(
    	if (asyncSocket.writeCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL];
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:asyncSocket.writeCallback];
			[skin pushNSObject: @(tag)];
			asyncSocket.writeCallback = [skin luaUnref:refTable ref:asyncSocket.writeCallback];
			[skin protectedCallAndError:@"hs.socket:write callback" nargs:1 nresults:0];
			_lua_stackguard_exit(skin.L);
		}
    );
}

static void readCallback(HSAsyncTcpSocket *asyncSocket, NSData *data, long tag) {
    mainThreadDispatch(
    	if (asyncSocket.readCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL];
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:asyncSocket.readCallback];
			[skin pushNSObject:data withOptions:LS_NSLuaStringAsDataOnly];
			[skin pushNSObject: @(tag)];
			[skin protectedCallAndError:@"hs.socket:read callback" nargs:2 nresults:0];
			_lua_stackguard_exit(skin.L);
		}
    );
}


// Delegate implementation
@implementation HSAsyncTcpSocket

- (id)init {
    dispatch_queue_t tcpDelegateQueue = dispatch_queue_create("tcpDelegateQueue", NULL);
    self.readCallback = LUA_NOREF;
    self.writeCallback = LUA_NOREF;
    self.connectCallback = LUA_NOREF;
    self.timeout = -1;
    self.connectedSockets = [[NSMutableArray alloc] init];

    return [super initWithDelegate:self delegateQueue:tcpDelegateQueue];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    [LuaSkin logDebug:@"TCP socket connected"];
    self.userData = DEFAULT;
    if (self.connectCallback != LUA_NOREF)
        connectCallback(self);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    [LuaSkin logDebug:@"TCP Unix domain socket connected"];
    self.userData = DEFAULT;
    self.unixSocketPath = [url path];
    if (self.connectCallback != LUA_NOREF)
        connectCallback(self);
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [LuaSkin logDebug:@"TCP client connected"];
    newSocket.userData = CLIENT;

    @synchronized(self.connectedSockets) {
        [self.connectedSockets addObject:newSocket];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (sock.userData == CLIENT) {
        [LuaSkin logDebug:[NSString stringWithFormat:@"TCP client disconnected: %@", [err localizedDescription]]];
        @synchronized(self.connectedSockets) {
            [self.connectedSockets removeObject:sock];
        }
    } else if (sock.userData == SERVER) {
        [LuaSkin logDebug:[NSString stringWithFormat:@"TCP server disconnected: %@", [err localizedDescription]]];
        @synchronized(self.connectedSockets) {
            for (HSAsyncTcpSocket *client in self.connectedSockets)
                [client disconnect];
        }
        if (self.unixSocketPath) { // Clean up created socket file
            NSError *error;
            if (![[NSFileManager defaultManager] removeItemAtPath:self.unixSocketPath error:&error]) {
                [LuaSkin logError:[NSString stringWithFormat:@"Could not remove created Unix domain socket: %@",
                                   [error localizedDescription]]];
            }
            self.unixSocketPath = nil;
        }
    } else
        [LuaSkin logDebug:[NSString stringWithFormat:@"TCP socket disconnected: %@", [err localizedDescription]]];

    sock.userData = nil;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    //[LuaSkin logDebug:@"Data written to TCP socket"];
    if (self.writeCallback != LUA_NOREF)
        writeCallback(self, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag  {
    //[LuaSkin logDebug:@"Data read from TCP socket"];
    if (self.readCallback != LUA_NOREF)
        readCallback(self, data, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL))completionHandler {
    // Allow TLS handshake without trust evaluation for self-signed certificates
    // This is only called if startTLS is invoked with option GCDAsyncSocketManuallyEvaluateTrust == YES
    if (completionHandler)
        completionHandler(YES);
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    [LuaSkin logDebug:@"TCP socket secured"];
}

@end


/// hs.socket.new([fn]) -> hs.socket object
/// Constructor
/// Creates an unconnected asynchronous TCP socket object
///
/// Parameters:
///  * fn - An optional [callback function](#setCallback) for reading data from the socket, settable here for convenience
///
/// Returns:
///  * An [`hs.socket`](#new) object
///
static int socket_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket *asyncSocket = [[HSAsyncTcpSocket alloc] init];

    if (lua_type(L, 1) == LUA_TFUNCTION) {
        lua_pushvalue(L, 1);
        asyncSocket.readCallback = [skin luaRef:refTable];
    }

    [skin requireModule:"hs.socket"];
    lua_getfield(skin.L, -1, "timeout");
    asyncSocket.timeout = lua_tonumber(skin.L, -1);

    asyncSocketUserData *userData = lua_newuserdata(L, sizeof(asyncSocketUserData));
    memset(userData, 0, sizeof(asyncSocketUserData));
    userData->asyncSocket = (__bridge_retained void*)asyncSocket;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.socket.parseAddress(sockaddr) -> table or nil
/// Function
/// Parses a binary socket address structure into a readable table
///
/// Parameters:
///  * sockaddr - A binary socket address structure, usually obtained from the [`info`](#info) method or in [`hs.socket.udp`](./hs.socket.udp.html)'s [read callback](./hs.socket.udp.html#setCallback)
///
/// Returns:
///  * A table describing the address with the following keys or `nil`:
///   * host - A string containing the host IP
///   * port - A number containing the port
///   * addressFamily - A number containing the address family
///
/// Notes:
///  * Some address family definitions from `<sys/socket.h>`:
///
/// address family | number | description
/// :--- | :--- | :---
/// AF_UNSPEC | 0 | unspecified
/// AF_UNIX | 1 | local to host (pipes)
/// AF_LOCAL | AF_UNIX | backward compatibility
/// AF_INET | 2 | internetwork: UDP, TCP, etc.
/// AF_NS | 6 | XEROX NS protocols
/// AF_CCITT | 10 | CCITT protocols, X.25 etc
/// AF_APPLETALK | 16 | Apple Talk
/// AF_ROUTE | 17 | Internal Routing Protocol
/// AF_LINK | 18 | Link layer interface
/// AF_INET6 | 30 | IPv6
///
static int socket_parseAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    const char *addressData = lua_tostring(L, 1);
    NSUInteger addressDataLength = lua_rawlen(L, 1);
    NSData *address = [NSData dataWithBytes:addressData length:addressDataLength];
    NSString *host;
    UInt16 port;
    sa_family_t addressFamily;

    if ([GCDAsyncSocket getHost:&host port:&port family:&addressFamily fromAddress:address])
        [skin pushNSObject:@{@"host": host, @"port": @(port), @"addressFamily": @(addressFamily)}];
    else
        lua_pushnil(L);

    return 1;
}

/// hs.socket:connect({host, port}|path[, fn]) -> self or nil
/// Method
/// Connects an unconnected [`hs.socket`](#new) instance
///
/// Parameters:
///  * host - A string containing the hostname or IP address
///  * port - A port number [1-65535]
///  * path - A string containing the path to the Unix domain socket
///  * fn - An optional single-use callback function to execute after establishing the connection. Receives no parameters
///
/// Returns:
///  * The [`hs.socket`](#new) object or `nil` if an error occurred
///
/// Notes:
///  * Either a host/port pair OR a Unix domain socket path must be supplied. If no port is passed, the first param is assumed to be a path to the socket file
///
static int socket_connect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY|LS_TOPTIONAL, LS_TANY|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    NSError *err;

    if (lua_type(L, 3) == LUA_TNUMBER) { //
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER|LS_TINTEGER, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
        NSString *theHost = [skin toNSObjectAtIndex:2];
        UInt16 thePort = [[skin toNSObjectAtIndex:3] unsignedShortValue];
        if (lua_type(L, 4) == LUA_TFUNCTION) {
            lua_pushvalue(L, 4);
            asyncSocket.connectCallback = [skin luaRef:refTable];
        }

        if (![asyncSocket connectToHost:theHost onPort:thePort withTimeout:asyncSocket.timeout error:&err]) {
            asyncSocket.connectCallback = [skin luaUnref:refTable ref:asyncSocket.connectCallback];
            [LuaSkin logError:[NSString stringWithFormat:@"Unable to connect to host/port: %@",
                               [err localizedDescription]]];
            lua_pushnil(L);
            return 1;
        }

    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
        NSString *thePath = [[skin toNSObjectAtIndex:2] stringByExpandingTildeInPath];
        if (lua_type(L, 3) == LUA_TFUNCTION) {
            lua_pushvalue(L, 3);
            asyncSocket.connectCallback = [skin luaRef:refTable];
        }

        NSURL *connectURL = [NSURL URLWithString:thePath];
        if (connectURL) {
            if (![asyncSocket connectToUrl:connectURL withTimeout:asyncSocket.timeout error:&err]) {
                asyncSocket.connectCallback = [skin luaUnref:refTable ref:asyncSocket.connectCallback];
                [LuaSkin logError:[NSString stringWithFormat:@"Unable to connect to Unix domain socket: %@",
                                   [err localizedDescription]]];
                lua_pushnil(L);
                return 1;
            }
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:listen(port|path) -> self or nil
/// Method
/// Binds an unconnected [`hs.socket`](#new) instance to a port or path (Unix domain socket) for listening
///
/// Parameters:
///  * port - A port number [0-65535]. Ports [1-1023] are privileged. Port 0 allows the OS to select any available port
///  * path - A string containing the path to the Unix domain socket
///
/// Returns:
///  * The [`hs.socket`](#new) object or `nil` if an error occurred
///
static int socket_listen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER|LS_TSTRING, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    NSError *err;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        UInt16 thePort = [[skin toNSObjectAtIndex:2] unsignedShortValue];
        if ([asyncSocket acceptOnPort:thePort error:&err]) {
            asyncSocket.userData = SERVER;
        } else {
            [LuaSkin logError:[NSString stringWithFormat:@"Unable to bind port: %@",
                               [err localizedDescription]]];
            lua_pushnil(L);
            return 1;
        }
    } else {
        NSString *thePath = [skin toNSObjectAtIndex:2];
        thePath = [thePath stringByExpandingTildeInPath];
        NSURL *acceptURL = [NSURL URLWithString:thePath];
        if (acceptURL) {
            if ([asyncSocket acceptOnUrl:acceptURL error:&err]) {
                asyncSocket.unixSocketPath = thePath;
                asyncSocket.userData = SERVER;
            } else {
                [LuaSkin logError:[NSString stringWithFormat:@"Unable to bind Unix domain path: %@",
                                   [err localizedDescription]]];
                lua_pushnil(L);
                return 1;
            }
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:disconnect() -> self
/// Method
/// Disconnects the [`hs.socket`](#new) instance, freeing it for reuse
///
/// Parameters:
///  * None
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
/// Notes:
///  * If called on a listening socket with multiple connections, each client is disconnected
///
static int socket_disconnect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);

    [asyncSocket disconnect];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:read(delimiter[, tag]) -> self or nil
/// Method
/// Read data from the socket. Results are passed to the [callback function](#setCallback), which must be set to use this method
///
/// Parameters:
///  * delimiter - Either a number of bytes to read, or a string delimiter such as "&#92;n" or "&#92;r&#92;n". Data is read up to and including the delimiter
///  * tag - An optional integer to assist with labeling reads. It is passed to the callback to assist with implementing [state machines](https://github.com/robbiehanson/CocoaAsyncSocket/wiki/Intro_GCDAsyncSocket#reading--writing) for processing complex protocols
///
/// Returns:
///  * The [`hs.socket`](#new) object or `nil` if an error occured
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is read from each of them
///
static int socket_read(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER|LS_TSTRING, LS_TNUMBER|LS_TINTEGER|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    long tag = (lua_type(L, 3) == LUA_TNUMBER) ? lua_tointeger(L, 3) : -1;

    if (asyncSocket.readCallback == LUA_NOREF) {
        [LuaSkin logError:@"No callback defined!"];
        lua_pushnil(L);
        return 1;
    }

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER: {
            NSNumber *bytesToRead = [skin toNSObjectAtIndex:2];
            NSUInteger bytes = [bytesToRead unsignedIntegerValue];
            [asyncSocket readDataToLength:bytes withTimeout:asyncSocket.timeout tag:tag];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncTcpSocket *client in asyncSocket.connectedSockets)
                        [client readDataToLength:bytes withTimeout:asyncSocket.timeout tag:tag];
                }
            }
        }
            break;
        case LUA_TSTRING: {
            NSString *separatorString = [skin toNSObjectAtIndex:2];
            NSData *separator = [separatorString dataUsingEncoding:NSUTF8StringEncoding];
            [asyncSocket readDataToData:separator withTimeout:asyncSocket.timeout tag:tag];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncTcpSocket *client in asyncSocket.connectedSockets)
                        [client readDataToData:separator withTimeout:asyncSocket.timeout tag:tag];
                }
            }
        }
            break;
        default:
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:write(message[, tag][, fn]) -> self
/// Method
/// Write data to the socket
///
/// Parameters:
///  * message - A string containing data to be sent on the socket
///  * tag - An optional integer to assist with labeling writes
///  * fn - An optional single-use callback function to execute after writing data to the socket. Receives the tag parameter
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is broadcasted to all connected sockets
///
static int socket_write(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER|LS_TINTEGER|LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    NSData *message = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly];
    long tag = (lua_type(L, 3) == LUA_TNUMBER) ? lua_tointeger(L, 3) : -1;

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        asyncSocket.writeCallback = [skin luaRef:refTable];
    }
    if (lua_type(L, 3) != LUA_TFUNCTION && lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4);
        asyncSocket.writeCallback = [skin luaRef:refTable];
    }

    if (asyncSocket.userData == SERVER) {
        @synchronized(asyncSocket.connectedSockets) {
            for (HSAsyncTcpSocket *client in asyncSocket.connectedSockets)
                [client writeData:message
                      withTimeout:asyncSocket.timeout tag:tag];
        }
    } else [asyncSocket writeData:message
                      withTimeout:asyncSocket.timeout tag:tag];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:setCallback([fn]) -> self
/// Method
/// Sets the read callback for the [`hs.socket`](#new) instance. Must be set to read data from the socket
///
/// Parameters:
///  * fn - An optional callback function to process data read from the socket. `nil` or no argument clears the callback. The callback receives 2 parameters:
///    * data - The data read from the socket as a string
///    * tag - The integer tag associated with the read call, which defaults to -1
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    asyncSocket.readCallback = [skin luaUnref:refTable ref:asyncSocket.readCallback];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        asyncSocket.readCallback = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:setTimeout(timeout) -> self
/// Method
/// Sets the timeout for the socket operations. If the timeout value is negative, the operations will not use a timeout, which is the default
///
/// Parameters:
///  * timeout - A number containing the timeout duration, in seconds
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_setTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    NSTimeInterval timeout = lua_tonumber(L, 2);
    asyncSocket.timeout = timeout;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:startTLS([verify][, peerName]) -> self
/// Method
/// Secures the socket with TLS. The socket will disconnect immediately if TLS negotiation fails
///
/// Parameters:
///  * verify - An optional boolean that, if `false`, allows TLS handshaking with servers with self-signed certificates and does not evaluate the chain of trust. Defaults to `true` and omitted if `peerName` is supplied
///  * peerName - An optional string containing the fully qualified domain name of the peer to validate against — for example, `store.apple.com`. It should match the name in the X.509 certificate given by the remote party. See notes below
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
/// Notes:
/// * IMPORTANT SECURITY NOTE:
/// The default settings will check to make sure the remote party's certificate is signed by a
/// trusted 3rd party certificate agency (e.g. verisign) and that the certificate is not expired.
/// However it will not verify the name on the certificate unless you
/// give it a name to verify against via `peerName`.
/// The security implications of this are important to understand.
/// Imagine you are attempting to create a secure connection to MySecureServer.com,
/// but your socket gets directed to MaliciousServer.com because of a hacked DNS server.
/// If you simply use the default settings, and MaliciousServer.com has a valid certificate,
/// the default settings will not detect any problems since the certificate is valid.
/// To properly secure your connection in this particular scenario you
/// should set `peerName` to "MySecureServer.com".
///
static int socket_startTLS(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);
    NSDictionary *tlsSettings = nil;

    if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2) == false) {
        tlsSettings = @{@"GCDAsyncSocketManuallyEvaluateTrust": @YES};
    } else if (lua_type(L, 2) == LUA_TSTRING) {
        NSString *peerName = [skin toNSObjectAtIndex:2];
        tlsSettings = @{@"kCFStreamSSLPeerName": peerName};
    }

    [asyncSocket startTLS:tlsSettings];

    lua_pushvalue(L, 1);
    return 1;
}

static NSInteger get_socket_connections(HSAsyncTcpSocket* asyncSocket) {
    NSInteger connections;

    if (asyncSocket.userData == SERVER)
        connections = asyncSocket.connectedSockets.count;
    else
        connections = asyncSocket.isConnected ? 1 : 0;

    return connections;
}

/// hs.socket:connected() -> bool
/// Method
/// Returns the connection status of the [`hs.socket`](#new) instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if connected, otherwise `false`
///
static int socket_connected(lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);

    lua_pushboolean(L, get_socket_connections(asyncSocket) ? true : false);
    return 1;
}

/// hs.socket:connections() -> number
/// Method
/// Returns the number of connections to the socket, which is at most 1 for default (non-listening) sockets
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of connections to the socket
///
static int socket_connections(lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);

    lua_pushinteger(L, get_socket_connections(asyncSocket));
    return 1;
}

/// hs.socket:info() -> table
/// Method
/// Returns information on the [`hs.socket`](#new) instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys:
///   * connectedAddress - `string` (`sockaddr` struct)
///   * connectedHost - `string`
///   * connectedPort - `number`
///   * connectedURL - `string`
///   * connections - `number`
///   * isConnected - `boolean`
///   * isDisconnected - `boolean`
///   * isIPv4 - `boolean`
///   * isIPv4Enabled - `boolean`
///   * isIPv4PreferredOverIPv6 - `boolean`
///   * isIPv6 - `boolean`
///   * isIPv6Enabled - `boolean`
///   * isSecure - `boolean`
///   * localAddress - `string` (`sockaddr` struct)
///   * localHost - `string`
///   * localPort - `number`
///   * timeout - `number`
///   * unixSocketPath - `string`
///   * userData - `string`
///
static int socket_info(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);

    NSDictionary *info = @{
        @"connectedAddress" : asyncSocket.connectedAddress ?: @"",
        @"connectedHost" : asyncSocket.connectedHost ?: @"",
        @"connectedPort" : @(asyncSocket.connectedPort),
        @"connectedURL" : asyncSocket.connectedUrl ?: @"",
        @"connections" : @(get_socket_connections(asyncSocket)),
        @"isConnected": @(asyncSocket.isConnected),
        @"isDisconnected": @(asyncSocket.isDisconnected),
        @"isIPv4": @(asyncSocket.isIPv4),
        @"isIPv4Enabled": @(asyncSocket.isIPv4Enabled),
        @"isIPv4PreferredOverIPv6": @(asyncSocket.isIPv4PreferredOverIPv6),
        @"isIPv6": @(asyncSocket.isIPv6),
        @"isIPv6Enabled": @(asyncSocket.isIPv6Enabled),
        @"isSecure": @(asyncSocket.isSecure),
        @"localAddress" : asyncSocket.localAddress ?: @"",
        @"localHost" : asyncSocket.localHost ?: @"",
        @"localPort" : @(asyncSocket.localPort),
        @"timeout" : @(asyncSocket.timeout),
        @"unixSocketPath" : asyncSocket.unixSocketPath ?: @"",
        @"userData" : asyncSocket.userData ?: @"",
    };

    [skin pushNSObject:info];
    return 1;
}


// Library registration functions
static int userdata_tostring(lua_State* L) {
    HSAsyncTcpSocket* asyncSocket = getUserData(L, 1);

    BOOL isServer = (asyncSocket.userData == SERVER) ? true : false;
    NSString *theHost = isServer ? asyncSocket.localHost : asyncSocket.connectedHost;
    UInt16 thePort = isServer ? asyncSocket.localPort : asyncSocket.connectedPort;
    NSString *theAddress = asyncSocket.unixSocketPath ?: [NSString stringWithFormat:@"%@:%hu", theHost, thePort];
    NSString *userData = isServer ? [NSString stringWithFormat:@"%s(server)", USERDATA_TAG] : [NSString stringWithUTF8String:USERDATA_TAG];

    lua_pushstring(L, [[NSString stringWithFormat:@"%@: %@ (%p)", userData, theAddress, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

static int userdata_gc(lua_State *L) {
    asyncSocketUserData *userData = lua_touserdata(L, 1);
    HSAsyncTcpSocket* asyncSocket = (__bridge_transfer HSAsyncTcpSocket *)userData->asyncSocket;
    userData->asyncSocket = nil;

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [asyncSocket disconnect];
    [asyncSocket setDelegate:nil delegateQueue:NULL];
    asyncSocket.readCallback = [skin luaUnref:refTable ref:asyncSocket.readCallback];
    asyncSocket.writeCallback = [skin luaUnref:refTable ref:asyncSocket.writeCallback];
    asyncSocket.connectCallback = [skin luaUnref:refTable ref:asyncSocket.connectCallback];
    asyncSocket = nil;

    return 0;
}

// Functions for returned object when module loads
static const luaL_Reg moduleLib[] = {
    {"new",             socket_new},
    {"parseAddress",    socket_parseAddress},
    {NULL,              NULL} // This must end with an empty struct
};

// Metatable for created objects when _new invoked
static const luaL_Reg userdata_metaLib[] = {
    {"connect",         socket_connect},
    {"listen",          socket_listen},
    {"disconnect",      socket_disconnect},
    {"read",            socket_read},
    {"write",           socket_write},
    {"setCallback",     socket_setCallback},
    {"setTimeout",      socket_setTimeout},
    {"startTLS",        socket_startTLS},
    {"connected",       socket_connected},
    {"connections",     socket_connections},
    {"info",            socket_info},
    {"__tostring",      userdata_tostring},
    {"__gc",            userdata_gc},
    {NULL,              NULL} // This must end with an empty struct
};

int luaopen_hs_libsocket(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    return 1;
}
