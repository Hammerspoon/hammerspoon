
/// === hs.network.ping.echoRequest ===
///
/// Provides lower-level access to the ICMP Echo Request infrastructure used by the hs.network.ping module. In general, you should not need to use this module directly unless you have specific requirements not met by the hs.network.ping module and the `hs.network.ping` object methods.
///
/// This module is based heavily on Apple's SimplePing sample project which can be found at https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html.
///
/// When a callback function argument is specified as an ICMP table, the Lua table returned will contain the following key-value pairs:
///  * `checksum`       - The ICMP packet checksum used to ensure data integrity.
///  * `code`           - ICMP Control Message Code. This should always be 0 unless the callback has received a "receivedUnexpectedPacket" message.
///  * `identifier`     - The ICMP packet identifier.  This should match the results of [hs.network.ping.echoRequest:identifier](#identifier) unless the callback has received a "receivedUnexpectedPacket" message.
///  * `payload`        - A string containing the ICMP payload for this packet. The default payload has been constructed to cause the ICMP packet to be exactly 64 bytes to match the convention for ICMP Echo Requests.
///  * `sequenceNumber` - The ICMP Sequence Number for this packet.
///  * `type`           - ICMP Control Message Type. Unless the callback has received a "receivedUnexpectedPacket" message, this will be 0 (ICMPv4) or 129 (ICMPv6) for packets we receive and 8 (ICMPv4) or 128 (ICMPv6) for packets we send.
///  * `_raw`           - A string containing the ICMP packet as raw data.
///
/// In cases where the callback receives a "receivedUnexpectedPacket" message because the packet is corrupted or truncated, this table may only contain the `_raw` field.

@import Cocoa ;
@import LuaSkin ;

@import Darwin.POSIX.netdb ;

#include "SimplePing.h"

#define USERDATA_TAG "hs.network.ping.echoRequest"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#define ADDRESS_STYLES @{ \
    @"any"  : @(SimplePingAddressStyleAny), \
    @"IPv4" : @(SimplePingAddressStyleICMPv4), \
    @"IPv6" : @(SimplePingAddressStyleICMPv6), \
}

#pragma mark - Support Functions and Classes

static int pushParsedAddress(lua_State *L, NSData *addressData) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    int  err;
    char addrStr[NI_MAXHOST];
    err = getnameinfo([addressData bytes], (unsigned int)[addressData length], addrStr, sizeof(addrStr), NULL, 0, NI_NUMERICHOST | NI_WITHSCOPEID | NI_NUMERICSERV);
    if (err == 0) {
        [skin pushNSObject:[NSString stringWithFormat:@"%s", addrStr]] ;
    } else {
        [skin pushNSObject:[NSString stringWithFormat:@"** address parse error:%s **", gai_strerror(err)]] ;
    }
    return 1;
}

static int pushParsedICMPPayload(lua_State *L, NSData *payloadData) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    size_t packetLength = [payloadData length] ;

    lua_newtable(L) ;
    size_t headerSize = sizeof(ICMPHeader) ;
    if (packetLength >= headerSize) {
        ICMPHeader payloadHeader ;
        [payloadData getBytes:&payloadHeader length:headerSize] ;
        lua_pushinteger(L, payloadHeader.type) ;           lua_setfield(L, -2, "type") ;
        lua_pushinteger(L, payloadHeader.code) ;           lua_setfield(L, -2, "code") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.checksum)) ;
        lua_setfield(L, -2, "checksum") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.identifier)) ;
        lua_setfield(L, -2, "identifier") ;
        lua_pushinteger(L, OSSwapHostToBigInt16(payloadHeader.sequenceNumber)) ;
        lua_setfield(L, -2, "sequenceNumber") ;
        if (packetLength > headerSize) {
            [skin pushNSObject:[payloadData subdataWithRange:NSMakeRange(headerSize, packetLength - headerSize)]] ;
            lua_setfield(L, -2, "payload") ;
        }
    } else {
        [skin logDebug:[NSString stringWithFormat:@"malformed ICMP data:%@", payloadData]] ;
        lua_pushstring(L, "ICMP header is too short -- malformed ICMP packet") ;
        lua_setfield(L, -2, "error") ;
    }
    [skin pushNSObject:payloadData] ;
    lua_setfield(L, -2, "_raw") ;

    return 1 ;
}

@interface SimplePing ()
@property (nonatomic, strong, readwrite, nullable) CFSocketRef socket __attribute__ ((NSObject));
@end

@interface PingableObject : SimplePing <SimplePingDelegate>
@property int  callbackRef ;
@property int  selfRef ;
@property BOOL passAllUnexpected ;
@end

@implementation PingableObject

- (instancetype)initWithHostName:(NSString *)hostName {
    if (!hostName) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:initWithHostName, hostname cannot be nil", USERDATA_TAG]] ;
        return nil ;
    }

    self = [super initWithHostName:hostName] ;
    if (self) {
        _callbackRef       = LUA_NOREF ;
        _selfRef           = LUA_NOREF ;
        _passAllUnexpected = NO ;
        self.delegate      = self ;
    }
    return self ;
}

#pragma mark * SimplePingDelegate Methods

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {

    // Clear the close-on-invalidate flag... otherwise a future stop on the object would
    // cause all ping objects to stop stop at the same time.
    CFOptionFlags sockopt = CFSocketGetSocketFlags(self.socket);
    sockopt &= ~kCFSocketCloseOnInvalidate;
    CFSocketSetSocketFlags(self.socket, sockopt);

    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"didStart"] ;
        pushParsedAddress(skin.L, address) ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didStartWithAddress callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    _lua_stackguard_entry(skin.L);
    NSString *errorReason = [error localizedDescription] ;
    [skin logDebug:[NSString stringWithFormat:@"%s:didFailWithError:%@ - ping stopped.", USERDATA_TAG, errorReason]] ;
    if (_callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"didFail"] ;
        [skin pushNSObject:errorReason] ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didFailWithError callback" nargs:3 nresults:0];
    }

    // by the time this method is invoked, SimplePing has already stopped us, so let's make sure
    // we reflect that.
    _selfRef = [skin luaUnref:refTable ref:_selfRef] ;
    _lua_stackguard_exit(skin.L);
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet
                                       sequenceNumber:(uint16_t)sequenceNumber {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"sendPacket"] ;
        pushParsedICMPPayload(skin.L, packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didSendPacket callback" nargs:4 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet
                                             sequenceNumber:(uint16_t)sequenceNumber
                                                      error:(NSError *)error {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"sendPacketFailed"] ;
        pushParsedICMPPayload(skin.L, packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        [skin pushNSObject:[error localizedDescription]] ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didFailToSendPacket callback" nargs:5 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet
                                                      sequenceNumber:(uint16_t)sequenceNumber {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"receivedPacket"] ;
        pushParsedICMPPayload(skin.L, packet) ;
        lua_pushinteger([skin L], sequenceNumber) ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didReceivePingResponsePacket" nargs:4 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    BOOL notifyCallback = YES ;
    if (!_passAllUnexpected) {
        size_t packetLength = [packet length] ;
        size_t headerSize   = sizeof(ICMPHeader) ;
        if (packetLength >= headerSize) {
            ICMPHeader payloadHeader ;
            [packet getBytes:&payloadHeader length:headerSize] ;
            if (OSSwapHostToBigInt16(payloadHeader.identifier) != self.identifier) notifyCallback = NO ;
        }
    }
    if (notifyCallback && _callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:pinger] ;
        [skin pushNSObject:@"receivedUnexpectedPacket"] ;
        pushParsedICMPPayload(skin.L, packet) ;
        [skin protectedCallAndError:@"hs.network.ping.echoRequest:didReceiveUnexpectedPacket callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

@end

#pragma mark - Module Functions

/// hs.network.ping.echoRequest.echoRequest(server) -> echoRequestObject
/// Constructor
/// Creates a new ICMP Echo Request object for the server specified.
///
/// Parameters:
///  * `server` - a string containing the hostname or ip address of the server to communicate with. Both IPv4 and IPv6 style addresses are supported.
///
/// Returns:
///  * an echoRequest object
///
/// Notes:
///  * This constructor returns a lower-level object than the `hs.network.ping.ping` constructor and is more difficult to use. It is recommended that you use this constructor only if `hs.network.ping.ping` is not sufficient for your needs.
///
///  * For convenience, you can call this constructor as `hs.network.ping.echoRequest(server)`
static int echoRequest_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    PingableObject *pinger = [[PingableObject alloc] initWithHostName:[skin toNSObjectAtIndex:1]] ;
    [skin pushNSObject:pinger] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.network.ping.echoRequest:setCallback(fn) -> echoRequestObject
/// Method
/// Set or remove the object callback function
///
/// Parameters:
///  * `fn` - a function to set as the callback function for this object, or nil if you wish to remove any existing callback function.
///
/// Returns:
///  * the echoRequestObject
///
/// Notes:
///  * The callback function should expect between 3 and 5 arguments and return none. The possible arguments which are sent will be one of the following:
///
///    * "didStart" - indicates that the object has resolved the address of the server and is ready to begin sending and receiving ICMP Echo packets.
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "didStart"
///      * `address` - a string representation of the IPv4 or IPv6 address of the server specified to the constructor.
///
///    * "didFail" - indicates that the object has failed, either because the address could not be resolved or a network error has occurred.
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "didFail"
///      * `error`   - a string describing the error that occurred.
///    * Notes:
///      * When this message is received, you do not need to call [hs.network.ping.echoRequest:stop](#stop) -- the object will already have been stopped.
///
///    * "sendPacket" - indicates that the object has sent an ICMP Echo Request packet.
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "sendPacket"
///      * `icmp`    - an ICMP packet table representing the packet which has been sent as described in the header of this module's documentation.
///      * `seq`     - the sequence number for this packet. Sequence numbers always start at 0 and increase by 1 every time the [hs.network.ping.echoRequest:sendPayload](#sendPayload) method is called.
///
///    * "sendPacketFailed" - indicates that the object failed to send the ICMP Echo Request packet.
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "sendPacketFailed"
///      * `icmp`    - an ICMP packet table representing the packet which was to be sent.
///      * `seq`     - the sequence number for this packet.
///      * `error`   - a string describing the error that occurred.
///    * Notes:
///      * Unlike "didFail", the echoRequestObject is not stopped when this message occurs; you can try to send another payload if you wish without restarting the object first.
///
///    * "receivedPacket" - indicates that an expected ICMP Echo Reply packet has been received by the object.
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "receivedPacket"
///      * `icmp`    - an ICMP packet table representing the packet received.
///      * `seq`     - the sequence number for this packet.
///
///    * "receivedUnexpectedPacket" - indicates that an unexpected ICMP packet was received
///      * `object`  - the echoRequestObject itself
///      * `message` - the message to the callback, in this case "receivedUnexpectedPacket"
///      * `icmp`    - an ICMP packet table representing the packet received.
///    * Notes:
///      * This message can occur for a variety of reasons, the most common being:
///        * the ICMP packet is corrupt or truncated and cannot be parsed
///        * the ICMP Identifier does not match ours and the sequence number is not one we have sent
///        * the ICMP type does not match an ICMP Echo Reply
///        * When using IPv6, this is especially common because IPv6 uses ICMP for network management functions like Router Advertisement and Neighbor Discovery.
///      * In general, it is reasonably safe to ignore these messages, unless you are having problems receiving anything else, in which case it could indicate problems on your network that need addressing.
static int echoRequest_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    // We're either removing a callback, or setting a new one. Either way, remove existing.
    pinger.callbackRef = [skin luaUnref:refTable ref:pinger.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        pinger.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.network.ping.echoRequest:hostName() -> string
/// Method
/// Returns the name of the target host as provided to the echoRequestObject's constructor
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the hostname as specified when the object was created.
static int echoRequest_hostName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:pinger.hostName] ;
    return 1 ;
}

/// hs.network.ping.echoRequest:identifier() -> integer
/// Method
/// Returns the identifier number for the echoRequestObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the identifier which is embedded in the ICMP packets this object sends.
///
/// Notes:
///  * ICMP Echo Replies which include this identifier will generate a "receivedPacket" message to the object callback, while replies which include a different identifier will generate a "receivedUnexpectedPacket" message.
static int echoRequest_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, pinger.identifier) ;
    return 1 ;
}

/// hs.network.ping.echoRequest:nextSequenceNumber() -> integer
/// Method
/// The sequence number that will be used for the next ICMP packet sent by this object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the sequence number that will be embedded in the next ICMP message sent by this object when [hs.network.ping.echoRequest:sendPayload](#sendPayload) is invoked.
///
/// Notes:
///  * ICMP Echo Replies which are expected by this object should always be less than this number, with the caveat that this number is a 16-bit integer which will wrap around to 0 after sending a packet with the sequence number 65535.
///  * Because of this wrap around effect, this module will generate a "receivedPacket" message to the object callback whenever the received packet has a sequence number that is within the last 120 sequence numbers we've sent and a "receivedUnexpectedPacket" otherwise.
///    * Per the comments in Apple's SimplePing.m file: Why 120?  Well, if we send one ping per second, 120 is 2 minutes, which is the standard "max time a packet can bounce around the Internet" value.
static int echoRequest_nextSequenceNumber(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, pinger.nextSequenceNumber) ;
    return 1 ;
}

/// hs.network.ping.echoRequest:acceptAddressFamily([family]) -> echoRequestObject | current value
/// Method
/// Get or set the address family the echoRequestObject should communicate with.
///
/// Parameters:
///  * `family` - an optional string, default "any", which specifies the address family used by this object.  Valid values are "any", "IPv4", and "IPv6".
///
/// Returns:
///  * if an argument is provided, returns the echoRequestObject, otherwise returns the current value.
///
/// Notes:
///  * Setting this value to "IPv6" or "IPv4" will cause the echoRequestObject to attempt to resolve the server's name into an IPv6 address or an IPv4 address and communicate via ICMPv6 or ICMP(v4) when the [hs.network.ping.echoRequest:start](#start) method is invoked.  A callback with the message "didFail" will occur if the server could not be resolved to an address in the specified family.
///  * If this value is set to "any", then the first address which is discovered for the server's name will determine whether ICMPv6 or ICMP(v4) is used, based upon the family of the address.
///
///  * Setting a value with this method will have no immediate effect on an echoRequestObject which has already been started with [hs.network.ping.echoRequest:start](#start). You must first stop and then restart the object for any change to have an effect.
static int echoRequest_addressStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *addressStyle = @(pinger.addressStyle) ;
        NSArray *temp = [ADDRESS_STYLES allKeysForObject:addressStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:unrecognized address style %@ -- notify developers", USERDATA_TAG, addressStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *addressStyle = ADDRESS_STYLES[key] ;
        if (addressStyle) {
            pinger.addressStyle = [addressStyle integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[ADDRESS_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs.network.ping.echoRequest:start() -> echoRequestObject
/// Method
/// Start the echoRequestObject by resolving the server's address and start listening for ICMP Echo Reply packets.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the echoRequestObject
static int echoRequest_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (pinger.selfRef == LUA_NOREF) {
        [pinger start] ;

        // assign a self ref to keep __gc from stopping us inadvertantly
        lua_pushvalue(L, 1) ;
        pinger.selfRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.network.ping.echoRequest:stop() -> echoRequestObject
/// Method
/// Stop listening for ICMP Echo Reply packets with this object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the echoRequestObject
static int echoRequest_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (pinger.selfRef != LUA_NOREF) {
        [pinger stop] ;

        // we no longer need a self ref to keep __gc from stopping us inadvertantly
        pinger.selfRef = [skin luaUnref:refTable ref:pinger.selfRef] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.network.ping.echoRequest:isRunning() -> boolean
/// Method
/// Returns a boolean indicating whether or not this echoRequestObject is currently listening for ICMP Echo Replies.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the object is currently listening for ICMP Echo Replies, or false if it is not.
static int echoRequest_isRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    // we only have a self ref when we've been started
    lua_pushboolean(L, (pinger.selfRef != LUA_NOREF)) ;
    return 1 ;
}

/// hs.network.ping.echoRequest:hostAddress() -> string | false | nil
/// Method
/// Returns a string representation for the server's IP address, or a boolean if address resolution has not completed yet.
///
/// Parameters:
///  * None
///
/// Returns:
///  * If the object has been started and address resolution has completed, then the string representation of the server's IP address is returned.
///  * If the object has been started, but resolution is still pending, returns a boolean value of false.
///  * If the object has not been started, returns nil.
static int echoRequest_hostAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    if (pinger.hostAddress) {
        pushParsedAddress(L, pinger.hostAddress) ;
    } else {
        if (pinger.selfRef != LUA_NOREF) {
            lua_pushboolean(L, NO) ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs.network.ping.echoRequest:sendPayload([payload]) -> echoRequestObject | false | nil
/// Method
/// Sends a single ICMP Echo Request packet.
///
/// Parameters:
///  * `payload` - an optional string containing the data to include in the ICMP Echo Request as the packet payload.
///
/// Returns:
///  * If the object has been started and address resolution has completed, then the ICMP Echo Packet is sent and this method returns the echoRequestObject
///  * If the object has been started, but resolution is still pending, the packet is not sent and this method returns a boolean value of false.
///  * If the object has not been started, the packet is not sent and this method returns nil.
///
/// Notes:
///  * By convention, unless you are trying to test for specific network fragmentation or congestion problems, ICMP Echo Requests are generally 64 bytes in length (this includes the 8 byte header, giving 56 bytes of payload data).  If you do not specify a payload, a default payload which will result in a packet size of 64 bytes is constructed.
static int echoRequest_sendPayload(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;
    NSData *payload = (lua_gettop(L) == 2) ?
        [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] : nil ;

    if (!payload) {
        payload = [[NSString stringWithFormat:@"Hammerspoon %s %*s0x%04x:%04x", USERDATA_TAG, (int)(56 - 24 - strlen(USERDATA_TAG)), " ", pinger.identifier, pinger.nextSequenceNumber] dataUsingEncoding:NSASCIIStringEncoding] ;
    }

    if (pinger.hostAddress) {
        [pinger sendPingWithData:payload] ;
        lua_pushvalue(L, 1) ;
    } else {
        if (pinger.selfRef != LUA_NOREF) {
            lua_pushboolean(L, NO) ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs.network.ping.echoRequest:hostAddressFamily() -> string
/// Method
/// Returns the host address family currently in use by this echoRequestObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string indicating the IP address family currently used by this echoRequestObject.  It will be one of the following values:
///    * "IPv4"       - indicates that ICMP(v4) packets are being sent and listened for.
///    * "IPv6"       - indicates that ICMPv6 packets are being sent and listened for.
///    * "unresolved" - indicates that the echoRequestObject has not been started or that address resolution is still in progress.
static int echoRequest_addressFamily(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    switch (pinger.hostAddressFamily) {
        case AF_INET:
            [skin pushNSObject:@"IPv4"] ;
            break ;
        case AF_INET6:
            [skin pushNSObject:@"IPv6"] ;
            break ;
        case AF_UNSPEC:
            [skin pushNSObject:@"unresolved"] ;
            break ;
        default:
            [skin logError:[NSString stringWithFormat:@"%s:unrecognized address family %d -- notify developers", USERDATA_TAG, pinger.hostAddressFamily]] ;
            lua_pushnil(L) ;
            break ;
    }
    return 1 ;
}

/// hs.network.ping.echoRequest:seeAllUnexpectedPackets([state]) -> boolean | echoRequestObject
/// Method
/// Get or set whether or not the callback should receive all unexpected packets or only those which carry our identifier.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not all unexpected packets or only those which carry our identifier should generate a "receivedUnexpectedPacket" callback message.
///
/// Returns:
///  * if an argument is provided, returns the echoRequestObject; otherwise returns the current value
///
/// Notes:
///  * The nature of ICMP packet reception is such that all listeners receive all ICMP packets, even those which belong to another process or echoRequestObject.
///    * By default, a valid packet (i.e. with a valid checksum) which does not contain our identifier is ignored since it was not intended for our receiver.  Only corrupt or packets with our identifier but that were otherwise unexpected will generate a "receivedUnexpectedPacket" callback message.
///    * This method optionally allows the echoRequestObject to receive *all* incoming packets, even ones which are expected by another process or echoRequestObject.
///  * If you wish to examine ICMPv6 router advertisement and neighbor discovery packets, you should set this property to true. Note that this module does not provide the necessary tools to decode these packets at present, so you will have to decode them yourself if you wish to examine their contents.
static int echoRequest_seeAllUnexpectedPackets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    PingableObject *pinger = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, pinger.passAllUnexpected) ;
    } else {
        pinger.passAllUnexpected = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushPingableObject(lua_State *L, id obj) {
    PingableObject *value = obj;

    // honor selfRef if it's been assigned
    if (value.selfRef != LUA_NOREF) {
        [[LuaSkin sharedWithState:L] pushLuaRef:refTable ref:value.selfRef] ;

    // otherwise, treat this like any other NSObject -> lua userdata
    } else {
        void** valuePtr = lua_newuserdata(L, sizeof(PingableObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    }
    return 1;
}

static id toPingableObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    PingableObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge PingableObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    PingableObject *obj = [skin luaObjectAtIndex:1 toClass:"PingableObject"] ;
    NSString *title = obj.hostName ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        PingableObject *obj1 = [skin luaObjectAtIndex:1 toClass:"PingableObject"] ;
        PingableObject *obj2 = [skin luaObjectAtIndex:2 toClass:"PingableObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    PingableObject *obj = get_objectFromUserdata(__bridge_transfer PingableObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

        // because the self ref means we have a reference in the registry, the only way we should ever
        // actually have to do this is during a reload/quit... and even then, it's not guaranteed
        // depending upon purge ordering and possible object resurrection, but lets be "correct" if we can
        if (obj.selfRef != LUA_NOREF) {
            [obj stop] ;
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        }
        obj = nil ;
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
    {"hostName",                echoRequest_hostName},
    {"identifier",              echoRequest_identifier},
    {"nextSequenceNumber",      echoRequest_nextSequenceNumber},
    {"setCallback",             echoRequest_setCallback},
    {"acceptAddressFamily",     echoRequest_addressStyle},
    {"start",                   echoRequest_start},
    {"stop",                    echoRequest_stop},
    {"isRunning",               echoRequest_isRunning},
    {"hostAddress",             echoRequest_hostAddress},
    {"hostAddressFamily",       echoRequest_addressFamily},
    {"sendPayload",             echoRequest_sendPayload},
    {"seeAllUnexpectedPackets", echoRequest_seeAllUnexpectedPackets},

    {"__tostring",              userdata_tostring},
    {"__eq",                    userdata_eq},
    {"__gc",                    userdata_gc},
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"echoRequest", echoRequest_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_network_ping_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushPingableObject         forClass:"PingableObject"];
    [skin registerLuaObjectHelper:toPingableObjectFromLua forClass:"PingableObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
