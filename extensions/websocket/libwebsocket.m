@import Foundation;
@import Cocoa;
@import Carbon;
@import LuaSkin;
@import WebKit;
#import <SocketRocket/SRWebSocket.h>

// Websocket userdata struct
typedef struct _webSocketUserData {
    int selfRef;
    void *ws;
} webSocketUserData;

#define getWsUserData(L, idx) (__bridge HSWebSocketDelegate *)((webSocketUserData *)lua_touserdata(L, idx))->ws;
static const char *WS_USERDATA_TAG = "hs.websocket";

static LSRefTable refTable;

@interface HSWebSocketDelegate: NSObject<SRWebSocketDelegate>
@property int fn;
@property (strong) SRWebSocket *webSocket;
@end

@implementation HSWebSocketDelegate

- (instancetype)initWithURL:(NSURL *)URL {
    if((self = [super init])) {
        _webSocket = [[SRWebSocket alloc] initWithURL:URL];
        _webSocket.delegate = self;
    }
    return self;
}
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fn == LUA_NOREF) {
            return;
        }
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:self.fn];
        [skin pushNSObject:@"received"];
        [skin pushNSObject:message];

        [skin protectedCallAndError:@"hs.websocket callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    });
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fn == LUA_NOREF) {
            return;
        }
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:self.fn];
        [skin pushNSObject:@"open"];

        [skin protectedCallAndError:@"hs.websocket callback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fn == LUA_NOREF) {
            return;
        }
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:self.fn];
        [skin pushNSObject:@"fail"];
        [skin pushNSObject:error];

        [skin protectedCallAndError:@"hs.websocket callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fn == LUA_NOREF) {
            return;
        }
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:self.fn];
        [skin pushNSObject:@"closed"];

        [skin protectedCallAndError:@"hs.websocket callback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fn == LUA_NOREF) {
            return;
        }
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:self.fn];
        [skin pushNSObject:@"pong"];

        [skin protectedCallAndError:@"hs.websocket callback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    });
}
@end

/// hs.websocket.new(url, callback) -> object
/// Function
/// Creates a new websocket connection.
///
/// Parameters:
///  * url - The URL to the websocket
///  * callback - A function that's triggered by websocket actions.
///
/// Returns:
///  * The `hs.websocket` object
///
/// Notes:
///  * The callback should accept two parameters.
///  * The first paramater is a string with the following possible options:
///   * open - The websocket connection has been opened
///   * closed - The websocket connection has been closed
///   * fail - The websocket connection has failed
///   * received - The websocket has received a message
///   * pong - A pong request has been received
///  * The second parameter is a string with the recieved message or an error message.
///  * Given a path '/mysock' and a port of 8000, the websocket URL is as follows:
///   * ws://localhost:8000/mysock
///   * wss://localhost:8000/mysock (if SSL enabled)
static int websocket_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK];

    NSString *url = [skin toNSObjectAtIndex:1];
    HSWebSocketDelegate* ws = [[HSWebSocketDelegate alloc] initWithURL:[NSURL URLWithString:url]];

    lua_pushvalue(L, 2);
    ws.fn = [skin luaRef:refTable];

    [ws.webSocket open];

    webSocketUserData *userData = lua_newuserdata(L, sizeof(webSocketUserData));
    memset(userData, 0, sizeof(webSocketUserData));
    userData->ws = (__bridge_retained void*)ws;
    luaL_getmetatable(L, WS_USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.websocket:send(message[, isData]) -> object
/// Method
/// Sends a message to the websocket client.
///
/// Parameters:
///  * message - A string containing the message to send.
///  * isData - An optional boolean that sends the message as binary data (defaults to true).
///
/// Returns:
///  * The `hs.websocket` object
///
/// Notes:
///  * Forcing a text representation by setting isData to `false` may alter the data if it
///   contains invalid UTF8 character sequences (the default string behavior is to make
///   sure everything is "printable" by converting invalid sequences into the Unicode
///   Invalid Character sequence).
static int websocket_send(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, WS_USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    HSWebSocketDelegate* ws = getWsUserData(L, 1);

    BOOL isData = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : YES ;

    NSUInteger options = isData ? LS_NSLuaStringAsDataOnly : LS_NSPreserveLuaStringExactly;    
    [ws.webSocket send:[skin toNSObjectAtIndex:2 withOptions:options]];
    
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.websocket:status() -> string
/// Method
/// Gets the status of a websocket.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing one of the following options:
///   * connecting
///   * open
///   * closing
///   * closed
///   * unknown
static int websocket_status(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, WS_USERDATA_TAG, LS_TBREAK];
    HSWebSocketDelegate* ws = getWsUserData(L, 1);
    if (ws.webSocket.readyState==0) {
        [skin pushNSObject:@"connecting"];
    }
    else if (ws.webSocket.readyState==1) {
        [skin pushNSObject:@"open"];
    }
    else if (ws.webSocket.readyState==2) {
        [skin pushNSObject:@"closing"];
    }
    else if (ws.webSocket.readyState==3) {
        [skin pushNSObject:@"closed"];
    }
    else {
        [skin pushNSObject:@"unknown"];
    }
    return 1;
}

/// hs.websocket:close() -> object
/// Method
/// Closes a websocket connection.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.websocket` object
static int websocket_close(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, WS_USERDATA_TAG, LS_TBREAK];
    HSWebSocketDelegate* ws = getWsUserData(L, 1);

    [ws.webSocket close];

    lua_pushvalue(L, 1);
    return 1;
}

static int websocket_gc(lua_State* L){
    webSocketUserData *userData = lua_touserdata(L, 1);
    HSWebSocketDelegate* ws = (__bridge_transfer HSWebSocketDelegate *)userData->ws;
    userData->ws = nil;

    [ws.webSocket close];
    ws.webSocket.delegate = nil;
    ws.webSocket = nil;
    ws.fn = [[LuaSkin sharedWithState:L] luaUnref:refTable ref:ws.fn];
    ws = nil;

    return 0;
}

static int websocket_tostring(lua_State* L) {
    HSWebSocketDelegate* ws = getWsUserData(L, 1);
    NSString *host = @"disconnected";

    if (ws.webSocket.readyState==1) {
        host = @"connected";
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", WS_USERDATA_TAG, host, lua_topointer(L, 1)] UTF8String]);
    return 1;
}

static const luaL_Reg websocketlib[] = {
    {"new",         websocket_new},

    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg metalib[] = {
    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg wsMetalib[] = {
    {"send",        websocket_send},
    {"close",       websocket_close},
    {"status",      websocket_status},
    {"__tostring",  websocket_tostring},
    {"__gc",        websocket_gc},

    {NULL, NULL} // This must end with an empty struct
};

int luaopen_hs_libwebsocket(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    refTable = [skin registerLibrary:WS_USERDATA_TAG functions:websocketlib metaFunctions:metalib];
    [skin registerObject:WS_USERDATA_TAG objectFunctions:wsMetalib];

    return 1;
}
