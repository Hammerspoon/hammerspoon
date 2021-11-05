@import Foundation;
@import Cocoa;
@import Carbon;
@import LuaSkin;
@import WebKit;

static LSRefTable refTable;
static NSMutableArray* delegates;

// Convert a response body to data we can send to Lua
static id responseBodyToId(NSHTTPURLResponse *httpResponse, NSData *bodyData) {
    NSString *contentType = [httpResponse.allHeaderFields objectForKey:@"Content-Type"];

    // If the response falls in the text/* content type, convert it to a string, otherwise
    // leave it as raw data
    if ([contentType hasPrefix:@"text/"]) {
        return [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
    }

    return bodyData;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    [delegate.connection cancel];
    delegate.fn = [skin luaUnref:refTable ref:delegate.fn];
    [delegates removeObject:delegate];
}

// Implementation of the connectionDelegate. If the property fn equals LUA_NOREF
// no lua operations will be performed in the callbacks
//
// From Apple: In rare cases, for example in the case of an HTTP load where the content type
// of the load data is multipart/x-mixed-replace, the delegate will receive more than one
// connection:didReceiveResponse: message. When this happens, discard (or process) all
// data previously delivered by connection:didReceiveData:, and prepare to handle the
// next part (which could potentially have a different MIME type).
@implementation connectionDelegate
- (void)connection:(NSURLConnection * __unused)connection didReceiveResponse:(NSURLResponse *)response {
    [self.receivedData setLength:0];
    self.httpResponse = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection * __unused)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection * __unused)connection {
    if (self.fn == LUA_NOREF) {
        return;
    }
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);

    [skin pushLuaRef:refTable ref:self.fn];
    lua_pushinteger(L, (int)self.httpResponse.statusCode);
    [skin pushNSObject:responseBodyToId(self.httpResponse, self.receivedData)];
    [skin pushNSObject:self.httpResponse.allHeaderFields];
    [skin protectedCallAndError:@"hs.http connectionDelefate:didFinishLoading" nargs:3 nresults:0];

    remove_delegate(L, self);
    _lua_stackguard_exit(L);
}

- (void)connection:(NSURLConnection * __unused)connection didFailWithError:(NSError *)error {
    if (self.fn == LUA_NOREF){
        return;
    }
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);

    NSString* errorMessage = [NSString stringWithFormat:@"Connection failed: %@ - %@", [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]];
    [skin pushLuaRef:refTable ref:self.fn];
    lua_pushinteger(self.L, -1);
    [skin pushNSObject:errorMessage];
    [skin protectedCallAndError:@"hs.http connectionDelegate:didFailWithError" nargs:2 nresults:0];
    remove_delegate(self.L, self);
    _lua_stackguard_exit(skin.L);
}

@end

// If the user specified a request body, get it from stack,
// add it to the request and add the content length header field
static void getBodyFromStack(lua_State* L, int index, NSMutableURLRequest* request){
    if (!lua_isnoneornil(L, index)) {
        NSData *postData ;
        if (lua_type(L, index) == LUA_TSTRING) {
            postData = [[LuaSkin sharedWithState:L] toNSObjectAtIndex:index withOptions:LS_NSLuaStringAsDataOnly] ;
        } else {
            NSString* body = [NSString stringWithCString:lua_tostring(L, index) encoding:NSASCIIStringEncoding];
            postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        }
        if (postData) {
            NSString *postLength = [NSString stringWithFormat:@"%lu", [postData length]];
            [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody:postData];
        } else {
            [LuaSkin logError:[NSString stringWithFormat:@"hs.http - getBodyFromStack - non-nil entry at stack index %u but unable to convert to NSData", index]] ;
        }
    }
}

// Gets all information for the request from the stack and creates a request
static NSMutableURLRequest* getRequestFromStack(lua_State* L, NSString* cachePolicy){
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSString* url = [skin toNSObjectAtIndex:1];
    NSString* method = [skin toNSObjectAtIndex:2];

    NSUInteger selectedCachePolicy;
    if ([cachePolicy isEqualToString:@"protocolCachePolicy"]) {
        selectedCachePolicy = NSURLRequestUseProtocolCachePolicy;
    } else if ([cachePolicy isEqualToString:@"ignoreLocalCache"]) {
        selectedCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    } else if ([cachePolicy isEqualToString:@"ignoreLocalAndRemoteCache"]) {
        selectedCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    } else if ([cachePolicy isEqualToString:@"returnCacheOrLoad"]) {
        selectedCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    } else if ([cachePolicy isEqualToString:@"returnCacheDontLoad"]) {
        selectedCachePolicy = NSURLRequestReturnCacheDataDontLoad;
    } else if ([cachePolicy isEqualToString:@"reloadRevalidatingCache"]) {
        selectedCachePolicy = NSURLRequestReloadRevalidatingCacheData;
    } else {
        selectedCachePolicy = NSURLRequestUseProtocolCachePolicy;
    }

    NSMutableURLRequest *request;
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                      cachePolicy: selectedCachePolicy
                                  timeoutInterval: 60.00];
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

/// hs.http.doAsyncRequest(url, method, data, headers, callback, [cachePolicy])
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
///  * cachePolicy - An optional string containing the cache policy ("protocolCachePolicy", "ignoreLocalCache", "ignoreLocalAndRemoteCache", "returnCacheOrLoad", "returnCacheDontLoad" or "reloadRevalidatingCache"). Defaults to `protocolCachePolicy`.
///
/// Returns:
///  * None
///
/// Notes:
///  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
///  * If the Content-Type response header begins `text/` then the response body return value is a UTF8 string. Any other content type passes the response body, unaltered, as a stream of bytes.
static int http_doAsyncRequest(lua_State* L){
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING|LS_TNIL, LS_TTABLE|LS_TNIL, LS_TFUNCTION, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString* cachePolicy = nil;
    if (lua_type(L, 6) == LUA_TSTRING) {
        cachePolicy = [skin toNSObjectAtIndex:6];
    }

    NSMutableURLRequest* request = getRequestFromStack(L, cachePolicy);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

    luaL_checktype(L, 5, LUA_TFUNCTION);
    lua_pushvalue(L, 5);

    connectionDelegate* delegate = [[connectionDelegate alloc] init];
    delegate.L = L;
    delegate.receivedData = [[NSMutableData alloc] init];
    delegate.fn = [skin luaRef:refTable];

    store_delegate(delegate);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
#pragma clang diagnostic pop

    delegate.connection = connection;

    return 0;
}

/// hs.http.doRequest(url, method, [data, headers, cachePolicy]) -> int, string, table
/// Function
/// Creates an HTTP request and executes it synchronously
///
/// Parameters:
///  * url - A string containing the URL
///  * method - A string containing the HTTP method to use (e.g. "GET", "POST", etc)
///  * data - An optional string containing the data to POST to the URL, or nil to send no data
///  * headers - An optional table of string keys and values used as headers for the request, or nil to add no headers
///  * cachePolicy - An optional string containing the cache policy ("protocolCachePolicy", "ignoreLocalCache", "ignoreLocalAndRemoteCache", "returnCacheOrLoad", "returnCacheDontLoad" or "reloadRevalidatingCache"). Defaults to `protocolCachePolicy`.
///
/// Returns:
///  * A number containing the HTTP response status code
///  * A string containing the response body
///  * A table containing the response headers
///
/// Notes:
///  * If authentication is required in order to download the request, the required credentials must be specified as part of the URL (e.g. "http://user:password@host.com/"). If authentication fails, or credentials are missing, the connection will attempt to continue without credentials.
///
///  * This function is synchronous and will therefore block all Lua execution until it completes. You are encouraged to use the asynchronous functions.
///  * If you attempt to connect to a local Hammerspoon server created with `hs.httpserver`, then Hammerspoon will block until the connection times out (60 seconds), return a failed result due to the timeout, and then the `hs.httpserver` callback function will be invoked (so any side effects of the function will occur, but it's results will be lost).  Use [hs.http.doAsyncRequest](#doAsyncRequest) to avoid this.
///  * If the Content-Type response header begins `text/` then the response body return value is a UTF8 string. Any other content type passes the response body, unaltered, as a stream of bytes.
static int http_doRequest(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING|LS_TNIL|LS_TOPTIONAL, LS_TTABLE|LS_TNIL|LS_TOPTIONAL, LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];

    NSString* cachePolicy = [skin toNSObjectAtIndex:5];

    NSMutableURLRequest *request = getRequestFromStack(L, cachePolicy);
    getBodyFromStack(L, 3, request);
    extractHeadersFromStack(L, 4, request);

    NSData *dataReply;
    NSURLResponse *response;
    NSError *error;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
#pragma clang diagnostic pop

    NSHTTPURLResponse *httpResponse;
    httpResponse = (NSHTTPURLResponse *)response;

    lua_pushinteger(L, (int)httpResponse.statusCode);
    [skin pushNSObject:responseBodyToId(httpResponse, dataReply)];
    [skin pushNSObject:httpResponse.allHeaderFields];

    return 3;
}

// NOTE: this function is wrapped in init.lua
static int http_encodeForQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    luaL_checkstring(L, 1) ;
    NSString *value = [skin toNSObjectAtIndex:1] ;

    if ([value respondsToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
        [skin pushNSObject:[value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]] ;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [skin pushNSObject:[value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] ;
#pragma clang diagnostic pop
    }
    return 1 ;
}

/// hs.http.urlParts(url) -> table
/// Function
/// Returns a table of keys containing the individual components of the provided url.
///
/// Parameters:
///  * url - the url to parse into it's individual components
///
/// Returns:
///  * a table containing any of the following keys which apply to the specified url:
///    * absoluteString           - The URL string for the URL as an absolute URL.
///    * absoluteURL              - An absolute URL that refers to the same resource as the provided URL.
///    * baseURL                  - the base URL, if the URL is relative
///    * fileSystemRepresentation - the URL’s unescaped path specified as a file system path
///    * fragment                 - the fragment, if specified in the URL
///    * host                     - the host for the URL
///    * isFileURL                - a boolean value indicating whether or not the URL represents a local file
///    * lastPathComponent        - the last path component specified in the URL
///    * parameterString          - the parameter string, if specified in the URL
///    * password                 - the password, if specified in the URL
///    * path                     - the unescaped path specified in the URL
///    * pathComponents           - an array containing the path components of the URL
///    * pathExtension            - the file extension, if specified in the URL
///    * port                     - the port, if specified in the URL
///    * query                    - the query, if specified in the URL
///    * queryItems               - if the URL contains a query string, then this field contains an array of the unescaped key-value pairs for each item. Each key-value pair is represented as a table in the array to preserve order.  See notes for more information.
///    * relativePath             - the relative path of the URL without resolving against its base URL. If the path has a trailing slash it is stripped. If the URL is already an absolute URL, this contains the same value as path.
///    * relativeString           - a string representation of the relative portion of the URL. If the URL is already an absolute URL this contains the same value as absoluteString.
///    * resourceSpecifier        - the resource specified in the URL
///    * scheme                   - the scheme of the URL
///    * standardizedURL          - the URL with any instances of ".." or "." removed from its path
///    * user                     - the username, if specified in the URL
///
/// Notes:
///  * This function assumes that the URL conforms to RFC 1808.  If the URL is malformed or does not conform to RFC1808, then many of these fields may be missing.
///
///  * A contrived example for the url `http://user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment`:
///
///     > hs.inspect(hs.http.urlParts("http://user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment"))
///      {
///        absoluteString = "http://user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment",
///        absoluteURL = "http://user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment",
///        fileSystemRepresentation = "/path/to a/../file.txt",
///        fragment = "fragment",
///        host = "host.site.com",
///        isFileURL = false,
///        lastPathComponent = "file.txt",
///        parameterString = "parameter",
///        password = "password",
///        path = "/path/to a/../file.txt",
///        pathComponents = { "/", "path", "to a", "..", "file.txt" },
///        pathExtension = "txt",
///        port = 80,
///        query = "query1=1&query2=a%28",
///        queryItems = { {
///            query1 = "1"
///          }, {
///            query2 = "a("
///          } },
///        relativePath = "/path/to a/../file.txt",
///        relativeString = "http://user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment",
///        resourceSpecifier = "//user:password@host.site.com:80/path/to%20a/../file.txt;parameter?query1=1&query2=a%28#fragment",
///        scheme = "http",
///        standardizedURL = "http://user:password@host.site.com:80/path/file.txt;parameter?query1=1&query2=a%28#fragment",
///        user = "user"
///      }
///
///  * Because it is valid for a query key-value pair to be missing either the key or the value or both, the following conventions are used:
///    * a missing key (e.g. '=value') will be represented as { "" = value }
///    * a missing value (e.g. 'key=') will be represented as { key = "" }
///    * a missing value with no = (e.g. 'key') will be represented as { key }
///    * a missing key and value (e.g. '=') will be represente as { "" = "" }
///    * an empty query item (e.g. a query ending in '&' or a query containing && between two other query items) will be represented as { "" }
///
///  * At present Hammerspoon does not provide a way to represent a URL as a true Objective-C object within the OS X API.  This affects the following keys:
///    * relative URLs are not possible to express properly so baseURL will always be nil and relativePath and relativeString will always match path and absoluteString.
///    * These limitations may change in a future update if the need for a more fully compliant URL treatment is determined to be necessary.
#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))
static int http_urlParts(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURL *theURL ;
    if (lua_type(L, 1) == LUA_TUSERDATA) {
// this only works if the userdata is an NSWindow or subclass with a contentView that is a WKWebView or subclass
// hs.webview meets this criteria
        NSWindow  *theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1) ;
        WKWebView *theView   = theWindow.contentView ;
        theURL               = [theView URL] ;
    } else {
        luaL_checkstring(L, 1) ;
        theURL = [NSURL URLWithString:(NSString *)[skin toNSObjectAtIndex:1]] ;
    }

    lua_newtable(L) ;
      [skin pushNSObject:[theURL absoluteString]] ;     lua_setfield(L, -2, "absoluteString") ;
      [skin pushNSObject:[theURL absoluteURL]] ;        lua_setfield(L, -2, "absoluteURL") ;
      [skin pushNSObject:[theURL baseURL]] ;            lua_setfield(L, -2, "baseURL") ;
      lua_pushstring(L, [theURL fileSystemRepresentation]) ;        lua_setfield(L, -2, "fileSystemRepresentation") ;
      [skin pushNSObject:[theURL fragment]] ;           lua_setfield(L, -2, "fragment") ;
      [skin pushNSObject:[theURL host]] ;               lua_setfield(L, -2, "host") ;
      [skin pushNSObject:[theURL lastPathComponent]] ;  lua_setfield(L, -2, "lastPathComponent") ;
      [skin pushNSObject:[theURL parameterString]] ;    lua_setfield(L, -2, "parameterString") ;
      [skin pushNSObject:[theURL password]] ;           lua_setfield(L, -2, "password") ;
      [skin pushNSObject:[theURL path]] ;               lua_setfield(L, -2, "path") ;
      [skin pushNSObject:[theURL pathComponents]] ;     lua_setfield(L, -2, "pathComponents") ;
      [skin pushNSObject:[theURL pathExtension]] ;      lua_setfield(L, -2, "pathExtension") ;
      [skin pushNSObject:[theURL port]] ;               lua_setfield(L, -2, "port") ;
      [skin pushNSObject:[theURL query]] ;              lua_setfield(L, -2, "query") ;
      [skin pushNSObject:[theURL relativePath]] ;       lua_setfield(L, -2, "relativePath") ;
      [skin pushNSObject:[theURL relativeString]] ;     lua_setfield(L, -2, "relativeString") ;
      [skin pushNSObject:[theURL resourceSpecifier]] ;  lua_setfield(L, -2, "resourceSpecifier") ;
      [skin pushNSObject:[theURL scheme]] ;             lua_setfield(L, -2, "scheme") ;
      [skin pushNSObject:[theURL standardizedURL]] ;    lua_setfield(L, -2, "standardizedURL") ;
      [skin pushNSObject:[theURL user]] ;               lua_setfield(L, -2, "user") ;
      lua_pushboolean(L, [theURL isFileURL]) ;                      lua_setfield(L, -2, "isFileURL") ;

      if ([theURL query]) {
          NSURLComponents *components = [NSURLComponents componentsWithURL:theURL resolvingAgainstBaseURL:YES] ;

          // NSQueryItem doesn't properly handle + as space in a query string.  According to Apple, this is
          // intended (see https://openradar.appspot.com/24076063), but even their own Safari submits GET
          // and POST data with + as the space.  Whatever.  Fix it.
          components.percentEncodedQuery = [components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%20"];

          lua_newtable(L) ;
          for (NSURLQueryItem *item in [components queryItems]) {
              lua_newtable(L) ;
              if ([item value]) {
                  [skin pushNSObject:[item value]] ; lua_setfield(L, -2, [[item name] UTF8String]) ;
              } else {
                  [skin pushNSObject:[item name]] ; lua_rawseti(L, -2, 1) ;
              }
              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
          }
          lua_setfield(L, -2, "queryItems") ;
      }

    return 1 ;
}

// not used here yet... but they are used in hs.webview.  This seems a more logical location for them, and
// I do hope to use them here when I get a chance, so as to provide a more consistent user experience.

static int NSURLResponse_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURLResponse *theResponse = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [theResponse expectedContentLength]) ; lua_setfield(L, -2, "expectedContentLength") ;
        [skin pushNSObject:[theResponse suggestedFilename]] ;     lua_setfield(L, -2, "suggestedFilename") ;
        [skin pushNSObject:[theResponse MIMEType]] ;              lua_setfield(L, -2, "MIMEType") ;
        [skin pushNSObject:[theResponse textEncodingName]] ;      lua_setfield(L, -2, "textEncodingName") ;
        [skin pushNSObject:[theResponse URL]] ;                   lua_setfield(L, -2, "URL") ;

        if ([obj isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *theHTTPResponse = obj ;
            lua_pushinteger(L, [theHTTPResponse statusCode]) ;      lua_setfield(L, -2, "statusCode") ;
            [skin pushNSObject:[NSHTTPURLResponse localizedStringForStatusCode:[theHTTPResponse statusCode]]] ;
            lua_setfield(L, -2, "statusCodeDescription") ;
            [skin pushNSObject:[theHTTPResponse allHeaderFields]] ; lua_setfield(L, -2, "allHeaderFields") ;
        }

    return 1 ;
}

static int NSURLRequest_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURLRequest *request = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[request mainDocumentURL]] ;         lua_setfield(L, -2, "mainDocumentURL") ;
      [skin pushNSObject:[request URL]] ;                     lua_setfield(L, -2, "URL") ;
      [skin pushNSObject:[request allHTTPHeaderFields]] ;     lua_setfield(L, -2, "HTTPHeaderFields") ;
      [skin pushNSObject:[request HTTPBody]] ;                lua_setfield(L, -2, "HTTPBody") ;
      [skin pushNSObject:[request HTTPMethod]] ;              lua_setfield(L, -2, "HTTPMethod") ;

      lua_pushnumber(L, [request timeoutInterval]) ;          lua_setfield(L, -2, "timeoutInterval") ;
      lua_pushboolean(L, [request HTTPShouldHandleCookies]) ; lua_setfield(L, -2, "HTTPShouldHandleCookies") ;
      lua_pushboolean(L, [request HTTPShouldUsePipelining]) ; lua_setfield(L, -2, "HTTPShouldUsePipelining") ;

//  Are there any macs which support this?
//       lua_pushboolean(L, [request allowsCellularAccess]) ;            lua_setfield(L, -2, "allowsCellularAccess") ;

// HTTPBodyStream -- maybe add if we add NSStream userdata at some point, until then, not in this modules scope, so would be only
//   for others who reuse these converters... not worth it until it is needed.

      switch([request cachePolicy]) {
          case NSURLRequestUseProtocolCachePolicy:       lua_pushstring(L, "protocolCachePolicy") ; break ;
          case NSURLRequestReloadIgnoringLocalCacheData: lua_pushstring(L, "ignoreLocalCache") ; break ;
          case NSURLRequestReturnCacheDataElseLoad:      lua_pushstring(L, "returnCacheOrLoad") ; break ;
          case NSURLRequestReturnCacheDataDontLoad:      lua_pushstring(L, "returnCacheDontLoad") ; break ;
          default:                                       lua_pushstring(L, "unknown") ; break ;
      }
      lua_setfield(L, -2, "cachePolicy") ;

      switch([request networkServiceType]) {
          case NSURLNetworkServiceTypeDefault:    lua_pushstring(L, "default") ; break ;
          case NSURLNetworkServiceTypeVoIP:       lua_pushstring(L, "VoIP") ; break ;
          case NSURLNetworkServiceTypeVideo:      lua_pushstring(L, "video") ; break ;
          case NSURLNetworkServiceTypeBackground: lua_pushstring(L, "background") ; break ;
          case NSURLNetworkServiceTypeVoice:      lua_pushstring(L, "voice") ; break ;
          default:                                lua_pushstring(L, "unknown") ; break ;
      }
      lua_setfield(L, -2, "networkServiceType") ;
    return 1 ;
}

static id table_toNSURLRequest(lua_State* L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init] ;

    lua_pushvalue(L, idx) ;
    switch (lua_type(L, idx)) {
        case LUA_TTABLE:
            if (lua_getfield(L, -1, "URL") == LUA_TSTRING) {
                [request setURL:[NSURL URLWithString:[skin toNSObjectAtIndex:-1]]] ;
            } else {
                lua_pop(L, 2) ;
                [skin logError:@"URL field missing in NSURLRequest table"] ;
                return nil ;
            }
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "mainDocumentURL") == LUA_TSTRING)
                [request setMainDocumentURL:[NSURL URLWithString:[skin toNSObjectAtIndex:-1]]] ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "HTTPBody") == LUA_TSTRING) {
                size_t size ;
                unsigned char *block = (unsigned char *)lua_tolstring(L, -1, &size) ;
                [request setHTTPBody:[NSData dataWithBytes:(void *)block length:size] ];
            }
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "HTTPMethod") == LUA_TSTRING)   // TODO: should probably validate
                [request setHTTPMethod:[skin toNSObjectAtIndex:-1]] ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "timeoutInterval") == LUA_TNUMBER)
                [request setTimeoutInterval:lua_tonumber(L, -1)] ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "HTTPShouldHandleCookies") == LUA_TBOOLEAN)
                [request setHTTPShouldHandleCookies:(BOOL)lua_toboolean(L, -1)] ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "HTTPShouldUsePipelining") == LUA_TBOOLEAN)
                [request setHTTPShouldUsePipelining:(BOOL)lua_toboolean(L, -1)] ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "cachePolicy") == LUA_TSTRING) {
                NSString *cp = [skin toNSObjectAtIndex:-1] ;
                if ([cp isEqualToString:@"protocolCachePolicy"]) { [request setCachePolicy:NSURLRequestUseProtocolCachePolicy] ; } else
                if ([cp isEqualToString:@"ignoreLocalCache"])    { [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData] ; } else
                if ([cp isEqualToString:@"returnCacheOrLoad"])   { [request setCachePolicy:NSURLRequestReturnCacheDataElseLoad] ; } else
                if ([cp isEqualToString:@"returnCacheDontLoad"]) { [request setCachePolicy:NSURLRequestReturnCacheDataDontLoad] ; }
            }
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "networkServiceType") == LUA_TSTRING) {
                NSString *nst = [skin toNSObjectAtIndex:-1] ;
                if ([nst isEqualToString:@"default"])    { [request setNetworkServiceType:NSURLNetworkServiceTypeDefault] ; } else
                if ([nst isEqualToString:@"VoIP"])       { [request setNetworkServiceType:NSURLNetworkServiceTypeVoIP] ; } else
                if ([nst isEqualToString:@"video"])      { [request setNetworkServiceType:NSURLNetworkServiceTypeVideo] ; } else
                if ([nst isEqualToString:@"background"]) { [request setNetworkServiceType:NSURLNetworkServiceTypeBackground] ; } else
                if ([nst isEqualToString:@"voice"])      { [request setNetworkServiceType:NSURLNetworkServiceTypeVoice] ; }
            }
            lua_pop(L, 1) ;

            if (lua_getfield(L, -1, "HTTPHeaderFields") == LUA_TTABLE) {
                NSMutableDictionary *fields = [[skin toNSObjectAtIndex:-1] mutableCopy] ;
                NSMutableArray      *toRemove = [[NSMutableArray alloc] init] ;

                // remove fields which are automatically handled or have non-string keys, convert numbers to strings

                for (id key in [fields allKeys]) {
                    if ([[fields objectForKey:key] isKindOfClass:[NSNumber class]]) {
                        [fields setObject:[[fields objectForKey:key] stringValue] forKey:key] ;
                    }

                    if (![key isKindOfClass:[NSString class]] || ![[fields objectForKey:key] isKindOfClass:[NSString class]]) {
                        [toRemove addObject:key] ;
                    } else {
                        if ([key compare:@"Authorization" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            [toRemove addObject:key] ;
                        } else if ([key compare:@"Connection" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            [toRemove addObject:key] ;
                        } else if ([key compare:@"Host" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            [toRemove addObject:key] ;
                        } else if ([key compare:@"WWW-Authenticate" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            [toRemove addObject:key] ;
                        } else if ([key compare:@"Content-Length" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            [toRemove addObject:key] ;
                        }
                    }
                }
                for (id item in toRemove) { [fields removeObjectForKey:item] ; }

                [request setAllHTTPHeaderFields:fields] ;
            }
            lua_pop(L, 1) ;
            break ;

        case LUA_TSTRING:
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[skin toNSObjectAtIndex:idx]]] ;
            break ;

        default:
            [skin logError:[NSString stringWithFormat:@"Unexpected type passed as a NSURLRequest: %s", lua_typename(L, lua_type(L, idx))]] ;
            return nil ;
    }

    lua_pop(L, 1);
    return request ;
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
    {"doRequest",       http_doRequest},
    {"doAsyncRequest",  http_doAsyncRequest},
    {"urlParts",        http_urlParts},
    {"encodeForQuery",  http_encodeForQuery},

    {NULL, NULL} // This must end with an empty struct
};

static const luaL_Reg metalib[] = {
    {"__gc", http_gc},

    {NULL, NULL} // This must end with an empty struct
};

int luaopen_hs_libhttp(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    delegates = [[NSMutableArray alloc] init];
    refTable = [skin registerLibrary:"hs.http" functions:httplib metaFunctions:metalib];

    [skin registerPushNSHelper:NSURLRequest_toLua      forClass:"NSURLRequest"] ;
    [skin registerPushNSHelper:NSURLResponse_toLua     forClass:"NSURLResponse"] ;
    [skin registerLuaObjectHelper:table_toNSURLRequest forClass:"NSURLRequest"] ;

    return 1;
}
