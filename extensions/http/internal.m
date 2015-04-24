#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

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
	NSString* url = [NSString stringWithCString:luaL_checklstring(L,1,NULL) encoding:NSASCIIStringEncoding];
	NSString* method = [NSString stringWithCString:luaL_checklstring(L,2,NULL) encoding:NSASCIIStringEncoding];

	NSMutableURLRequest *request;

	request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:url]];
	[request setHTTPMethod:method];

	if(!lua_isnil(L,3)){
		NSString* body = [NSString stringWithCString:lua_tostring(L,3) encoding:NSASCIIStringEncoding];
		NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];

		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setHTTPBody:postData];
	}

	if(!lua_isnil(L,4)){
		lua_pushnil(L);
		while (lua_next(L, 4) != 0) {
			// TODO check key and value for string type
			NSString* key = [NSString stringWithCString:luaL_checkstring(L,-2) encoding:NSASCIIStringEncoding];
			NSString* value = [NSString stringWithCString:luaL_checkstring(L,-1) encoding:NSASCIIStringEncoding];

			[request setValue:value forHTTPHeaderField:key];

			lua_pop(L, 1);
		}
	}

	NSData *dataReply;
	NSURLResponse *response;
	NSError *error;

	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	NSString* stringReply = (NSString *)[[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];

	NSHTTPURLResponse *httpResponse;
	httpResponse = (NSHTTPURLResponse *)response;
    int statusCode = [httpResponse statusCode];
    NSDictionary *responseHeaders = [httpResponse allHeaderFields];

    lua_pushinteger(L,statusCode);
    lua_pushstring(L, [stringReply UTF8String]);

    lua_newtable(L);
    for(id key in responseHeaders){
    	NSString *value = [responseHeaders objectForKey:key];
    	lua_pushstring(L, [value UTF8String]);
    	lua_setfield(L,-2, [key UTF8String]);
    }

    return 3;
}

static const luaL_Reg httplib[] = {
    {"doRequest", http_doRequest},

    {} // This must end with an empty struct
};

int luaopen_hs_http_internal(lua_State* L) {
    luaL_newlib(L, httplib);

    return 1;
}