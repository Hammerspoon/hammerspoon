#import "helpers.h"

/// updates
///
/// Check for and install Hydra updates.



static NSString* updates_url = @"https://api.github.com/repos/sdegutis/hydra/releases";

/// updates.getversions(fn(versions))
/// Low-level function to get list of available Hydra versions; used by updates.check; you probably want to use updates.check instead of using this directly.
static int updates_getversions(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int fnref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    NSURL* url = [NSURL URLWithString:updates_url];
    NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         lua_rawgeti(L, LUA_REGISTRYINDEX, fnref);
         luaL_unref(L, LUA_REGISTRYINDEX, fnref);
         
         if ([(NSHTTPURLResponse*)response statusCode] != 200) {
             printf("checked for update but github's api seems broken\n");
             lua_pop(L, 1);
             return;
         }
         
         NSArray* releases = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
         
         lua_newtable(L);
         int i = 0;
         
         for (NSDictionary* release in releases) {
             NSString* tag_name = [release objectForKey:@"tag_name"];
             lua_pushstring(L, [tag_name UTF8String]);
             lua_rawseti(L, -2, ++i);
         }
         
         if (lua_pcall(L, 1, 0, 0))
             hydra_handle_error(L);
     }];
    
    return 0;
}


/// updates.currentversion() -> string
/// Low-level function to get current Hydra version; used by updates.check; you probably want to use updates.check instead of using this directly.
static int updates_currentversion(lua_State* L) {
    lua_pushstring(L, [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] UTF8String]);
    return 1;
}


static const luaL_Reg updateslib[] = {
    {"getversions", updates_getversions},
    {"currentversion", updates_currentversion},
    {NULL, NULL}
};

int luaopen_updates(lua_State* L) {
    luaL_newlib(L, updateslib);
    return 1;
}
