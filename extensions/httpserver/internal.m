#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"
#import <CocoaHTTPServer/HTTPServer.h>
#import <CocoaHTTPServer/HTTPConnection.h>
#import <CocoaHTTPServer/HTTPDataResponse.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "MYAnonymousIdentity.h"

// Defines

#define USERDATA_TAG "hs.httpserver"
#define get_item_arg(L, idx) ((httpserver_t *)luaL_checkudata(L, idx, USERDATA_TAG))
#define getUserData(L, idx) (__bridge HSHTTPServer *)((httpserver_t *)get_item_arg(L, idx))->server

int refTable;

// ObjC Class definitions
@interface HSHTTPServer : HTTPServer
@property int fn;
@property SecIdentityRef sslIdentity;
@property (nonatomic, copy) NSString *httpPassword;
@end

@interface HSHTTPDataResponse : HTTPDataResponse
@property int hsStatus;
@property (nonatomic, copy) NSMutableDictionary *hsHeaders;
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
    }
    return self;
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
    return YES;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    __block int responseCode;
    __block NSMutableDictionary *responseHeaders = nil;
    __block NSString *responseBody = nil;

    void (^responseCallbackBlock)(void) = ^{
        LuaSkin *skin = [LuaSkin shared];
        lua_State *L = skin.L;

        [skin pushLuaRef:refTable ref:((HSHTTPServer *)config.server).fn];
        lua_pushstring(L, [method UTF8String]);
        lua_pushstring(L, [path UTF8String]);

        if (![skin protectedCallAndTraceback:2 nresults:3]) {
            const char *errorMsg = lua_tostring(L, -1);
            CLS_NSLOG(@"%s", errorMsg);
            showError(L, (char *)errorMsg);
            responseCode = 503;
            responseBody = [NSString stringWithUTF8String:"An error occurred during hs.httpserver callback handling"];
        } else {
            if (!(lua_type(L, -3) == LUA_TSTRING && lua_type(L, -2) == LUA_TNUMBER && lua_type(L, -1) == LUA_TTABLE)) {
                showError(L, "ERROR: hs.httpserver callbacks must return three values. A string for the response body, an integer response code and a table of headers");
                responseCode = 503;
                responseBody = [NSString stringWithUTF8String:"Callback handler returned invalid values"];
            } else {
                responseBody = [NSString stringWithUTF8String:lua_tostring(L, -3)];
                responseCode = (int)lua_tointeger(L, -2);

                responseHeaders = [[NSMutableDictionary alloc] init];
                BOOL headerTypeError = NO;
                // Push nil onto the stack, which means that the table has moved from -1 to -2
                lua_pushnil(L);
                while (lua_next(L, -2)) {
                    if (lua_type(L, -1) == LUA_TSTRING && lua_type(L, -2) == LUA_TSTRING) {
                        NSString *key = lua_to_nsstring(L, -2);
                        NSString *value = lua_to_nsstring (L, -1);
                        [responseHeaders setObject:value forKey:key];
                    } else {
                        headerTypeError = YES;
                    }
                    lua_pop(L, 1);
                }
                if (headerTypeError) {
                    showError(L, "ERROR: hs.httpserver callback returned a header table that contains non-strings");
                }
            }
        }
    };

    // Make sure we do all the above Lua work on the main thread
    if ([NSThread isMainThread]) {
        responseCallbackBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), responseCallbackBlock);
    }

    HSHTTPDataResponse *response = [[HSHTTPDataResponse alloc] initWithData:[responseBody dataUsingEncoding:NSUTF8StringEncoding]];
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

    [(HTTPConnection *)self performSelector:@selector(startReadingRequest)];
}
@end

typedef struct _httpserver_t {
    void *server;
} httpserver_t;

/// hs.httpserver.new([ssl]) -> object
/// Function
/// Creates a new HTTP or HTTPS server
///
/// Parameters:
///  * ssl - An optional boolean. If true, the server will start using HTTPS. Defaults to false.
///
/// Returns:
///  * An `hs.httpserver` object
///
/// Notes:
///  * By default, the server will start on a random TCP port and advertise itself with Bonjour. You can check the port with `hs.httpserver:getPort()`
///  * Currently, in HTTPS mode, the server will use a self-signed certificate, which most browsers will warn about. If you want/need to be able to use `hs.httpserver` with a certificate signed by a trusted Certificate Authority, please file an bug on Hammerspoon requesting support for this.
static int httpserver_new(lua_State *L) {
    BOOL useSSL = false;
    httpserver_t *httpServer = lua_newuserdata(L, sizeof(httpserver_t));
    memset(httpServer, 0, sizeof(httpserver_t));

    HSHTTPServer *server = [[HSHTTPServer alloc] init];
    if (lua_type(L, 1) == LUA_TBOOLEAN) {
        useSSL = lua_toboolean(L, 1);
    }

    if (useSSL) {
        [server setConnectionClass:[HSHTTPSConnection class]];
    } else {
        [server setConnectionClass:[HSHTTPConnection class]];
    }
    [server setType:@"_http._tcp."];

    server.fn = LUA_NOREF;
    httpServer->server = (__bridge_retained void *)server;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
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
///  * The callback will be passed two arguments:
///   * A string containing the type of request (i.e. `GET`/`POST`/`DELETE`/etc)
///   * A string containing the path element of the request (e.g. `/index.html`)
///  * The callback *must* return three values:
///   * A string containing the body of the response
///   * An integer containing the response code (e.g. 200 for a successful request)
///   * A table containing additional HTTP headers to set (or an empty table, `{}`, if no extra headers are required)
static int httpserver_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];

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
            showError(L, "ERROR: Unknown type passed to hs.httpserver:setCallback(). Argument must be a function or nil");
            break;
    }

    lua_pushvalue(L, 1);
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
    HSHTTPServer *server = getUserData(L, 1);

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
        case LUA_TNONE:
            server.httpPassword = nil;
            break;
        case LUA_TSTRING:
            server.httpPassword = lua_to_nsstring(L, 2);
            break;
        default:
            showError(L, "ERROR: Unknown type passed to hs.httpserver:setPassword(). Argument must be a string or nil");
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
    HSHTTPServer *server = getUserData(L, 1);

    if (server.fn == LUA_NOREF) {
        showError(L, "ERROR: No callback handler set on hs.httpserver object");
    } else {
        NSError *error = nil;
        if (![server start:&error]) {
            CLS_NSLOG(@"ERROR: Unable to start hs.httpserver object: %@", error);
            showError(L, "ERROR: Unable to start hs.httpserver object");
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
/// sets the TCP port the server is configured to listen on
///
/// Parameters:
///  * port - An integer containing a TCP port to listen on
///
/// Returns:
///  * The `hs.httpserver` object
static int httpserver_setPort(lua_State *L) {
    HSHTTPServer *server = getUserData(L, 1);
    [server setPort:luaL_checkinteger(L, 2)];
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
    HSHTTPServer *server = getUserData(L, 1);
    [server setName:lua_to_nsstring(L, 2)];
    lua_pushvalue(L, 1);
    return 1;
}

static int httpserver_objectGC(lua_State *L) {
    lua_pushcfunction(L, httpserver_stop);
    lua_pushvalue(L, 1);
    lua_call(L, 1, 1);

    lua_pushcfunction(L, httpserver_setCallback);
    lua_pushvalue(L, 1);
    lua_pushnil(L);
    lua_call(L, 1, 1);

    httpserver_t *httpServer = get_item_arg(L, 1);
    HSHTTPServer *server = (__bridge_transfer HSHTTPServer *)httpServer->server;
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
    {"start", httpserver_start},
    {"stop", httpserver_stop},
    {"getPort", httpserver_getPort},
    {"setPort", httpserver_setPort},
    {"getName", httpserver_getName},
    {"setName", httpserver_setName},
    {"setCallback", httpserver_setCallback},
    {"setPassword", httpserver_setPassword},

    {"__tostring", userdata_tostring},
    {"__gc", httpserver_objectGC},
    {NULL, NULL}
};

int luaopen_hs_httpserver_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:"hs.httpserver" functions:httpserverLib metaFunctions:nil objectFunctions:httpserverObjectLib];

    [DDLog addLogger:[DDASLLogger sharedInstance]];

    return 1;
}
