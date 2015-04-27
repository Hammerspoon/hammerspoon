#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

static void createResponseHeaderTable(lua_State* L, NSHTTPURLResponse* httpResponse){
	NSDictionary *responseHeaders = [httpResponse allHeaderFields];
	lua_newtable(L);
    for(id key in responseHeaders){
    	NSString *value = [responseHeaders objectForKey:key];
    	lua_pushstring(L, [value UTF8String]);
    	lua_setfield(L,-2, [key UTF8String]);
    }
}

@interface connectionDelegate : NSObject<NSURLConnectionDelegate>
@property lua_State* L;
@property int fn;
@property NSMutableData* receivedData;
@property NSHTTPURLResponse* httpResponse;
@end

@implementation connectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	self.httpResponse = (NSHTTPURLResponse *)response;

}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.receivedData appendData:data];

}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSString* stringReply = (NSString *)[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
	int statusCode = [self.httpResponse statusCode];

    lua_pushinteger(self.L,statusCode);
    lua_pushstring(self.L,[stringReply UTF8String]);
    createResponseHeaderTable(self.L,self.httpResponse);
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, self.fn);
    lua_pcall(self.L,3,0,0);
}
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
  	// TODO implement error callback
}
@end

static void getBodyFromStack(lua_State* L, int index, NSMutableURLRequest* request){
	if(!lua_isnil(L,index)){
		NSString* body = [NSString stringWithCString:lua_tostring(L,3) encoding:NSASCIIStringEncoding];
		NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];

		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setHTTPBody:postData];
	}
}

static NSMutableURLRequest* getRequestFromStack(lua_State* L){
	NSString* url = [NSString stringWithCString:luaL_checklstring(L,1,NULL) encoding:NSASCIIStringEncoding];
	NSString* method = [NSString stringWithCString:luaL_checklstring(L,2,NULL) encoding:NSASCIIStringEncoding];

	NSMutableURLRequest *request;

	request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:url]];
	[request setHTTPMethod:method];
	return request;
}

static void extractHeadersFromStack(lua_State* L, int index, NSMutableURLRequest* request){
	if(!lua_isnil(L,index)){
		lua_pushnil(L);
		while (lua_next(L, index) != 0) {
			// TODO check key and value for string type
			NSString* key = [NSString stringWithCString:luaL_checkstring(L,-2) encoding:NSASCIIStringEncoding];
			NSString* value = [NSString stringWithCString:luaL_checkstring(L,-1) encoding:NSASCIIStringEncoding];

			[request setValue:value forHTTPHeaderField:key];

			lua_pop(L, 1);
		}
	}
}

/// hs.http.doAsyncRequest(url, method, [data, headers,] callback)
/// Function
/// Creates a http request and executes it asynchronously, calling the callback upon success
///
/// Parameters:
///  * url - String representing the full URL
///  * method - String representing the HTTP method
///  * data - String presenting the request body
///  * headers - Table containing string keys and values representing request header keys and values
///  * callback - Callback function to called when the response is received
static int http_doAsyncRequest(lua_State* L){
	NSMutableURLRequest* request = getRequestFromStack(L);
	getBodyFromStack(L,3,request);
	extractHeadersFromStack(L,4,request);

	luaL_checktype(L, 5, LUA_TFUNCTION);
	lua_pushvalue(L, 5);

	connectionDelegate* delegate = [[connectionDelegate alloc] init];
	delegate.L = L;
	delegate.receivedData = [[NSMutableData alloc] init];
	delegate.fn = luaL_ref(L, LUA_REGISTRYINDEX);

	NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];

	return 0;
}

/// hs.http.doRequest(url, method, [data, headers]) -> int, string, table
/// Function
/// Creates a http request and sends it to the specified URL
///
/// Parameters:
///  * url - String representing the full URL
///  * method - String, the HTTP method,i.e. GET, POST, PUT, DELETE
///  * data - String representing the data to post to the URL
///  * headers - Table of String keys and values used as headers for the request
///
/// Returns:
///  * the response status code
///  * the response body
///  * the response headers as a table
static int http_doRequest(lua_State* L) {
	NSMutableURLRequest *request = getRequestFromStack(L);
	getBodyFromStack(L,3,request);
	extractHeadersFromStack(L,4,request);

	NSData *dataReply;
	NSURLResponse *response;
	NSError *error;

	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	NSString* stringReply = (NSString *)[[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];

	NSHTTPURLResponse *httpResponse;
	httpResponse = (NSHTTPURLResponse *)response;
    int statusCode = [httpResponse statusCode];

    lua_pushinteger(L,statusCode);
    lua_pushstring(L, [stringReply UTF8String]);

    createResponseHeaderTable(L,httpResponse);

    return 3;
}

static const luaL_Reg httplib[] = {
    {"doRequest", http_doRequest},
    {"doAsyncRequest", http_doAsyncRequest},

    {} // This must end with an empty struct
};

int luaopen_hs_http_internal(lua_State* L) {
    luaL_newlib(L, httplib);

    return 1;
}