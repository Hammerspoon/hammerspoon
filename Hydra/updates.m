#import "helpers.h"

static hydradoc doc_updates_check = {
    "updates", "check", "updates.check()",
    "Checks for an update. If one is available, calls updates.available(true); otherwise calls updates.available(false)."
};

static NSString* updates_url = @"https://api.github.com/repos/sdegutis/hydra/releases";

static int updatesref;

int updates_check(lua_State* L) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, updatesref);
    lua_getfield(L, -1, "available");
    
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return 0;
    }
    
    int fnindex = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    
    NSURL* url = [NSURL URLWithString:updates_url];
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         lua_rawgeti(L, LUA_REGISTRYINDEX, fnindex);
         luaL_unref(L, LUA_REGISTRYINDEX, fnindex);
         
         if ([(NSHTTPURLResponse*)response statusCode] != 200) {
             printf("checked for update but github's api seems broken\n");
             lua_pop(L, 1);
             return;
         }
         
         NSArray* releases = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
         
         int fullVersions = 0;
         for (NSDictionary* release in releases) {
             NSNumber* prerelease = [release objectForKey:@"prerelease"];
             if ([prerelease boolValue] == NO)
                 fullVersions++;
         }
         
         BOOL updateAvailable = (fullVersions > 1);
         
         lua_pushboolean(L, updateAvailable);
         if (lua_pcall(L, 1, 0, 0))
             hydra_handle_error(L);
     }];
    
    return 0;
}

static const luaL_Reg updateslib[] = {
    {"check", updates_check},
    {NULL, NULL}
};

int luaopen_updates(lua_State* L) {
    hydra_add_doc_group(L, "updates", "Check for and install Hydra updates.");
    hydra_add_doc_item(L, &doc_updates_check);
    
    luaL_newlib(L, updateslib);
    
    lua_pushvalue(L, -1);
    updatesref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    return 1;
}
