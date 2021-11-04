#import "socket.h"
#import "CocoaAsyncSocket/GCDAsyncUdpSocket.h"


// Userdata for hs.socket.udp objects
#define getUserData(L, idx) (__bridge HSAsyncUdpSocket *)((asyncSocketUserData *)lua_touserdata(L, idx))->asyncSocket;
static const char *USERDATA_TAG = "hs.socket.udp";


// UDP socket class declaration
@interface HSAsyncUdpSocket : GCDAsyncUdpSocket <GCDAsyncUdpSocketDelegate>
@property int readCallback;
@property int writeCallback;
@property int connectCallback;
@property NSTimeInterval timeout;
@end


// Lua callbacks
static void connectCallback(HSAsyncUdpSocket *asyncUdpSocket) {
    mainThreadDispatch(
        if (asyncUdpSocket.connectCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:asyncUdpSocket.connectCallback];
            asyncUdpSocket.connectCallback = [skin luaUnref:refTable ref:asyncUdpSocket.connectCallback];
            [skin protectedCallAndError:@"hs.socket.udp:connect" nargs:0 nresults:0];
            _lua_stackguard_exit(skin.L);
        }
    );
}

static void writeCallback(HSAsyncUdpSocket *asyncUdpSocket, long tag) {
    mainThreadDispatch(
        if (asyncUdpSocket.writeCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:asyncUdpSocket.writeCallback];
            [skin pushNSObject: @(tag)];
            asyncUdpSocket.writeCallback = [skin luaUnref:refTable ref:asyncUdpSocket.writeCallback];
            [skin protectedCallAndError:@"hs.socket.udp:write callback" nargs:1 nresults:0];
            _lua_stackguard_exit(skin.L);
        }
    );
}

static void readCallback(HSAsyncUdpSocket *asyncUdpSocket, NSData *data, NSData *address) {
    mainThreadDispatch(
        if (asyncUdpSocket.readCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:asyncUdpSocket.readCallback];
            [skin pushNSObject: [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            [skin pushNSObject: address];
            [skin protectedCallAndError:@"hs.socket.udp:read callback" nargs:2 nresults:0];
            _lua_stackguard_exit(skin.L);
        }
    );
}

// Delegate implementation
@implementation HSAsyncUdpSocket

- (id)init {
    dispatch_queue_t udpDelegateQueue = dispatch_queue_create("udpDelegateQueue", NULL);
    self.readCallback = LUA_NOREF;
    self.writeCallback = LUA_NOREF;
    self.connectCallback = LUA_NOREF;
    self.timeout = -1;

    return [super initWithDelegate:self delegateQueue:udpDelegateQueue];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    [LuaSkin logDebug:@"UDP socket connected"];
    self.userData = DEFAULT;
    if (self.connectCallback != LUA_NOREF)
        connectCallback(self);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    [LuaSkin logError:[NSString stringWithFormat:@"UDP socket did not connect: %@", [error localizedDescription]]];
    mainThreadDispatch(self.connectCallback = [[LuaSkin sharedWithState:NULL] luaUnref:refTable ref:self.connectCallback]);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    [LuaSkin logDebug:[NSString stringWithFormat:@"UDP socket closed: %@", [error localizedDescription]]];
    sock.userData = nil;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    [LuaSkin logDebug:@"Data written to UDP socket"];
    if (self.writeCallback != LUA_NOREF)
        writeCallback(self, tag);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    [LuaSkin logError:[NSString stringWithFormat:@"Data not sent on UDP socket: %@", [error localizedDescription]]];
    mainThreadDispatch(self.writeCallback = [[LuaSkin sharedWithState:NULL] luaUnref:refTable ref:self.writeCallback]);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    [LuaSkin logDebug:@"Data read from UDP socket"];
    if (self.readCallback != LUA_NOREF)
        readCallback(self, data, address);
}

@end


/// hs.socket.udp.new([fn]) -> hs.socket.udp object
/// Constructor
/// Creates an unconnected asynchronous UDP socket object
///
/// Parameters:
///  * fn - An optional [callback function](#setCallback) for reading data from the socket, settable here for convenience
///
/// Returns:
///  * An [`hs.socket.udp`](#new) object
///
static int socketudp_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket *asyncUdpSocket = [[HSAsyncUdpSocket alloc] init];

    if (lua_type(L, 1) == LUA_TFUNCTION) {
        lua_pushvalue(L, 1);
        asyncUdpSocket.readCallback = [skin luaRef:refTable];
    }

    [skin requireModule:"hs.socket"] ;
    for (NSString *field in @[@"udp", @"timeout"])
        lua_getfield(skin.L, -1, [field UTF8String]);
    asyncUdpSocket.timeout = lua_tonumber(skin.L, -1);

    asyncSocketUserData *userData = lua_newuserdata(L, sizeof(asyncSocketUserData));
    memset(userData, 0, sizeof(asyncSocketUserData));
    userData->asyncSocket = (__bridge_retained void*)asyncUdpSocket;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.socket.udp:connect(host, port[, fn]) -> self or nil
/// Method
/// Connects an unconnected [`hs.socket.udp`](#new) instance
///
/// Parameters:
///  * host - A string containing the hostname or IP address
///  * port - A port number [1-65535]
///  * fn - An optional single-use callback function to execute after establishing the connection. Receives no parameters
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occured
///
/// Notes:
/// * By design, UDP is a connectionless protocol, and connecting is not needed
/// * Choosing to connect to a specific host/port has the following effect:
///  * You will only be able to send data to the connected host/port
///  * You will only be able to receive data from the connected host/port
///  * You will receive ICMP messages that come from the connected host/port, such as "connection refused"
/// * The actual process of connecting a UDP socket does not result in any communication on the socket. It simply changes the internal state of the socket
/// * You cannot bind a socket after it has been connected
/// * You can only connect a socket once
///
static int socketudp_connect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER|LS_TINTEGER, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    NSString *theHost = [skin toNSObjectAtIndex:2];
    UInt16 thePort = [[skin toNSObjectAtIndex:3] unsignedShortValue];
    NSError *err;

    if (lua_type(L, 4) == LUA_TFUNCTION) {
        lua_pushvalue(L, 4);
        asyncUdpSocket.connectCallback = [skin luaRef:refTable];
    }

    if (![asyncUdpSocket connectToHost:theHost onPort:thePort error:&err]) {
        asyncUdpSocket.connectCallback = [skin luaUnref:refTable ref:asyncUdpSocket.connectCallback];
        [LuaSkin logError:[NSString stringWithFormat:@"Unable to connect: %@",
                           [err localizedDescription]]];
        lua_pushnil(L);
        return 1;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:listen(port) -> self or nil
/// Method
/// Binds an unconnected [`hs.socket.udp`](#new) instance to a port for listening
///
/// Parameters:
///  * port - A port number [0-65535]. Ports [1-1023] are privileged. Port 0 allows the OS to select any available port
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occured
///
static int socketudp_listen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    UInt16 thePort = [[skin toNSObjectAtIndex:2] unsignedShortValue];
    NSError *err;

    if (![asyncUdpSocket bindToPort:thePort error:&err]) {
        [LuaSkin logError:[NSString stringWithFormat:@"Unable to bind port: %@",
                           [err localizedDescription]]];
        lua_pushnil(L);
        return 1;
    }

    asyncUdpSocket.userData = SERVER;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:close() -> self
/// Method
/// Immediately closes the underlying socket, freeing the [`hs.socket.udp`](#new) instance for reuse. Any pending send operations are discarded
///
/// Parameters:
///  * None
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
static int socketudp_close(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    [asyncUdpSocket close];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:pause() -> self
/// Method
/// Suspends reading of packets from the socket. Call one of the receive methods to resume
///
/// Parameters:
///  * None
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
static int socketudp_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    [asyncUdpSocket pauseReceiving];

    lua_pushvalue(L, 1);
    return 1;
}

static BOOL socketudp_receiveContinuous(lua_State *L, BOOL readContinuous) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    NSError *err;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        asyncUdpSocket.readCallback = [skin luaUnref:refTable ref:asyncUdpSocket.readCallback];
        lua_pushvalue(L, 2);
        asyncUdpSocket.readCallback = [skin luaRef:refTable];
    }

    if (asyncUdpSocket.readCallback == LUA_NOREF) {
        [LuaSkin logError:@"No callback defined!"];
        return false;
    }

    readContinuous ? [asyncUdpSocket beginReceiving:&err] : [asyncUdpSocket receiveOnce:&err];

    if (err) {
        [LuaSkin logError:[NSString stringWithFormat:@"Unable to read from UDP socket: %@",
                           [err localizedDescription]]];
        return false;
    }

    return true;
}

/// hs.socket.udp:receive([fn]) -> self or nil
/// Method
/// Reads packets from the socket as they arrive. Results are passed to the [callback function](#setCallback), which must be set to use this method
///
/// Parameters:
///  * fn - Optionally supply the [read callback](#setCallback) here
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occured
///
/// Notes:
///  * There are two modes of operation for receiving packets: one-at-a-time & continuous
///  * In one-at-a-time mode, you call receiveOne every time you are ready process an incoming UDP packet
///  * Receiving packets one-at-a-time may be better suited for implementing certain state machine code where your state machine may not always be ready to process incoming packets
///  * In continuous mode, the callback is invoked immediately every time incoming udp packets are received
///  * Receiving packets continuously is better suited to real-time streaming applications
///  * You may switch back and forth between one-at-a-time mode and continuous mode
///  * If the socket is currently in one-at-a-time mode, calling this method will switch it to continuous mode
///
static int socketudp_receive(lua_State *L) {
    socketudp_receiveContinuous(L, true) ? lua_pushvalue(L, 1) : lua_pushnil(L);

    return 1;
}

/// hs.socket.udp:receiveOne([fn]) -> self or nil
/// Method
/// Reads a single packet from the socket. Results are passed to the [callback function](#setCallback), which must be set to use this method
///
/// Parameters:
///  * fn - Optionally supply the [read callback](#setCallback) here
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occured
///
/// Notes:
///  * There are two modes of operation for receiving packets: one-at-a-time & continuous
///  * In one-at-a-time mode, you call receiveOne every time you are ready process an incoming UDP packet
///  * Receiving packets one-at-a-time may be better suited for implementing certain state machine code where your state machine may not always be ready to process incoming packets
///  * In continuous mode, the callback is invoked immediately every time incoming udp packets are received
///  * Receiving packets continuously is better suited to real-time streaming applications
///  * You may switch back and forth between one-at-a-time mode and continuous mode
///  * If the socket is currently in continuous mode, calling this method will switch it to one-at-a-time mode
///
static int socketudp_receiveOne(lua_State *L) {
    socketudp_receiveContinuous(L, false) ? lua_pushvalue(L, 1) : lua_pushnil(L);

    return 1;
}

/// hs.socket.udp:send(message, host, port[, tag][, fn]) -> self
/// Method
/// Sends a packet to the destination address
///
/// Parameters:
///  * message - A string containing data to be sent on the socket
///  * host - A string containing the hostname or IP address
///  * port - A port number [1-65535]
///  * tag - An optional integer to assist with labeling writes
///  * fn - An optional single-use callback function to execute after sending the packet. Receives the tag parameter
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
/// Notes:
///  * For non-connected sockets, the remote destination is specified for each packet
///  * If the socket has been explicitly connected with [`connect`](#connect), only the message parameter and an optional tag and/or write callback can be supplied
///  * Recall that connecting is optional for a UDP socket
///  * For connected sockets, data can only be sent to the connected address
///
static int socketudp_send(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY|LS_TOPTIONAL, LS_TANY|LS_TOPTIONAL, LS_TANY|LS_TOPTIONAL, LS_TANY|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    
    NSData *sendData = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly];

    if (asyncUdpSocket.isConnected) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER|LS_TINTEGER|LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
        long tag = (lua_type(L, 3) == LUA_TNUMBER) ? lua_tointeger(L, 3) : -1;
        if (lua_type(L, 3) == LUA_TFUNCTION) {
            lua_pushvalue(L, 3);
            asyncUdpSocket.writeCallback = [skin luaRef:refTable];
        }
        if (lua_type(L, 3) != LUA_TFUNCTION && lua_type(L, 4) == LUA_TFUNCTION) {
            lua_pushvalue(L, 4);
            asyncUdpSocket.writeCallback = [skin luaRef:refTable];
        }
        
        if (sendData) {
            [asyncUdpSocket sendData:sendData
                         withTimeout:asyncUdpSocket.timeout
                                 tag:tag];
        }
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING, LS_TNUMBER|LS_TINTEGER, LS_TNUMBER|LS_TINTEGER|LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];
        NSString *theHost = [skin toNSObjectAtIndex:3];
        UInt16 thePort = [[skin toNSObjectAtIndex:4] unsignedShortValue];
        long tag = (lua_type(L, 5) == LUA_TNUMBER) ? lua_tointeger(L, 5) : -1;
        if (lua_type(L, 5) == LUA_TFUNCTION) {
            lua_pushvalue(L, 5);
            asyncUdpSocket.writeCallback = [skin luaRef:refTable];
        }
        if (lua_type(L, 5) != LUA_TFUNCTION && lua_type(L, 6) == LUA_TFUNCTION) {
            lua_pushvalue(L, 6);
            asyncUdpSocket.writeCallback = [skin luaRef:refTable];
        }
        
        if (sendData) {
            [asyncUdpSocket sendData:sendData
                              toHost:theHost
                                port:thePort
                         withTimeout:asyncUdpSocket.timeout
                                 tag:tag];
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:broadcast([flag]) -> self or nil
/// Method
/// Enables broadcasting on the underlying socket
///
/// Parameters:
///  * flag - An optional boolean: `true` to enable broadcasting, `false` to disable it. Defaults to `true`
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occurred
///
/// Notes:
///  * By default, the underlying socket in the OS will not allow you to send broadcast messages
///  * In order to send broadcast messages, you need to enable this functionality in the socket
///  * A broadcast is a UDP message to addresses like "192.168.255.255" or "255.255.255.255" that is delivered to every host on the network.
///  * The reason this is generally disabled by default (by the OS) is to prevent accidental broadcast messages from flooding the network.
///
static int socketudp_enableBroadcast(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    BOOL enableFlag = (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 3) == false) ? false : true;
    NSError *err;

    if (![asyncUdpSocket enableBroadcast:enableFlag error:&err]) {
        [LuaSkin logError:[NSString stringWithFormat:@"Unable to enable broadcasting: %@",
                           [err localizedDescription]]];
        lua_pushnil(L);
        return 1;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:reusePort([flag]) -> self or nil
/// Method
/// Enables port reuse on the underlying socket
///
/// Parameters:
///  * flag - An optional boolean: `true` to enable port reuse, `false` to disable it. Defaults to `true`
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occurred
///
/// Notes:
///  * By default, only one socket can be bound to a given IP address+port at a time
///  * To enable multiple processes to simultaneously bind to the same address+port, you need to enable this functionality in the socket
///  * All processes that wish to use the address+port simultaneously must all enable reuse port on the socket bound to that port
///  * Must be called before binding the socket
///
static int socketudp_enableReusePort(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    BOOL enableFlag = (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 3) == false) ? false : true;
    NSError *err;

    if (![asyncUdpSocket enableReusePort:enableFlag error:&err]) {
        [LuaSkin logError:[NSString stringWithFormat:@"Unable to enable port reuse: %@",
                           [err localizedDescription]]];
        lua_pushnil(L);
        return 1;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:enableIPv(version[, flag]) -> self or nil
/// Method
/// Enables or disables IPv4 or IPv6 on the underlying socket. By default, both are enabled
///
/// Parameters:
///  * version - A number containing the IP version (4 or 6) to enable or disable
///  * flag - A boolean: `true` to enable the chosen IP version, `false` to disable it. Defaults to `true`
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object or `nil` if an error occurred
///
/// Notes:
///  * Must be called before binding the socket. If you want to create an IPv6-only server, do something like:
///   * `hs.socket.udp.new(callback):enableIPv(4, false):listen(port):receive()`
///  * The convenience constructor [`hs.socket.server`](#server) will automatically bind the socket and requires closing and relistening to use this method
///
static int socketudp_enableIPversion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    UInt8 ipVersion = lua_tointeger(L, 2);
    BOOL enableFlag = (lua_type(L, 3) == LUA_TBOOLEAN && lua_toboolean(L, 3) == false) ? false : true;

    if (ipVersion == 4) {
        [asyncUdpSocket setIPv4Enabled:enableFlag];
    } else if (ipVersion == 6) {
        [asyncUdpSocket setIPv6Enabled:enableFlag];
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"Invalid IP version: %hhu", ipVersion]];
        lua_pushnil(L);
        return 1;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:preferIPv([version]) -> self
/// Method
/// Sets the preferred IP version: IPv4, IPv6, or neutral (first to resolve)
///
/// Parameters:
///  * version - An optional number containing the IP version to prefer. Anything but 4 or 6 else sets the default neutral behavior
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
/// Notes:
///  * If a DNS lookup returns only IPv4 results, the socket will automatically use IPv4
///  * If a DNS lookup returns only IPv6 results, the socket will automatically use IPv6
///  * If a DNS lookup returns both IPv4 and IPv6 results, then the protocol used depends on the configured preference
///
static int socketudp_preferIPversion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    if (lua_type(L, 2) == LUA_TNUMBER && lua_tointeger(L, 2) == 4) {
        [asyncUdpSocket setPreferIPv4];
    } else if (lua_type(L, 2) == LUA_TNUMBER && lua_tointeger(L, 2) == 6) {
        [asyncUdpSocket setPreferIPv6];
    } else {
        [asyncUdpSocket setIPVersionNeutral];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:setBufferSize(size[, version]) -> self
/// Method
/// Sets the maximum size of the buffer that will be allocated for receive operations
///
/// Parameters:
///  * size - An number containing the receive buffer size in bytes
///  * version - An optional number containing the IP version for which to set the buffer size. Anything but 4 or 6 else sets the same size for both
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
/// Notes:
///  * The default maximum size is 9216 bytes
///  * The theoretical maximum size of any IPv4 UDP packet is UINT16_MAX = 65535
///  * The theoretical maximum size of any IPv6 UDP packet is UINT32_MAX = 4294967295
///  * Since the OS notifies us of the size of each received UDP packet, the actual allocated buffer size for each packet is exact
///  * In practice the size of UDP packets is generally much smaller than the max. Most protocols will send and receive packets of only a few bytes, or will set a limit on the size of packets to prevent fragmentation in the IP layer.
///  * If you set the buffer size too small, the sockets API in the OS will silently discard any extra data
///
static int socketudp_setReceiveBufferSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TINTEGER, LS_TNUMBER|LS_TINTEGER|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    NSUInteger bufferSize = lua_tointeger(L, 2);
    UInt16 IPv4BufferSize = (bufferSize > UINT16_MAX) ? UINT16_MAX : (UInt16)bufferSize;
    UInt32 IPv6BufferSize = (bufferSize > UINT32_MAX) ? UINT32_MAX : (UInt32)bufferSize;

    if (lua_type(L, 3) == LUA_TNUMBER) {
        if (lua_tointeger(L, 3) == 4) {
            [asyncUdpSocket setMaxReceiveIPv4BufferSize:IPv4BufferSize];
        } else if (lua_tointeger(L, 3) == 6) {
            [asyncUdpSocket setMaxReceiveIPv6BufferSize:IPv6BufferSize];
        }
    } else {
        [asyncUdpSocket setMaxReceiveIPv4BufferSize:IPv4BufferSize];
        [asyncUdpSocket setMaxReceiveIPv6BufferSize:IPv6BufferSize];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:setCallback([fn]) -> self
/// Method
/// Sets the read callback for the [`hs.socket.udp`](#new) instance. Must be set to read data from the socket
///
/// Parameters:
///  * fn - An optional callback function to process data read from the socket. `nil` or no argument clears the callback. The callback receives 2 parameters:
///    * data - The data read from the socket as a string
///    * sockaddr - The sending address as a binary socket address structure. See [`parseAddress`](#parseAddress)
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
static int socketudp_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    asyncUdpSocket.readCallback = [skin luaUnref:refTable ref:asyncUdpSocket.readCallback];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        asyncUdpSocket.readCallback = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:setTimeout(timeout) -> self
/// Method
/// Sets the timeout for the socket operations. If the timeout value is negative, the operations will not use a timeout, which is the default
///
/// Parameters:
///  * timeout - A number containing the timeout duration, in seconds
///
/// Returns:
///  * The [`hs.socket.udp`](#new) object
///
static int socketudp_setTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);
    NSTimeInterval timeout = lua_tonumber(L, 2);
    asyncUdpSocket.timeout = timeout;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.socket.udp:connected() -> bool
/// Method
/// Returns the connection status of the [`hs.socket.udp`](#new) instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if connected, otherwise `false`
///
/// Notes:
///  * UDP sockets are typically meant to be connectionless
///  * This method will only return `true` if the [`connect`](#connect) method has been explicitly called
///
static int socketudp_connected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    lua_pushboolean(L, asyncUdpSocket.isConnected);
    return 1;
}

/// hs.socket.udp:closed() -> bool
/// Method
/// Returns the closed status of the [`hs.socket.udp`](#new) instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if closed, otherwise `false`
///
/// Notes:
///  * UDP sockets are typically meant to be connectionless
///  * Sending a packet anywhere, regardless of whether or not the destination receives it, opens the socket until it is explicitly closed
///  * An active listening socket will not be closed, but will not be 'connected' unless the [connect](#connect) method has been called
///
static int socketudp_closed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    lua_pushboolean(L, asyncUdpSocket.isClosed);
    return 1;
}

/// hs.socket.udp:info() -> table
/// Method
/// Returns information on the [`hs.socket.udp`](#new) instance
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys:
///   * connectedAddress - `string` (`sockaddr` struct)
///   * connectedHost - `string`
///   * connectedPort - `number`
///   * isClosed - `boolean`
///   * isConnected - `boolean`
///   * isIPv4 - `boolean`
///   * isIPv4Enabled - `boolean`
///   * isIPv4Preferred - `boolean`
///   * isIPv6 - `boolean`
///   * isIPv6Enabled - `boolean`
///   * isIPv6Preferred - `boolean`
///   * isIPVersionNeutral - `boolean`
///   * localAddress - `string` (`sockaddr` struct)
///   * localAddress_IPv4 - `string` (`sockaddr` struct)
///   * localAddress_IPv6 - `string` (`sockaddr` struct)
///   * localHost - `string`
///   * localHost_IPv4 - `string`
///   * localHost_IPv6 - `string`
///   * localPort - `number`
///   * localPort_IPv4 - `number`
///   * localPort_IPv6 - `number`
///   * maxReceiveIPv4BufferSize - `number`
///   * maxReceiveIPv6BufferSize - `number`
///   * timeout - `number`
///   * userData - `string`
///
static int socketudp_info(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    NSDictionary *info = @{
        @"connectedAddress" : asyncUdpSocket.connectedAddress ?: @"",
        @"connectedHost" : asyncUdpSocket.connectedHost ?: @"",
        @"connectedPort" : @(asyncUdpSocket.connectedPort),
        @"isClosed": @(asyncUdpSocket.isClosed),
        @"isConnected": @(asyncUdpSocket.isConnected),
        @"isIPv4": @(asyncUdpSocket.isIPv4),
        @"isIPv4Enabled": @(asyncUdpSocket.isIPv4Enabled),
        @"isIPv4Preferred": @(asyncUdpSocket.isIPv4Preferred),
        @"isIPv6": @(asyncUdpSocket.isIPv6),
        @"isIPv6Enabled": @(asyncUdpSocket.isIPv6Enabled),
        @"isIPv6Preferred": @(asyncUdpSocket.isIPv6Preferred),
        @"isIPVersionNeutral": @(asyncUdpSocket.isIPVersionNeutral),
        @"localAddress": asyncUdpSocket.localAddress ?: @"",
        @"localAddress_IPv4": asyncUdpSocket.localAddress_IPv4 ?: @"",
        @"localAddress_IPv6": asyncUdpSocket.localAddress_IPv6 ?: @"",
        @"localHost": asyncUdpSocket.localHost ?: @"",
        @"localHost_IPv4": asyncUdpSocket.localHost_IPv4 ?: @"",
        @"localHost_IPv6": asyncUdpSocket.localHost_IPv6 ?: @"",
        @"localPort" : @(asyncUdpSocket.localPort),
        @"localPort_IPv4" : @(asyncUdpSocket.localPort_IPv4),
        @"localPort_IPv6" : @(asyncUdpSocket.localPort_IPv6),
        @"maxReceiveIPv4BufferSize" : @(asyncUdpSocket.maxReceiveIPv4BufferSize),
        @"maxReceiveIPv6BufferSize" : @(asyncUdpSocket.maxReceiveIPv6BufferSize),
        @"timeout": @(asyncUdpSocket.timeout),
        @"userData" : asyncUdpSocket.userData ?: @"",
    };

    [skin pushNSObject:info];
    return 1;
}


// Library registration functions
static int userdata_tostring(lua_State* L) {
    HSAsyncUdpSocket* asyncUdpSocket = getUserData(L, 1);

    BOOL isServer = (asyncUdpSocket.userData == SERVER) ? true : false;
    NSString *theHost = isServer ? asyncUdpSocket.localHost : asyncUdpSocket.connectedHost;
    UInt16 thePort = isServer ? asyncUdpSocket.localPort : asyncUdpSocket.connectedPort;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@:%hu (%p)", USERDATA_TAG, theHost, thePort, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

static int userdata_gc(lua_State *L) {
    asyncSocketUserData *userData = lua_touserdata(L, 1);
    HSAsyncUdpSocket* asyncUdpSocket = (__bridge_transfer HSAsyncUdpSocket *)userData->asyncSocket;
    userData->asyncSocket = nil;

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [asyncUdpSocket close];
    [asyncUdpSocket setDelegate:nil delegateQueue:NULL];
    asyncUdpSocket.readCallback = [skin luaUnref:refTable ref:asyncUdpSocket.readCallback];
    asyncUdpSocket.writeCallback = [skin luaUnref:refTable ref:asyncUdpSocket.writeCallback];
    asyncUdpSocket.connectCallback = [skin luaUnref:refTable ref:asyncUdpSocket.connectCallback];
    asyncUdpSocket = nil;

    return 0;
}

// Functions for returned object when module loads
static const luaL_Reg moduleLib[] = {
    {"new",             socketudp_new},
    {NULL,              NULL} // This must end with an empty struct
};

// Metatable for created objects when _new invoked
static const luaL_Reg userdata_metaLib[] = {
    {"connect",         socketudp_connect},
    {"listen",          socketudp_listen},
    {"close",           socketudp_close},
    {"pause",           socketudp_pause},
    {"receive",         socketudp_receive},
    {"receiveOne",      socketudp_receiveOne},
    {"send",            socketudp_send},
    {"broadcast",       socketudp_enableBroadcast},
    {"reusePort",       socketudp_enableReusePort},
    {"enableIPv",       socketudp_enableIPversion},
    {"preferIPv",       socketudp_preferIPversion},
    {"setBufferSize",   socketudp_setReceiveBufferSize},
    {"setCallback",     socketudp_setCallback},
    {"setTimeout",      socketudp_setTimeout},
    {"connected",       socketudp_connected},
    {"closed",          socketudp_closed},
    {"info",            socketudp_info},
    {"__tostring",      userdata_tostring},
    {"__gc",            userdata_gc},
    {NULL,              NULL} // This must end with an empty struct
};

int luaopen_hs_libsocketudp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:meta_gcLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];

    return 1;
}
