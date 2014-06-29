#import "helpers.h"
void PHShowAlert(NSString* oneLineMsg, CGFloat duration);

int hydra_exit(lua_State* L) {
    if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
        lua_close(L);
    
    [[NSApplication sharedApplication] terminate: nil];
    return 0; // lol
}

static hydradoc doc_hydra_showabout = {
    "hydra", "showabout", "showabout()",
    "Displays the standard OS X about panel; implicitly focuses Hydra."
};

int hydra_showabout(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

static hydradoc doc_hydra_focushydra = {
    "hydra", "focushydra", "focushydra()",
    "Makes Hydra the currently focused app; useful in combination with textgrids."
};

int hydra_focushydra(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    return 0;
}

static hydradoc doc_hydra_alert = {
    "hydra", "alert", "alert(str, seconds = 2)",
    "Shows a message in large words briefly in the middle of the screen; does tostring() on its argument for convenience.."
};

int hydra_alert(lua_State* L) {
    size_t len;
    const char* str = luaL_tolstring(L, 1, &len);
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    PHShowAlert([[NSString alloc] initWithBytes:str length:len encoding:NSUTF8StringEncoding], duration);
    
    return 0;
}

static hydradoc doc_hydra_fileexists = {
    "hydra", "fileexists", "fileexists(path) -> exists, isdir",
    "Checks if a file exists, and whether it's a directory."
};

// args: [path]
// return: [exists, isdir]
int hydra_fileexists(lua_State* L) {
    NSString* path = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    
    BOOL isdir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
    
    lua_pushboolean(L, exists);
    lua_pushboolean(L, isdir);
    return 2;
}

static hydradoc doc_hydra_check_accessibility = {
    "hydra", "check_accessibility", "check_accessibility(shouldprompt) -> isenabled",
    "Returns whether accessibility is enabled. If passed `true`, prompts the user to enable it."
};

int hydra_check_accessibility(lua_State* L) {
    NSDictionary* opts = nil;
    
    if (lua_isboolean(L, -1))
        opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @(lua_toboolean(L, -1))};
    
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
    
    lua_pushboolean(L, enabled);
    return 1;
}

static const luaL_Reg hydralib[] = {
    {"exit", hydra_exit},
    {"showabout", hydra_showabout},
    {"focushydra", hydra_focushydra},
    {"alert", hydra_alert},
    {"fileexists", hydra_fileexists},
    {"check_accessibility", hydra_check_accessibility},
    {NULL, NULL}
};

int luaopen_hydra(lua_State* L) {
    hydra_add_doc_group(L, "hydra", "General stuff.");
    
    hydra_add_doc_item(L, &doc_hydra_showabout);
    hydra_add_doc_item(L, &doc_hydra_focushydra);
    hydra_add_doc_item(L, &doc_hydra_alert);
    hydra_add_doc_item(L, &doc_hydra_fileexists);
    hydra_add_doc_item(L, &doc_hydra_check_accessibility);
    
    luaL_newlib(L, hydralib);
    
    lua_pushstring(L, [[[NSBundle mainBundle] resourcePath] fileSystemRepresentation]);
    lua_setfield(L, -2, "resourcesdir");
    
    return 1;
}
