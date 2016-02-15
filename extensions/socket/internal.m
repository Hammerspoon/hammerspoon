#import <LuaSkin/LuaSkin.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

// Definitions
@interface HSAsyncSocket : GCDAsyncSocket
@property int callback;
@property NSMutableArray* connectedSockets;
@end

// Userdata for hs.socket objects
#define getUserData(L, idx) (__bridge HSAsyncSocket *)((asyncSocketUserData *)lua_touserdata(L, idx))->asyncSocket;

static const char *USERDATA_TAG = "hs.socket";

typedef struct _asyncSocketUserData {
    int selfRef;
    void *asyncSocket;
} asyncSocketUserData;

// These constants are used to set GCDAsyncSocket's built-in userData to distinguish socket types.
// Foreign client sockets (from netcat for example) connecting to our listening sockets are of type
// GCDAsyncSocket and attempting to place our subclass's new properties on them will fail
static const NSString *DEFAULT = @"DEFAULT";
static const NSString *SERVER = @"SERVER";
static const NSString *CLIENT = @"CLIENT";

// Callback on data reads
static int refTable = LUA_NOREF;

static void callback(HSAsyncSocket *asyncSocket, NSData *data) {
    LuaSkin *skin = [LuaSkin shared];
    NSString *utf8Data = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    [skin pushLuaRef:refTable ref:asyncSocket.callback];
    [skin pushNSObject: utf8Data];

    if (![skin protectedCallAndTraceback:1 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logError:[NSString stringWithFormat:@"hs.socket callback error: %s", errorMsg]];
    }
}

// Delegate implementation
@implementation HSAsyncSocket

- (id)init {
    self.callback = LUA_NOREF;
    self.connectedSockets = [[NSMutableArray alloc] init];
    return [super initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)socket:(HSAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [[LuaSkin shared] logInfo:@"Socket connected"];

    sock.userData = DEFAULT;
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
        [[LuaSkin shared] logInfo:@"Client disconnected"];

        @synchronized(self.connectedSockets) {
            [self.connectedSockets removeObject:sock];
        }
    } else if (sock.userData == SERVER) {
        [[LuaSkin shared] logInfo:@"Server disconnected"];

        @synchronized(self.connectedSockets) {
            for (HSAsyncSocket *client in sock.connectedSockets){
                [client disconnect];
            }
        }
    } else {
        [[LuaSkin shared] logInfo:@"Socket disconnected"];
    }
    sock.userData = nil;
}

- (void)socket:(HSAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [[LuaSkin shared] logInfo:@"Data written to socket"];
}

- (void)socket:(HSAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag  {
    [[LuaSkin shared] logInfo:@"Data read from socket"];

    callback(self, data);
}

@end


// Establish connection
static void connectSocket(HSAsyncSocket *asyncSocket, NSString *host, NSNumber *port) {
    NSError *err;
    if (![asyncSocket connectToHost:host onPort:[port unsignedShortValue] error:&err]) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"Unable to connect: %@", err]];
    }
}

// Establish listening port
static void listenSocket(HSAsyncSocket *asyncSocket, NSNumber *port) {
    NSError *err;
    if (![asyncSocket acceptOnPort:[port unsignedShortValue] error:&err]) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"Unable to connect: %@", err]];
    } else {
        asyncSocket.userData = SERVER;
    }
}

/// hs.socket.new([host], port[, fn]) -> hs.socket object
/// Constructor
/// Creates an asynchronous TCP socket object for reading (with callbacks) and writing
///
/// Parameters:
///  * host - A optional string containing the hostname or IP address. If `nil`, a listening socket is created (same as `hs.socket.server`)
///  * port - A port number [1024-65535]. Ports [1-1023] are privileged
///  * fn - An optional callback function accepting a single parameter to process data. Can be set with the `setCallback` method
///
/// Returns:
///  * An `hs.socket` object
///
static int socket_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING|LS_TNIL, LS_TNUMBER, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket *asyncSocket = [[HSAsyncSocket alloc] init];
    NSString *theHost = [skin toNSObjectAtIndex:1];
    NSNumber *thePort = [skin toNSObjectAtIndex:2];

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        asyncSocket.callback = [skin luaRef:refTable];
    }

    if (![theHost isEqual:[NSNull null]]) {
        connectSocket(asyncSocket, theHost, thePort);
    } else {
        listenSocket(asyncSocket, thePort);
    }

    // Create the userdata object
    asyncSocketUserData *userData = lua_newuserdata(L, sizeof(asyncSocketUserData));
    memset(userData, 0, sizeof(asyncSocketUserData));
    userData->asyncSocket = (__bridge_retained void*)asyncSocket;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.socket:connect() -> self
/// Method
/// Connects an unconnected `hs.socket` instance
///
/// Parameters:
///  * host - A string containing the hostname or IP address
///  * port - A port number [1024-65535]. Ports [1-1023] are privileged
///
/// Returns:
///  * The `hs.socket` object
///
static int socket_connect(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSString *theHost = [skin toNSObjectAtIndex:2];
    NSNumber *thePort = [skin toNSObjectAtIndex:3];

    connectSocket(asyncSocket, theHost, thePort);

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:listen() -> self
/// Method
/// Binds an unconnected `hs.socket` instance to a port for listening
///
/// Parameters:
///  * port - A port number [1024-65535]. Ports [1-1023] are privileged
///
/// Returns:
///  * The `hs.socket` object
///
static int socket_listen(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSNumber *thePort = [skin toNSObjectAtIndex:2];

    listenSocket(asyncSocket, thePort);

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:disconnect() -> self
/// Method
/// Disconnects the socket instance, freeing it for reuse
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.socket` object
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

/// hs.socket.read(delimiter) -> self
/// Method
/// Read data from the socket. Data is passed to the callback function, which is required for this method
///
/// Parameters:
///  * delimiter - Either a number of bytes to read, or a string delimiter such as `\n` or `\r\n`. Data is read up to and including the delimiter
///
/// Returns:
///  * The `hs.socket` object or none if error
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is read from each of them
///
static int socket_read(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING|LS_TNUMBER, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    if (!asyncSocket.callback || asyncSocket.callback==LUA_NOREF) {
        [skin logError:@"No callback defined!"];
        return 0;
    }

    lua_getglobal(L, "hs"); lua_getfield(L, -1, "socket"); lua_getfield(L, -1, "timeout");
    NSTimeInterval timeout = lua_tonumber(L, -1);

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER: {
            NSNumber *bytesToRead = [skin toNSObjectAtIndex:2];
            NSUInteger bytes = [bytesToRead unsignedIntegerValue];
            [asyncSocket readDataToLength:bytes withTimeout:timeout tag:-1];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                        [client readDataToLength:bytes withTimeout:timeout tag:-1];
                    }
                }
            }
        } break;

        case LUA_TSTRING: {
            NSString *separatorString = [skin toNSObjectAtIndex:2];
            NSData *separator = [separatorString dataUsingEncoding:NSUTF8StringEncoding];
            [asyncSocket readDataToData:separator withTimeout:timeout tag:-1];
            if (asyncSocket.userData == SERVER) {
                @synchronized(asyncSocket.connectedSockets) {
                    for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                        [client readDataToData:separator withTimeout:timeout tag:-1];
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

/// hs.socket.write(message) -> self
/// Method
/// Write data to the socket
///
/// Parameters:
///  * message - A string containing data to be sent on the socket
///
/// Returns:
///  * The `hs.socket` object
///
/// Notes:
///  * If called on a listening socket with multiple connections, data is broadcasted to all connected sockets
///
static int socket_write(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSString *message = [skin toNSObjectAtIndex:2];

    lua_getglobal(L, "hs"); lua_getfield(L, -1, "socket"); lua_getfield(L, -1, "timeout");
    NSTimeInterval timeout = lua_tonumber(L, -1);

    if (asyncSocket.userData != SERVER) {
        [asyncSocket writeData:[message dataUsingEncoding:NSUTF8StringEncoding] withTimeout:timeout tag:-1];
    } else {
        @synchronized(asyncSocket.connectedSockets) {
            for (HSAsyncSocket *client in asyncSocket.connectedSockets){
                [client writeData:[message dataUsingEncoding:NSUTF8StringEncoding] withTimeout:timeout tag:-1];
            }
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:setCallback([fn]) -> self
/// Method
/// Sets the callback for the socket. Required for working with read data
///
/// Parameters:
///  * fn - An optional callback function with single parameter containing data read from the socket. A `nil` argument or nothing clears the callback
///
/// Returns:
///  * The `hs.socket` object
///
static int socket_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    asyncSocket.callback = [skin luaUnref:refTable ref:asyncSocket.callback];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        asyncSocket.callback = [skin luaRef:refTable];
    } else {
        asyncSocket.callback = LUA_NOREF;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket:connected() -> bool
/// Method
/// Returns the connection status of the socket instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if connected, otherwise false
///
static int socket_connected(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    BOOL isConnected;

    if (asyncSocket.userData==SERVER) {
        isConnected = asyncSocket.connectedSockets.count;
    } else {
        isConnected = [asyncSocket isConnected];
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
///  * True if connected, otherwise false
///
static int socket_connections(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);
    NSInteger connections;
    if (asyncSocket.userData==SERVER) {
        connections = asyncSocket.connectedSockets.count;
    } else {
        connections = asyncSocket.isConnected ? 1 : 0;
    }

    lua_pushinteger(L, connections);
    return 1;
}

/// hs.socket:info() -> table
/// Method
/// Returns information on the socket instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys:
///   * connectedHost
///   * connectedPort
///   * localHost
///   * localPort
///   * isConnected
///   * isIPv4
///   * isIPv6
///   * isIPv4Enabled
///   * isIPv6Enabled
///   * isIPv4PreferredOverIPv6
///   * isSecure
///
static int socket_info(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    NSString *socketType = asyncSocket.userData;
    NSString *connectedHost = [asyncSocket connectedHost];
    NSNumber *connectedPort = [NSNumber numberWithUnsignedShort:[asyncSocket connectedPort]];
    NSString *localHost = [asyncSocket localHost];
    NSNumber *localPort = [NSNumber numberWithUnsignedShort:[asyncSocket localPort]];
    NSNumber *isConnected = [NSNumber numberWithBool:[asyncSocket isConnected]];
    NSNumber *isIPv4 = [NSNumber numberWithBool:[asyncSocket isIPv4]];
    NSNumber *isIPv6 = [NSNumber numberWithBool:[asyncSocket isIPv6]];
    NSNumber *isIPv4Enabled = [NSNumber numberWithBool:[asyncSocket isIPv4Enabled]];
    NSNumber *isIPv6Enabled = [NSNumber numberWithBool:[asyncSocket isIPv6Enabled]];
    NSNumber *isIPv4PreferredOverIPv6 = [NSNumber numberWithBool:[asyncSocket isIPv4PreferredOverIPv6]];
    NSNumber *isSecure = [NSNumber numberWithBool:[asyncSocket isSecure]];

    connectedHost = connectedHost ? connectedHost : @"";
    localHost = localHost ? localHost : @"";
    socketType = socketType ? socketType : @"";

    NSDictionary *info = @{
        @"socketType" : socketType,
        @"connectedHost" : connectedHost,
        @"connectedPort" : connectedPort,
        @"localHost" : localHost,
        @"localPort" : localPort,
        @"isConnected": isConnected,
        @"isIPv4": isIPv4,
        @"isIPv6": isIPv6,
        @"isIPv4Enabled": isIPv4Enabled,
        @"isIPv6Enabled": isIPv6Enabled,
        @"isIPv4PreferredOverIPv6": isIPv4PreferredOverIPv6,
        @"isSecure": isSecure,
    };

    [skin pushNSObject:info];
    return 1;
}


static int socket_objectGC(lua_State *L) {
    asyncSocketUserData *userData = lua_touserdata(L, 1);
    HSAsyncSocket* asyncSocket = (__bridge_transfer HSAsyncSocket *)userData->asyncSocket;
    userData->asyncSocket = nil;

    [asyncSocket disconnect];
    [asyncSocket setDelegate:nil delegateQueue:NULL];
    asyncSocket.callback = [[LuaSkin shared] luaUnref:refTable ref:asyncSocket.callback];
    asyncSocket = nil;

    return 0;
}

static int userdata_tostring(lua_State* L) {
    HSAsyncSocket* asyncSocket = getUserData(L, 1);

    BOOL isServer = (asyncSocket.userData == SERVER) ? true : false;
    NSString *theHost = isServer ? [asyncSocket localHost] : [asyncSocket connectedHost];
    uint16_t thePort = isServer ? [asyncSocket localPort] : [asyncSocket connectedPort];

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@:%hu (%p)", USERDATA_TAG, theHost, thePort, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

static const luaL_Reg socketLib[] = {
    {"new", socket_new},

    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg socketObjectLib[] = {
    {"connect", socket_connect},
    {"listen", socket_listen},
    {"disconnect", socket_disconnect},
    {"read", socket_read},
    {"write", socket_write},
    {"setCallback", socket_setCallback},
    {"connected", socket_connected},
    {"connections", socket_connections},
    {"info", socket_info},

    {"__tostring", userdata_tostring},
    {"__gc", socket_objectGC},

    {NULL, NULL} // This must end with an empty struct
};

int luaopen_hs_socket_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:"hs.socket"
                                     functions:socketLib
                                 metaFunctions:nil
                               objectFunctions:socketObjectLib];

    return 1;
}
