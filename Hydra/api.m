#import "hydra.h"
void PHShowAlert(NSString* oneLineMsg, CGFloat duration);

static hydradoc doc_api_showabout = {
    "api", "showabout", "api.showabout()",
    "Displays the standard OS X about panel; implicitly focuses Hydra."
};

int api_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

static hydradoc doc_api_focushydra = {
    "api", "focushydra", "api.focushydra()",
    "Makes Hydra the currently focused app; useful in combination with textgrids."
};

int api_focushydra(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    return 0;
}

static hydradoc doc_api_alert = {
    "api", "alert", "api.alert(str, seconds = 2)",
    "Shows a message in large words briefly in the middle of the screen."
};

int api_alert(lua_State* L) {
    const char* str = lua_tostring(L, 1);
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    PHShowAlert([NSString stringWithUTF8String:str], duration);
    
    return 0;
}

static hydradoc doc_api_fileexists = {
    "api", "fileexists", "api.fileexists(path) -> exists, isdir",
    "Checks if a file exists, and whether it's a directory."
};

// args: [path]
// return: [exists, isdir]
int api_fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
    
    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

static const luaL_Reg apilib[] = {
    {"showabout", api_showabout},
    {"focushydra", api_focushydra},
    {"alert", api_alert},
    {"fileexists", api_fileexists},
    {NULL, NULL}
};

int luaopen_api(lua_State* L) {
    luaL_newlib(L, apilib);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "api");
    
    lua_newtable(L);
    lua_setfield(L, -2, "doc");
    
    _hydra_add_doc_group(L, "api", "Top level API functions.");
    _hydra_add_doc_item(L, &doc_api_showabout);
    _hydra_add_doc_item(L, &doc_api_focushydra);
    _hydra_add_doc_item(L, &doc_api_alert);
    _hydra_add_doc_item(L, &doc_api_fileexists);
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
