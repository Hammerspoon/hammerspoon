#import "helpers.h"

/// === http ===
///
/// For making HTTP/HTTPS requests

/// http.send(url, method, timeout, headers, body, fn(code, header, data, err))
/// Send an HTTP request using the given method, with the following parameters:
///   url must be a string
///   method must be a string (i.e. "GET")
///   timeout must be a number
///   headers must be a table; may be empty; any keys and values present must both be strings
///   body may be a string or nil
///   fn must be a valid function, and is called with the following parameters:
///     code is a number (is sometimes 0, I think?)
///     header is a table of string->string pairs
///     data is a string on success, nil on failure
///     err is a string on failure, nil on success
static int http_send(lua_State* L) {
    NSURL* url = [NSURL URLWithString:[NSString stringWithUTF8String: luaL_checkstring(L, 1)]];
    NSString* method = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    NSTimeInterval timeout = luaL_checknumber(L, 3);
    luaL_checktype(L, 4, LUA_TTABLE);    // headers
    size_t body_n;
    const char* body = lua_tolstring(L, 5, &body_n);
    luaL_checktype(L, 6, LUA_TFUNCTION); // callback
    
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [req setHTTPMethod:method];
    
    lua_pushnil(L);
    while (lua_next(L, 4) != 0) {
        NSString* key = [NSString stringWithUTF8String: lua_tostring(L, -2)];
        NSString* val = [NSString stringWithUTF8String: lua_tostring(L, -1)];
        [req addValue:val forHTTPHeaderField:key];
        lua_pop(L, 1);
    }
    
    if (body) {
        NSData* bodydata = [NSData dataWithBytes:body length:body_n];
        [req setHTTPBody:bodydata];
    }
    
    lua_pushvalue(L, 6);
    int fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               lua_rawgeti(L, LUA_REGISTRYINDEX, fn);
                               
                               NSHTTPURLResponse* httpresponse = (NSHTTPURLResponse*)response;
                               lua_pushnumber(L, [httpresponse statusCode]);
                               
                               lua_newtable(L);
                               for (NSString* key in [httpresponse allHeaderFields]) {
                                   NSString* val = [[httpresponse allHeaderFields] objectForKey:key];
                                   lua_pushstring(L, [key UTF8String]);
                                   lua_pushstring(L, [val UTF8String]);
                                   lua_settable(L, -3);
                               }
                               
                               if (data) {
                                   lua_pushlstring(L, [data bytes], [data length]);
                                   lua_pushnil(L);
                               }
                               else {
                                   lua_pushnil(L);
                                   lua_pushstring(L, [[connectionError localizedDescription] UTF8String]);
                               }
                               
                               if (lua_pcall(L, 4, 0, 0))
                                   hydra_handle_error(L);
                               
                               luaL_unref(L, LUA_REGISTRYINDEX, fn);
                           }];
    
    return 0;
}

static luaL_Reg httplib[] = {
    {"send", http_send},
    {NULL, NULL}
};

int luaopen_http(lua_State* L) {
    luaL_newlib(L, httplib);
    return 1;
}
