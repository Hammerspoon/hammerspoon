#import "hydra.h"
void PHShowAlert(NSString* oneLineMsg, CGFloat duration);

int api_exit(lua_State* L) {
    if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
        lua_close(L);
    
    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static hydradoc doc_api_showabout = {
    NULL, "showabout", "api.showabout()",
    "Displays the standard OS X about panel; implicitly focuses Hydra."
};

int api_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

static hydradoc doc_api_focushydra = {
    NULL, "focushydra", "api.focushydra()",
    "Makes Hydra the currently focused app; useful in combination with textgrids."
};

int api_focushydra(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    return 0;
}

static hydradoc doc_api_alert = {
    NULL, "alert", "api.alert(str, seconds = 2)",
    "Shows a message in large words briefly in the middle of the screen; does tostring() on its argument for convenience.."
};

int api_alert(lua_State* L) {
    size_t len;
    const char* str = luaL_tolstring(L, 1, &len);
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    PHShowAlert([[NSString alloc] initWithBytes:str length:len encoding:NSUTF8StringEncoding], duration);
    
    return 0;
}

static hydradoc doc_api_fileexists = {
    NULL, "fileexists", "api.fileexists(path) -> exists, isdir",
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

static hydradoc doc_api_check_accessibility = {
    NULL, "check_accessibility", "api.check_accessibility(shouldprompt) -> isenabled",
    "Returns whether accessibility is enabled. If passed `true`, prompts the user to enable it."
};

int api_check_accessibility(lua_State* L) {
    NSDictionary* opts = nil;
    
    if (lua_isboolean(L, -1))
        opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @(lua_toboolean(L, -1))};
    
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
    
    lua_pushboolean(L, enabled);
    return 1;
}

static const luaL_Reg apilib[] = {
    {"exit", api_exit},
    {"showabout", api_showabout},
    {"focushydra", api_focushydra},
    {"alert", api_alert},
    {"fileexists", api_fileexists},
    {"check_accessibility", api_check_accessibility},
    {NULL, NULL}
};

int luaopen_api(lua_State* L) {
    luaL_newlib(L, apilib);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "api");
    
    hydra_add_doc_item(L, &doc_api_showabout);
    hydra_add_doc_item(L, &doc_api_focushydra);
    hydra_add_doc_item(L, &doc_api_alert);
    hydra_add_doc_item(L, &doc_api_fileexists);
    hydra_add_doc_item(L, &doc_api_check_accessibility);
    
    // no trailing slash
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
