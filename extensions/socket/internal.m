#import <LuaSkin/LuaSkin.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "socket.h"

// Definitions
@interface HSAsyncSocket : GCDAsyncSocket
@property int readCallback;
@property int writeCallback;
@property int connectCallback;
@property NSTimeInterval timeout;
@property NSMutableArray* connectedSockets;
@end

// Userdata for hs.socket objects
static const char *USERDATA_TAG = "hs.socket";
#define getUserData(L, idx) (__bridge HSAsyncSocket *)((asyncSocketUserData *)lua_touserdata(L, idx))->asyncSocket;


// Delegate implementation
@implementation HSAsyncSocket

- (id)init {
    self.readCallback = LUA_NOREF;
    self.writeCallback = LUA_NOREF;
    self.connectCallback = LUA_NOREF;
    self.timeout = -1;
    self.connectedSockets = [[NSMutableArray alloc] init];
    return [super initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)socket:(HSAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    LuaSkin *skin = [LuaSkin shared];
    [skin logInfo:@"TCP socket connected"];
    sock.userData = DEFAULT;

    if (sock.connectCallback != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:sock.connectCallback];
        sock.connectCallback = [skin luaUnref:refTable ref:sock.connectCallback];

        if (![skin protectedCallAndTraceback:0 nresults:0]) {
            const char *errorMsg = lua_tostring(skin.L, -1);
            [skin logError:[NSString stringWithFormat:@"%s connect callback error: %s", USERDATA_TAG, errorMsg]];
        }
    }
}

- (void)socket:(HSAsyncSocket *)sock didAcceptNewSocket:(HSAsyncSocket *)newSocket {
    [[LuaSkin shared] logInfo:@"Client socket connected"];

    newSocket.userData = CLIENT;

    @synchronized(self.connectedSockets) {
        [self.connectedSockets addObject:newSocket];
    }
}

- (void)socketDidDisconnect:(HSAsyncSocket *)sock withError:(NSError *)err {
    if (sock.userData == CLIENT) {
        [[LuaSkin shared] logInfo:[NSString stringWithFormat:@"Client disconnected %@", err]];

        @synchronized(self.connectedSockets) {
            [self.connectedSockets removeObject:sock];
        }
    } else if (sock.userData == SERVER) {
        [[LuaSkin shared] logInfo:[NSString stringWithFormat:@"Server disconnected %@", err]];

        @synchronized(self.connectedSockets) {
            for (HSAsyncSocket *client in sock.connectedSockets){
                [client disconnect];
            }
        }
    } else [[LuaSkin shared] logInfo:[NSString stringWithFormat:@"Socket disconnected %@", err]];

    sock.userData = nil;
}

- (void)socket:(HSAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    LuaSkin *skin = [LuaSkin shared];
    [skin logInfo:@"Data written to socket"];

    if (self.writeCallback != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:self.writeCallback];
        [skin pushNSObject: @(tag)];
        self.writeCallback = [skin luaUnref:refTable ref:self.writeCallback];

        if (![skin protectedCallAndTraceback:1 nresults:0]) {
            const char *errorMsg = lua_tostring(skin.L, -1);
            [skin logError:[NSString stringWithFormat:@"%s write callback error: %s", USERDATA_TAG, errorMsg]];
        }
    }
}

- (void)socket:(HSAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag  {
    LuaSkin *skin = [LuaSkin shared];
    [skin logInfo:@"Data read from socket"];
    NSString *utf8Data = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    [skin pushLuaRef:refTable ref:self.readCallback];
    [skin pushNSObject: utf8Data];
    [skin pushNSObject: @(tag)];

    if (![skin protectedCallAndTraceback:2 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logError:[NSString stringWithFormat:@"%s read callback error: %s", USERDATA_TAG, errorMsg]];
    }
}

- (void)socket:(HSAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL))completionHandler {
    // Allow TLS handshake without trust evaluation for self-signed certificates
    // This is only called if startTLS is invoked with option GCDAsyncSocketManuallyEvaluateTrust == YES
    if (completionHandler) completionHandler(YES);
}

- (void)socketDidSecure:(HSAsyncSocket *)sock {
    [[LuaSkin shared] logInfo:@"Socket secured"];
}

@end


/// hs.socket.new([fn]) -> hs.socket object
/// Constructor
/// Creates an unconnected asynchronous TCP socket object
///
/// Parameters:
///  * fn - An optional callback function to process data on reads. Can also be set with the [`setCallback`](#setCallback) method
///
/// Returns:
///  * An [`hs.socket`](#new) object
///
static int socket_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncSocket *asyncSocket = [[HSAsyncSocket alloc] init];

    if (lua_type(L, 1) == LUA_TFUNCTION) {
        lua_pushvalue(L, 1);
        asyncSocket.readCallback = [skin luaRef:refTable];
    }

    lua_getglobal(skin.L, "hs"); lua_getfield(skin.L, -1, "socket"); lua_getfield(skin.L, -1, "timeout");
    asyncSocket.timeout = lua_tonumber(skin.L, -1);

    // Create the userdata object
    asyncSocketUserData *userData = lua_newuserdata(L, sizeof(asyncSocketUserData));
    memset(userData, 0, sizeof(asyncSocketUserData));
    userData->asyncSocket = (__bridge_retained void*)asyncSocket;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.socket.parseAddress(sockaddr) -> table
/// Function
/// Parses a binary sockaddr address into a readable table
///
/// Parameters:
///  * sockaddr - A binary address descriptor, usually obtained in the [`hs.socket.udp`](./hs.socket.udp.html) read callback or from the [`info`](#info) method
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    const char *addressData = lua_tostring(L, 1);
    NSUInteger addressDataLength = lua_rawlen(L, 1);
    NSData *address = [NSData dataWithBytes:addressData length:addressDataLength];

    NSString *host;
    UInt16 port;
    sa_family_t addressFamily;

    if ([GCDAsyncSocket getHost:&host port:&port family:&addressFamily fromAddress:address]) {
        NSDictionary *addressDict = @{ @"host": host,
                                       @"port": @(port),
                                       @"addressFamily": @(addressFamily) };

        [skin pushNSObject:addressDict];
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.socket:connect(host, port[, fn]) -> self
/// Method
/// Connects an unconnected [`hs.socket`](#new) instance
///
/// Parameters:
///  * host - A string containing the hostname or IP address
///  * port - A port number [1-65535]
///  * fn - An optional single-use callback function to execute after establishing the connection. Takes no parameters
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_connect(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSString *theHost = [skin toNSObjectAtIndex:2];
    UInt16 thePort = [[skin toNSObjectAtIndex:3] unsignedShortValue];

    if (lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4);
        asyncSocket.connectCallback = [skin luaRef:refTable];
    }

    NSError *err;
    if (![asyncSocket connectToHost:theHost onPort:thePort withTimeout:asyncSocket.timeout error:&err]) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"Unable to connect: %@", err]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:listen(port) -> self
/// Method
/// Binds an unconnected [`hs.socket`](#new) instance to a port for listening
///
/// Parameters:
///  * port - A port number [0-65535]. Ports [1-1023] are privileged. Port 0 allows the OS to select any available port
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_listen(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];
    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    UInt16 thePort = [[skin toNSObjectAtIndex:2] unsignedShortValue];

    NSError *err;
    if (![asyncSocket acceptOnPort:thePort error:&err]) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"Unable to bind port: %@", err]];
    } else {
        asyncSocket.userData = SERVER;
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    [asyncSocket disconnect];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:read(delimiter[, tag]) -> self
/// Method
/// Read data from the socket. Results are passed to the callback function, which is required for this method
///
/// Parameters:
///  * delimiter - Either a number of bytes to read, or a string delimiter such as `\n` or `\r\n`. Data is read up to and including the delimiter
///  * tag - An optional integer to assist with labeling reads that is passed to the read callback
///
/// Returns:
///  * The [`hs.socket`](#new) object or `nil` if no callback error
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is read from each of them
///
static int socket_read(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING|LS_TNUMBER, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    if (asyncSocket.readCallback == LUA_NOREF) {
        [skin logError:@"No callback defined!"];
        return 0;
    }

    long tag = -1;
    if (lua_type(L, 3) == LUA_TNUMBER) tag = lua_tointeger(L, 3);

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER: {
            NSNumber *bytesToRead = [skin toNSObjectAtIndex:2];
            NSUInteger bytes = [bytesToRead unsignedIntegerValue];
            [asyncSocket readDataToLength:bytes withTimeout:asyncSocket.timeout tag:tag];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                        [client readDataToLength:bytes withTimeout:asyncSocket.timeout tag:tag];
                    }
                }
            }
        } break;

        case LUA_TSTRING: {
            NSString *separatorString = [skin toNSObjectAtIndex:2];
            NSData *separator = [separatorString dataUsingEncoding:NSUTF8StringEncoding];
            [asyncSocket readDataToData:separator withTimeout:asyncSocket.timeout tag:tag];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                        [client readDataToData:separator withTimeout:asyncSocket.timeout tag:tag];
                    }
                }
            }
        } break;

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
///  * fn - An optional single-use callback function to execute after writing data to the socket. Takes the tag parameter
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is broadcasted to all connected sockets
///
static int socket_write(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER|LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSString *message = [skin toNSObjectAtIndex:2];

    long tag = -1;
    if (lua_type(L, 3) == LUA_TNUMBER) {
        tag = lua_tointeger(L, 3);
    } else if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        asyncSocket.writeCallback = [skin luaRef:refTable];
    }
    if (lua_type(L, 3) != LUA_TFUNCTION && lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4);
        asyncSocket.writeCallback = [skin luaRef:refTable];
    }

    if (asyncSocket.userData != SERVER) {
        [asyncSocket writeData:[message dataUsingEncoding:NSUTF8StringEncoding] withTimeout:asyncSocket.timeout tag:tag];
    } else {
        @synchronized(asyncSocket.connectedSockets) {
            for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                [client writeData:[message dataUsingEncoding:NSUTF8StringEncoding] withTimeout:asyncSocket.timeout tag:tag];
            }
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:setCallback([fn]) -> self
/// Method
/// Sets the read callback for the [`hs.socket`](#new) instance. **Required** for working with read data
/// The callback's first parameter is the data read from the socket. The optional second parameter is the tag associated with the particular read operation
///
/// Parameters:
///  * fn - An optional callback function to process data read from the socket. A `nil` argument or nothing clears the callback
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
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
/// Sets the timeout for the socket operations. If the timeout value is negative, the operations will not use a timeout
///
/// Parameters:
///  * timeout - A number containing the timeout duration, in seconds
///
/// Returns:
///  * The [`hs.socket`](#new) object
///
static int socket_setTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    BOOL isConnected;

    if (asyncSocket.userData == SERVER) {
        isConnected = asyncSocket.connectedSockets.count;
    } else {
        isConnected = asyncSocket.isConnected;
    }

    lua_pushboolean(L, isConnected);
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSInteger connections;
    if (asyncSocket.userData == SERVER) {
        connections = asyncSocket.connectedSockets.count;
    } else {
        connections = asyncSocket.isConnected ? 1 : 0;
    }

    lua_pushinteger(L, connections);
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
///   * userData - `string`
///
static int socket_info(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    NSDictionary *info = @{
        @"connectedAddress" : asyncSocket.connectedAddress ?: @"",
        @"connectedHost" : asyncSocket.connectedHost ?: @"",
        @"connectedPort" : @(asyncSocket.connectedPort),
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
        @"userData" : asyncSocket.userData ?: @"",
    };

    [skin pushNSObject:info];
    return 1;
}

static int userdata_tostring(lua_State* L) {
    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    BOOL isServer = (asyncSocket.userData == SERVER) ? true : false;
    NSString *theHost = isServer ? asyncSocket.localHost : asyncSocket.connectedHost;
    UInt16 thePort = isServer ? asyncSocket.localPort : asyncSocket.connectedPort;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@:%hu (%p)", USERDATA_TAG, theHost, thePort, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

static int userdata_gc(lua_State *L) {
    asyncSocketUserData *userData = lua_touserdata(L, 1);
    HSAsyncSocket* asyncSocket = (__bridge_transfer HSAsyncSocket *)userData->asyncSocket;
    userData->asyncSocket = nil;

    [asyncSocket disconnect];
    [asyncSocket setDelegate:nil delegateQueue:NULL];
    asyncSocket.readCallback = [[LuaSkin shared] luaUnref:refTable ref:asyncSocket.readCallback];
    asyncSocket.writeCallback = [[LuaSkin shared] luaUnref:refTable ref:asyncSocket.writeCallback];
    asyncSocket.connectCallback = [[LuaSkin shared] luaUnref:refTable ref:asyncSocket.connectCallback];
    asyncSocket = nil;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Functions for returned object when module loads
static const luaL_Reg socketLib[] = {
    {"new",             socket_new},
    {"parseAddress",    socket_parseAddress},
    {NULL,              NULL} // This must end with an empty struct
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",            meta_gc},
    {NULL,              NULL} // This must end with an empty struct
};

// Metatable for created objects when _new invoked
static const luaL_Reg socketObjectLib[] = {
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

int luaopen_hs_socket_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:socketLib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:socketObjectLib];

    return 1;
}
