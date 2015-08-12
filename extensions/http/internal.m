#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

static NSMutableArray* delegates;

// Create a new Lua table and add all response header keys and values from the response
static void createResponseHeaderTable(lua_State* L, NSHTTPURLResponse* httpResponse){
    NSDictionary *responseHeaders = [httpResponse allHeaderFields];
    lua_newtable(L);
    for (id key in responseHeaders) {
        NSString *value = [responseHeaders objectForKey:key];
        lua_pushstring(L, [value UTF8String]);
        lua_setfield(L, -2, [key UTF8String]);
    }
}

// Definition of the collection delegate to receive callbacks from NSUrlConnection
@interface connectionDelegate : NSObject<NSURLConnectionDelegate>
@property lua_State* L;
@property int fn;
@property(nonatomic, retain) NSMutableData* receivedData;
@property(nonatomic, retain) NSHTTPURLResponse* httpResponse;
@property(nonatomic, retain) NSURLConnection* connection;
@end

// Store a created delegate so we can cancel it on garbage collection
static void store_delegate(connectionDelegate* delegate) {
    [delegates addObject:delegate];
}

// Remove a delegate either if loading has finished or if it needs to be
// garbage collected. This unreferences the lua callback and sets the callback
// reference in the delegate to LUA_NOREF.
static void remove_delegate(lua_State* L, connectionDelegate* delegate) {
    [delegate.connection cancel];
    luaL_unref(L, LUA_REGISTRYINDEX, delegate.fn);
    delegate.fn = LUA_NOREF;
    [delegates removeObject:delegate];
}

// Implementation of the connectionDelegate. If the property fn equals LUA_NOREF
// no lua operations will be performed in the callbacks
@implementation connectionDelegate
- (void)connection:(NSURLConnection * __unused)connection didReceiveResponse:(NSURLResponse *)response {
    self.httpResponse = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection * __unused)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection * __unused)connection {
    if (self.fn == LUA_NOREF) {
        return;
    }
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    NSString* stringReply = (NSString *)[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    int statusCode = (int)[self.httpResponse statusCode];

    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    lua_pushinteger(L, statusCode);
    lua_pushstring(L, [stringReply UTF8String]);
    createResponseHeaderTable(L, self.httpResponse);

    if (![skin protectedCallAndTraceback:3 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
    }
    remove_delegate(L, self);
}

- (void)connection:(NSURLConnection * __unused)connection didFailWithError:(NSError *)error {
    if (self.fn == LUA_NOREF){
        return;
    }
    NSString* errorMessage = [NSString stringWithFormat:@"Connection failed: %@ - %@", [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]];
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, self.fn);
    lua_pushinteger(self.L, -1);
    lua_pushstring(self.L, [errorMessage UTF8String]);
    lua_pcall(self.L, 2, 0, 0);
    remove_delegate(self.L, self);
}

@end

// If the user specified a request body, get it from stack,
// add it to the request and add the content length header field
static void getBodyFromStack(lua_State* L, int index, NSMutableURLRequest* request){
    if (!lua_isnoneornil(L, index)) {
        NSString* body = [NSString stringWithCString:lua_tostring(L, 3) encoding:NSASCIIStringEncoding];
        NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", [postData length]];

        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
    }
}

// Gets all information for the request from the stack and creates a request
static NSMutableURLRequest* getRequestFromStack(lua_State* L){
    NSString* url = lua_to_nsstring(L, 1);
    NSString* method = lua_to_nsstring(L, 2);

    NSMutableURLRequest *request;

    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:method];
    return request;
}

// Gets the table for the headers from stack and adds the key value pairs to the request object
static void extractHeadersFromStack(lua_State* L, int index, NSMutableURLRequest* request){
    if (!lua_isnoneornil(L, index)) {
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            // TODO check key and value for string type
            NSString* key = [NSString stringWithCString:luaL_checkstring(L, -2) encoding:NSASCIIStringEncoding];
            NSString* value = [NSString stringWithCString:luaL_checkstring(L, -1) encoding:NSASCIIStringEncoding];

            [request setValue:value forHTTPHeaderField:key];

            lua_pop(L, 1);
        }
    }
}

/// hs.http.doAsyncRequest(url, method, data, headers, callback)
/// Function
/// Creates an HTTP request and executes it asynchronously
///
/// Parameters:
///  * url - A string containing the URL
///  * method - A string containing the HTTP method to use (e.g. "GET", "POST", etc)
///  * data - A string containing the request body, or nil to send no body
///  * headers - A table containing string keys and values representing request header keys and values, or nil to add no headers
///  * callback - A function to called when the response is received. The function should accept three arguments:
///   * code - A number containing the HTTP response code
///   * body - A string containing the body of the response
///   * headers - A table containing the HTTP headers of the response
///
/// Returns:
///  * None
static int http_doAsyncRequest(lua_State* L){
    NSMutableURLRequest* request = getRequestFromStack(L);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

    luaL_checktype(L, 5, LUA_TFUNCTION);
    lua_pushvalue(L, 5);

    connectionDelegate* delegate = [[connectionDelegate alloc] init];
    delegate.L = L;
    delegate.receivedData = [[NSMutableData alloc] init];
    delegate.fn = luaL_ref(L, LUA_REGISTRYINDEX);

    store_delegate(delegate);

    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];

    delegate.connection = connection;

    return 0;
}

/// hs.http.doRequest(url, method, [data, headers]) -> int, string, table
/// Function
/// Creates an HTTP request and executes it synchronously
///
/// Parameters:
///  * url - A string containing the URL
///  * method - A string containing the HTTP method to use (e.g. "GET", "POST", etc)
///  * data - An optional string containing the data to POST to the URL, or nil to send no data
///  * headers - An optional table of string keys and values used as headers for the request, or nil to add no headers
///
/// Returns:
///  * A number containing the HTTP response status code
///  * A string containing the response body
///  * A table containing the response headers
///
/// Notes:
///  * This function is synchronous and will therefore block all Lua execution until it completes. You are encouraged to use the asynchronous functions.
static int http_doRequest(lua_State* L) {
    NSMutableURLRequest *request = getRequestFromStack(L);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

    NSData *dataReply;
    NSURLResponse *response;
    NSError *error;

    dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

    NSString* stringReply = (NSString *)[[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];

    NSHTTPURLResponse *httpResponse;
    httpResponse = (NSHTTPURLResponse *)response;
    int statusCode = (int)[httpResponse statusCode];

    lua_pushinteger(L, statusCode);
    lua_pushstring(L, [stringReply UTF8String]);

    createResponseHeaderTable(L, httpResponse);

    return 3;
}

static int http_gc(lua_State* L){
    NSMutableArray* delegatesCopy = [[NSMutableArray alloc] init];
    [delegatesCopy addObjectsFromArray:delegates];

    for (connectionDelegate* delegate in delegatesCopy){
        remove_delegate(L, delegate);
    }

    return 0;
}

static const luaL_Reg httplib[] = {
    {"doRequest", http_doRequest},
    {"doAsyncRequest", http_doAsyncRequest},

    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg metalib[] = {
    {"__gc", http_gc},

    {NULL, NULL} // This must end with an empty struct
};

int luaopen_hs_http_internal(lua_State* L) {
    delegates = [[NSMutableArray alloc] init];
    luaL_newlib(L, httplib);

    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    return 1;
}
