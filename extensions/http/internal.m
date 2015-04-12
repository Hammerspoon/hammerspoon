#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

/// Send a POST request
///
static int http_post(lua_State* L) {
	lua_settop(L, 2);
	NSString* url = [NSString stringWithUTF8String: luaL_tolstring(L, 1, NULL)];
	NSString* body = [NSString stringWithUTF8String: luaL_tolstring(L, 1, NULL)];

	NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];

	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];

	NSMutableURLRequest *request;

	request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:url]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];

	NSData *dataReply;
	NSURLResponse *response;
	NSError *error;
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	NSString* stringReply = (NSString *)[[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];

	lua_pushstring(L, [stringReply UTF8String]);

	return 0;
}

static const luaL_Reg httplib[] = {
    {"post", http_post},

    {} // This must end with an empty struct
};

int luaopen_hs_http_internal(lua_State* L) {
    luaL_newlib(L, httplib);

    return 1;
}