#import <LuaSkin/LuaSkin.h>
#import "CocoaHTTPServer/HTTPServer.h"
#import "CocoaHTTPServer/HTTPMessage.h"
#import "CocoaHTTPServer/HTTPConnection.h"
#import "CocoaHTTPServer/HTTPDataResponse.h"
#import "CocoaHTTPServer/WebSocket.h"
#import "CocoaAsyncSocket/GCDAsyncSocket.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wexpansion-to-defined"
#import "CocoaLumberjack/CocoaLumberjack.h"
#pragma clang diagnostic pop
#import "MYAnonymousIdentity.h"

// From HTTPConnection.m
#define TIMEOUT_WRITE_ERROR 30
#define HTTP_FINAL_RESPONSE 91

// Defines

#define USERDATA_TAG "hs.httpserver"
#define get_item_arg(L, idx) ((httpserver_t *)luaL_checkudata(L, idx, USERDATA_TAG))
#define getUserData(L, idx) (__bridge HSHTTPServer *)((httpserver_t *)get_item_arg(L, idx))->server

static LSRefTable refTable;

// ObjC Class definitions
@interface HSWebSocket : WebSocket
@property int callback;
@end

@interface HSHTTPServer : HTTPServer
@property int fn;
@property NSUInteger maxBodySize;
@property SecIdentityRef sslIdentity;
@property (nonatomic, copy) NSString *httpPassword;
@property int wsCallback;
@property (nonatomic) NSString *wsPath;
@property HSWebSocket *ws;
@end

@interface HSHTTPDataResponse : HTTPDataResponse
@property int hsStatus;
@property (nonatomic, copy) NSDictionary *hsHeaders;
@end

@interface HSHTTPConnection : HTTPConnection
@end

@interface HSHTTPSConnection : HSHTTPConnection
@end

// ObjC Class implementations

@implementation HSHTTPServer
- (id)init {
    self = [super init];
    if (self) {
        self.httpPassword = nil;
        self.maxBodySize  = 10 * 1024 * 1024; // set initial max body size to 10 MB
        self.wsCallback   = LUA_NOREF ;
        self.fn           = LUA_NOREF ;
    }
    return self;
}
@end

@implementation HSWebSocket

- (void)didOpen
{
    [super didOpen];
    [LuaSkin logInfo:@"Opened websocket connection"];
}

- (void)didReceiveData:(NSData *)msg
{
    __block NSData *response = nil;

    void (^responseCallbackBlock)(void) = ^{
        if (self.callback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self.callback];
            [skin pushNSObject:msg];
            
            if (![skin protectedCallAndTraceback:1 nresults:1]) {
                const char *errorMsg = lua_tostring(skin.L, -1);
                [skin logError:[NSString stringWithFormat:@"hs.httpserver:websocket callback error: %s", errorMsg]];
                // No need to lua_pop() here, nresults is 1 so the lua_pop() below catches successful results and error messages
            } else {
                response = [skin toNSObjectAtIndex:-1];
            }

            lua_pop(skin.L, 1);
            _lua_stackguard_exit(skin.L);
        }
    };

    // Make sure we do all the above Lua work on the main thread
    if ([NSThread isMainThread]) {
        responseCallbackBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), responseCallbackBlock);
    }

    [self sendMessage:[NSString stringWithFormat:@"%@", response]];
}

- (void)didReceiveMessage:(NSString *)msg
{
    __block NSData *response = nil;

    void (^responseCallbackBlock)(void) = ^{
        if (self.callback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self.callback];
            lua_pushstring(skin.L, [msg UTF8String]);

            if (![skin protectedCallAndTraceback:1 nresults:1]) {
                const char *errorMsg = lua_tostring(skin.L, -1);
                [skin logError:[NSString stringWithFormat:@"hs.httpserver:websocket callback error: %s", errorMsg]];
                // No need to lua_pop() here, nresults is 1 so the lua_pop() below catches successful results and error messages
            } else {
                response = [skin toNSObjectAtIndex:-1];
            }

            lua_pop(skin.L, 1);
            _lua_stackguard_exit(skin.L);
        }
    };

    // Make sure we do all the above Lua work on the main thread
    if ([NSThread isMainThread]) {
        responseCallbackBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), responseCallbackBlock);
    }

    [self sendMessage:[NSString stringWithFormat:@"%@", response]];
}

- (void)didClose
{
    [super didClose];
    [LuaSkin logInfo:@"Closed websocket connection"];
}
@end

@implementation HSHTTPDataResponse

- (NSInteger)status {
    return self.hsStatus;
}

- (NSDictionary *)httpHeaders {
    return self.hsHeaders;
}
@end

@implementation HSHTTPConnection

- (BOOL)supportsMethod:(NSString * __unused)method atPath:(NSString * __unused)path {
    if ([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"])
        return requestContentLength <= ((HSHTTPServer *)config.server).maxBodySize ;

    return YES;
}

- (void)handleUnknownMethod:(NSString *)method
{
    if (requestContentLength > ((HSHTTPServer *)config.server).maxBodySize) {

        // Status code 413 - Request Entity Too Large
        HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:413 description:nil version:HTTPVersion1_1];
        [response setHeaderField:@"Content-Length" value:@"0"];
        [response setHeaderField:@"Connection" value:@"close"];

        NSData *responseData = [self preprocessErrorResponse:response];
        [asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_FINAL_RESPONSE];
    } else {
        [super handleUnknownMethod:method];
    }
}

- (NSData *)preprocessErrorResponse:(HTTPMessage *)response {
    if ([response statusCode] == 413) {
        NSString *msg = [NSString stringWithFormat:@"<html><head><title>Request Entity Too Large</title><head><body><H1>HTTP/1.1 413 Request Entity Too Large</H1><br/>The %@ method is not supported for requests larger than %lu bytes.<br/><hr/></body></html>", [request method], ((HSHTTPServer *)config.server).maxBodySize];
        NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];

        [response setBody:msgData];

        NSString *contentLengthStr = [NSString stringWithFormat:@"%lu", (unsigned long)[msgData length]];
        [response setHeaderField:@"Content-Length" value:contentLengthStr];
    }

    return [super preprocessErrorResponse:response];
}

- (void)processBodyData:(NSData *)postDataChunk
{
    [request appendData:postDataChunk];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    __block int responseCode = 0;
    __block NSMutableDictionary *responseHeaders = nil;
    __block NSData *responseBody = nil;

    void (^responseCallbackBlock)(void) = ^{
        if (((HSHTTPServer *)self->config.server).fn != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            lua_State *L = skin.L;
            _lua_stackguard_entry(L);

            // add some headers for callback function to access
            [self->request setHeaderField:@"X-Remote-Addr" value:self->asyncSocket.connectedHost];
            [self->request setHeaderField:@"X-Remote-Port" value:[NSString stringWithFormat:@"%hu", self->asyncSocket.connectedPort]];
            [self->request setHeaderField:@"X-Server-Addr" value:self->asyncSocket.localHost];
            [self->request setHeaderField:@"X-Server-Port" value:[NSString stringWithFormat:@"%hu", self->asyncSocket.localPort]];


            [skin pushLuaRef:refTable ref:((HSHTTPServer *)self->config.server).fn];
            lua_pushstring(L, [method UTF8String]);
            lua_pushstring(L, [path UTF8String]);
            [skin pushNSObject:[self->request allHeaderFields]];
            [skin pushNSObject:[self->request body] withOptions:LS_NSLuaStringAsDataOnly];

            if (![skin protectedCallAndTraceback:4 nresults:3]) {
                const char *errorMsg = lua_tostring(L, -1);
                [skin logError:[NSString stringWithFormat:@"hs.httpserver:setCallback() callback error: %s", errorMsg]];
                responseCode = 503;
                responseBody = [NSData dataWithData:[@"An error occurred during hs.httpserver callback handling" dataUsingEncoding:NSUTF8StringEncoding]];
                lua_pop(L, 1) ; // the error message
            } else {
                if (!(lua_type(L, -3) == LUA_TSTRING && lua_type(L, -2) == LUA_TNUMBER && lua_type(L, -1) == LUA_TTABLE)) {
                    [skin logError:@"hs.httpserver:setCallback() callbacks must return three values. A string for the response body, an integer response code, and a table of headers"];
                    responseCode = 503;
                    responseBody = [NSData dataWithData:[@"Callback handler returned invalid values" dataUsingEncoding:NSUTF8StringEncoding]];
                } else {
                    responseBody = [skin toNSObjectAtIndex:-3 withOptions:LS_NSLuaStringAsDataOnly];
                    responseCode = (int)lua_tointeger(L, -2);

                    responseHeaders = [[NSMutableDictionary alloc] init];
                    BOOL headerTypeError = NO;
                    // Push nil onto the stack, which means that the table has moved from -1 to -2
                    lua_pushnil(L);
                    while (lua_next(L, -2)) {
                        if (lua_type(L, -1) == LUA_TSTRING && lua_type(L, -2) == LUA_TSTRING) {
                            NSString *key = [skin toNSObjectAtIndex:-2];
                            NSString *value = [skin toNSObjectAtIndex:-1];
                            [responseHeaders setObject:value forKey:key];
                        } else {
                            headerTypeError = YES;
                        }
                        lua_pop(L, 1);
                    }
                    if (headerTypeError) {
                        [skin logError:@"hs.httpserver:setCallback() callback returned a header table that contains non-strings"];
                    }
                }
                lua_pop(L, 3) ; // our results... don't leave them on the stack
            }
            _lua_stackguard_exit(L);
        }
    };

    // Make sure we do all the above Lua work on the main thread
    if ([NSThread isMainThread]) {
        responseCallbackBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), responseCallbackBlock);
    }

    HSHTTPDataResponse *response = [[HSHTTPDataResponse alloc] initWithData:responseBody];
    response.hsStatus = responseCode;
    response.hsHeaders = responseHeaders;

    return response;
}

- (BOOL)isPasswordProtected:(NSString * __unused)path {
    return ((HSHTTPServer *)config.server).httpPassword != nil;
}

- (BOOL)useDigestAccessAuthentication {
    return YES;
}

- (NSString *)passwordForUser:(NSString * __unused)username {
    return ((HSHTTPServer *)config.server).httpPassword;
}

- (WebSocket *)webSocketForURI:(NSString *)path
{
    if([path isEqualToString:((HSHTTPServer *)config.server).wsPath])
    {
        HSWebSocket *ws = [[HSWebSocket alloc] initWithRequest:request socket:asyncSocket];
        ws.callback = ((HSHTTPServer *)config.server).wsCallback;
        ((HSHTTPServer *)config.server).ws = ws;
        return ws;
    }

    return [super webSocketForURI:path];
}
@end

@implementation HSHTTPSConnection
- (BOOL)isSecureServer {
    return YES;
}

- (NSArray *)sslIdentityAndCertificates {
    NSArray *chain;
    NSError *certError;
    SecIdentityRef identity = MYGetOrCreateAnonymousIdentity(@"Hammerspoon HTTP Server", 20 * kMYAnonymousIdentityDefaultExpirationInterval, &certError);
    if (!identity) {
        NSLog(@"ERROR: Unable to find/generate a certificate: %@", certError);
        return nil;
    }

    ((HSHTTPServer *)config.server).sslIdentity = identity;
    chain = [NSArray arrayWithObject:(__bridge id)identity];
    return chain;
}

// We're overriding this because CocoaHTTPServer seems to have not been updated for deprecated APIs
- (void)startConnection
{
    // Override me to do any custom work before the connection starts.
    //
    // Be sure to invoke [super startConnection] when you're done.

    //HTTPLogTrace();

    if ([self isSecureServer])
    {
        // We are configured to be an HTTPS server.
        // That is, we secure via SSL/TLS the connection prior to any communication.

        NSArray *certificates = [self sslIdentityAndCertificates];

        if ([certificates count] > 0)
        {
            // All connections are assumed to be secure. Only secure connections are allowed on this server.
            NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];

            // Configure this connection as the server
            [settings setObject:[NSNumber numberWithBool:YES]
                         forKey:(NSString *)kCFStreamSSLIsServer];

            [settings setObject:certificates
                         forKey:(NSString *)kCFStreamSSLCertificates];

            // Configure this connection to use the highest possible SSL level
            [settings setObject:[NSNumber numberWithInteger:kTLSProtocol12] forKey:GCDAsyncSocketSSLProtocolVersionMin];
            [settings setObject:[NSNumber numberWithInteger:kTLSProtocol12] forKey:GCDAsyncSocketSSLProtocolVersionMax];

            [asyncSocket startTLS:settings];
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [(HTTPConnection *)self performSelector:@selector(startReadingRequest)];
#pragma clang diagnostic pop
}
@end

typedef struct _httpserver_t {
    void *server;
} httpserver_t;

/// hs.httpserver.new([ssl], [bonjour]) -> object
/// Function
/// Creates a new HTTP or HTTPS server
///
/// Parameters:
///  * ssl     - An optional boolean. If true, the server will start using HTTPS. Defaults to false.
///  * bonjour - An optional boolean. If true, the server will advertise itself with Bonjour.  Defaults to true. Note that in order to change this, you must supply a true or false value for the `ssl` argument.
///
/// Returns:
///  * An `hs.httpserver` object
///
/// Notes:
///  * By default, the server will start on a random TCP port and advertise itself with Bonjour. You can check the port with `hs.httpserver:getPort()`
///  * By default, the server will listen on all network interfaces. You can override this with `hs.httpserver:setInterface()` before starting the server
///  * Currently, in HTTPS mode, the server will use a self-signed certificate, which most browsers will warn about. If you want/need to be able to use `hs.httpserver` with a certificate signed by a trusted Certificate Authority, please file an bug on Hammerspoon requesting support for this.
static int httpserver_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    BOOL useSSL     = (lua_type(L, 1) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 1) : false;
    BOOL useBonjour = (lua_type(L, 2) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 2) : true;

    httpserver_t *httpServer = lua_newuserdata(L, sizeof(httpserver_t));
    memset(httpServer, 0, sizeof(httpserver_t));

    HSHTTPServer *server = [[HSHTTPServer alloc] init];

    if (useSSL) {
        [server setConnectionClass:[HSHTTPSConnection class]];
    } else {
        [server setConnectionClass:[HSHTTPConnection class]];
    }
    if (useBonjour) [server setType:@"_http._tcp."];

    server.fn = LUA_NOREF;
    httpServer->server = (__bridge_retained void *)server;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

/// hs.httpserver:websocket(path, callback) -> object
/// Method
/// Enables a websocket endpoint on the HTTP server
///
/// Parameters:
///  * path - A string containing the websocket path such as '/ws'
///  * callback - A function returning a string for each recieved websocket message
///
/// Returns:
///  * The `hs.httpserver` object
///
/// Notes:
///  * The callback is passed one string parameter containing the received message
///  * The callback must return a string containing the response message
///  * Given a path '/mysock' and a port of 8000, the websocket URL is as follows:
///   * ws://localhost:8000/mysock
///   * wss://localhost:8000/mysock (if SSL enabled)
static int httpserver_websocket(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TFUNCTION, LS_TBREAK];
    HSHTTPServer *server = getUserData(L, 1);

    server.wsPath = [skin toNSObjectAtIndex:2];
    server.wsCallback = [skin luaUnref:refTable ref:server.wsCallback];
    lua_pushvalue(L, 3);
    server.wsCallback = [skin luaRef:refTable];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:send(message) -> object
/// Method
/// Sends a message to the websocket client
///
/// Parameters:
///  * message - A string containing the message to send
///
/// Returns:
///  * The `hs.httpserver` object
static int httpserver_send(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSHTTPServer *server = getUserData(L, 1);

    [server.ws sendMessage:[skin toNSObjectAtIndex:2]];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:setCallback([callback]) -> object
/// Method
/// Sets the request handling callback for an HTTP server object
///
/// Parameters:
///  * callback - An optional function that will be called to process each incoming HTTP request, or nil to remove an existing callback. See the notes section below for more information about this callback
///
/// Returns:
///  * The `hs.httpserver` object
///
/// Notes:
///  * The callback will be passed four arguments:
///   * A string containing the type of request (i.e. `GET`/`POST`/`DELETE`/etc)
///   * A string containing the path element of the request (e.g. `/index.html`)
///   * A table containing the request headers
///   * A string containing the raw contents of the request body, or the empty string if no body is included in the request.
///  * The callback *must* return three values:
///   * A string containing the body of the response
///   * An integer containing the response code (e.g. 200 for a successful request)
///   * A table containing additional HTTP headers to set (or an empty table, `{}`, if no extra headers are required)
///
/// Notes:
///  * A POST request, often used by HTML forms, will store the contents of the form in the body of the request.
static int httpserver_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    HSHTTPServer *server = getUserData(L, 1);

    switch (lua_type(L, 2)) {
        case LUA_TFUNCTION:
            server.fn = [skin luaUnref:refTable ref:server.fn];
            lua_pushvalue(L, 2);
            server.fn = [skin luaRef:refTable];
            break;
        case LUA_TNIL:
        case LUA_TNONE:
            server.fn = [skin luaUnref:refTable ref:server.fn];
            break;
        default:
            [skin logError:@"Unknown type passed to hs.httpserver:setCallback(). Argument must be a function or nil"];
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:maxBodySize([size]) -> object | current-value
/// Method
/// Get or set the maximum allowed body size for an incoming HTTP request.
///
/// Parameters:
///  * size - An optional integer value specifying the maximum body size allowed for an incoming HTTP request in bytes.  Defaults to 10485760 (10 MB).
///
/// Returns:
///  * If a new size is specified, returns the `hs.httpserver` object; otherwise the current value.
///
/// Notes:
///  * Because the Hammerspoon http server processes incoming requests completely in memory, this method puts a limit on the maximum size for a POST or PUT request.
static int httpserver_maxBodySize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK];

    HSHTTPServer *server = getUserData(L, 1);
    if (lua_gettop(L) == 2) {
        server.maxBodySize = (NSUInteger)lua_tointeger(L, 2);
        lua_pushvalue(L, 1);
    } else {
        lua_pushinteger(L, (lua_Integer)server.maxBodySize);
    }
    return 1;
}

/// hs.httpserver:setPassword([password]) -> object
/// Method
/// Sets a password for an HTTP server object
///
/// Parameters:
///  * password - An optional string that contains the server password, or nil to remove an existing password
///
/// Returns:
///  * The `hs.httpserver` object
///
/// Notes:
///  * It is not currently possible to set multiple passwords for different users, or passwords only on specific paths
static int httpserver_setPassword(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    HSHTTPServer *server = getUserData(L, 1);

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
        case LUA_TNONE:
            server.httpPassword = nil;
            break;
        case LUA_TSTRING:
            server.httpPassword = [skin toNSObjectAtIndex:2];
            break;
        default:
            [skin logError:@"Unknown type passed to hs.httpserver:setPassword(). Argument must be a string or nil"];
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:start() -> object
/// Method
/// Starts an HTTP server object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.httpserver` object
static int httpserver_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSHTTPServer *server = getUserData(L, 1);

    if (server.fn == LUA_NOREF) {
        [skin logError:@"hs.httpserver:start() called with no callback set. You must call hs.httpserver:setCallback() first"];
    } else {
        NSError *error = nil;
        if (![server start:&error]) {
            [skin logError:[NSString stringWithFormat:@"hs.httpserver:start() Unable to start object: %@", error]];
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:stop() -> object
/// Method
/// Stops an HTTP server object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.httpserver` object
static int httpserver_stop(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    [server stop];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:getPort() -> number
/// Method
/// Gets the TCP port the server is configured to listen on
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the TCP port
static int httpserver_getPort(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    lua_pushinteger(L, [server listeningPort]);
    return 1;
}

/// hs.httpserver:setPort(port) -> object
/// Method
/// Sets the TCP port the server is configured to listen on
///
/// Parameters:
///  * port - An integer containing a TCP port to listen on
///
/// Returns:
///  * The `hs.httpserver` object
static int httpserver_setPort(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    [server setPort:(UInt16)luaL_checkinteger(L, 2)];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:getInterface() -> string or nil
/// Method
/// Gets the network interface the server is configured to listen on
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the network interface name, or nil if the server will listen on all interfaces
static int httpserver_getInterface(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    lua_pushstring(L, [[server interface] UTF8String]);
    return 1;
}

/// hs.httpserver:setInterface(interface) -> object
/// Method
/// Sets the network interface the server is configured to listen on
///
/// Parameters:
///  * interface - A string containing an interface name
///
/// Returns:
///  * The `hs.httpserver` object
///
/// Notes:
///  * As well as real interface names (e.g. `en0`) the following values are valid:
///   * An IP address of one of your interfaces
///   * localhost
///   * loopback
///   * nil (which means all interfaces, and is the default)
static int httpserver_setInterface(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    if (lua_isnoneornil(L, 2)) {
        [server setInterface:nil];
    } else {
        [server setInterface:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]];
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.httpserver:getName() -> string
/// Method
/// Gets the Bonjour name the server is configured to advertise itself as
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the Bonjour name of this server
///
/// Notes:
///  * This is not the hostname of the server, just its name in Bonjour service lists (e.g. Safari's Bonjour bookmarks menu)
static int httpserver_getName(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    lua_pushstring(L, [[server name] UTF8String]);
    return 1;
}

/// hs.httpserver:setName(name) -> object
/// Method
/// Sets the Bonjour name the server should advertise itself as
///
/// Parameters:
///  * name - A string containing the Bonjour name for the server
///
/// Returns:
///  * The `hs.httpserver` object
///
/// Notes:
///  * This is not the hostname of the server, just its name in Bonjour service lists (e.g. Safari's Bonjour bookmarks menu)
static int httpserver_setName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSHTTPServer *server = getUserData(L, 1);
    [server setName:[skin toNSObjectAtIndex:2]];
    lua_pushvalue(L, 1);
    return 1;
}

static int httpserver_objectGC(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    httpserver_t *httpServer = get_item_arg(L, 1);
    HSHTTPServer *server = (__bridge_transfer HSHTTPServer *)httpServer->server;
    [server stop];
    server.fn = [skin luaUnref:refTable ref:server.fn];
    server.wsCallback = [skin luaUnref:refTable ref:server.wsCallback];
    server = nil;

    return 0;
}

static int userdata_tostring(lua_State* L) {
    HSHTTPServer *server = getUserData(L, 1);
    NSString *theName = [server name] ;
    int thePort = [server listeningPort] ;

    if (!theName) theName = @"unnamed" ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@:%d (%p)", USERDATA_TAG, theName, thePort, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg httpserverLib[] = {
    {"new", httpserver_new},

    {NULL, NULL}
};

static const luaL_Reg httpserverObjectLib[] = {
    {"websocket",   httpserver_websocket},
    {"send",        httpserver_send},
    {"start",       httpserver_start},
    {"stop",        httpserver_stop},
    {"getPort",     httpserver_getPort},
    {"setPort",     httpserver_setPort},
    {"getInterface", httpserver_getInterface},
    {"setInterface", httpserver_setInterface},
    {"getName",     httpserver_getName},
    {"setName",     httpserver_setName},
    {"setCallback", httpserver_setCallback},
    {"setPassword", httpserver_setPassword},
    {"maxBodySize", httpserver_maxBodySize},

    {"__tostring", userdata_tostring},
    {"__gc", httpserver_objectGC},
    {NULL, NULL}
};

int luaopen_hs_httpserver_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:"hs.httpserver" functions:httpserverLib metaFunctions:nil objectFunctions:httpserverObjectLib];

    [DDLog addLogger:[DDOSLogger sharedInstance]];

    return 1;
}
