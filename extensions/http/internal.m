#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

static NSMutableArray* delegates;

// Create a new Lua table and add all response header keys and values from the response
static void createResponseHeaderTable(lua_State* L, NSHTTPURLResponse* httpResponse){
	NSDictionary *responseHeaders = [httpResponse allHeaderFields];
	lua_newtable(L);
    for(id key in responseHeaders){
    	NSString *value = [responseHeaders objectForKey:key];
    	lua_pushstring(L, [value UTF8String]);
    	lua_setfield(L,-2, [key UTF8String]);
    }
}

// Show an error message via hs.showError
static void showError(lua_State* L, NSString* error) {
	lua_getglobal(L, "hs"); 
	lua_getfield(L, -1, "showError"); 
	lua_remove(L, -2);
    lua_pushstring(L, [error UTF8String]);
    lua_pcall(L, 1, 0, 0);
}

@interface connectionDelegate : NSObject<NSURLConnectionDelegate>
@property lua_State* L;
@property int fn;
@property NSMutableData* receivedData;
@property NSHTTPURLResponse* httpResponse;
@property NSURLConnection* connection;
@end

static void store_delegate(connectionDelegate* delegate) {
	[delegates addObject:delegate];
}

static void remove_delegate(lua_State* L, connectionDelegate* delegate) {
	[delegate.connection cancel];
	luaL_unref(L, LUA_REGISTRYINDEX, delegate.fn);
	delegate.fn = LUA_NOREF;
	[delegates removeObject:delegate];
}

@implementation connectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	self.httpResponse = (NSHTTPURLResponse *)response;

}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.receivedData appendData:data];

}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	lua_State* L = self.L;
	if(self.fn == LUA_NOREF){
    	return;
    }
	NSString* stringReply = (NSString *)[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
	int statusCode = [self.httpResponse statusCode];

	lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    lua_pushinteger(L,statusCode);
    lua_pushstring(L,[stringReply UTF8String]);
    createResponseHeaderTable(L,self.httpResponse);
    int cbRes = lua_pcall(L,3,0,0);
    if (cbRes != LUA_OK){
    	NSString* message = [NSString stringWithFormat:@"%s Code: %d", @"Can't call callback", cbRes];
    	showError(L, message);
    }
    remove_delegate(L,self);
}
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
  	if(self.fn == LUA_NOREF){
    	return;
    }
  	NSString* errorMessage = [NSString stringWithFormat:@"Connection failed: %@ - %@", [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]];
  	lua_rawgeti(self.L, LUA_REGISTRYINDEX, self.fn);
  	lua_pushinteger(self.L,-1);
  	lua_pushstring(self.L,[errorMessage UTF8String]);
  	lua_pcall(self.L,2,0,0);
  	remove_delegate(self.L,self);
}
@end

// If the user specified a request body, get it from stack, 
// add it to the request and add the content length header field
static void getBodyFromStack(lua_State* L, int index, NSMutableURLRequest* request){
	if(!lua_isnil(L,index)){
		NSString* body = [NSString stringWithCString:lua_tostring(L,3) encoding:NSASCIIStringEncoding];
		NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];

		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setHTTPBody:postData];
	}
}

// Gets all information for the request from the stack and creates a request
static NSMutableURLRequest* getRequestFromStack(lua_State* L){
	NSString* url = [NSString stringWithCString:luaL_checklstring(L,1,NULL) encoding:NSASCIIStringEncoding];
	NSString* method = [NSString stringWithCString:luaL_checklstring(L,2,NULL) encoding:NSASCIIStringEncoding];

	NSMutableURLRequest *request;

	request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:url]];
	[request setHTTPMethod:method];
	return request;
}

// Gets the table for the headers from stack and adds the key value pairs to the request object
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

	store_delegate(delegate);

	NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];

	delegate.connection = connection;

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

static int http_gc(lua_State* L){
	NSMutableArray* delegatesCopy = [[NSMutableArray alloc] init];
	[delegatesCopy addObjectsFromArray:delegates];

	for(connectionDelegate* delegate in delegatesCopy){
		remove_delegate(L, delegate);
	}

	return 0;
}

static const luaL_Reg httplib[] = {
    {"doRequest", http_doRequest},
    {"doAsyncRequest", http_doAsyncRequest},

    {} // This must end with an empty struct
};

static const luaL_Reg metalib[] = {
    {"__gc", http_gc},

    {} // This must end with an empty struct
};

int luaopen_hs_http_internal(lua_State* L) {
	delegates = [[NSMutableArray alloc] init];
    luaL_newlib(L, httplib);

    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    return 1;
}