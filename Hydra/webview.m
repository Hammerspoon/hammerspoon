#import "hydra.h"
#import "PHWebViewController.h"

int webview_open(lua_State* L) {
    PHWebViewController* wc = [[PHWebViewController alloc] init];
    [wc showWindow: nil];
    
    lua_newtable(L);
    
    lua_pushlightuserdata(L, (__bridge_retained void*)wc);
    lua_setfield(L, -2, "__wc");
    
    return 1;
}

static PHWebViewController* get_window_controller(lua_State* L, int idx) {
    lua_getfield(L, idx, "__wc");
    PHWebViewController* wc = (__bridge id)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return wc;
}

static hydradoc doc_webview_settitle = {
    "webview", "settitle", "api.webview:settitle(string)",
    "Set the title of a webview window."
};

int webview_settitle(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

static hydradoc doc_webview_setborderless = {
    "webview", "setborderless", "api.webview:setborderless(bool)",
    "Set whether a webview window has a border."
};

int webview_setborderless(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL hasborder = lua_toboolean(L, 2);
    
    NSUInteger mask = [[wc window] styleMask];
    
    if (hasborder) mask = mask & NSBorderlessWindowMask;
    else mask = mask ^ NSBorderlessWindowMask;
    
    [[wc window] setStyleMask:mask];
    
    return 0;
}

static hydradoc doc_webview_loadstring = {
    "webview", "loadfile", "api.webview:loadfile(path)",
    "Loads the given file in the webview; must be an absolute path."
};

int webview_loadstring(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    NSString* string = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    NSString* basepath = [NSString stringWithUTF8String: lua_tostring(L, 3)];
    
    [[[wc webview] mainFrame] loadHTMLString:string baseURL:[NSURL fileURLWithPath:basepath]];
    
    return 0;
}

static const luaL_Reg webviewlib[] = {
    {"_open", webview_open},
    {"settitle", webview_settitle},
    {"setborderless", webview_setborderless},
    {"loadstring", webview_loadstring},
    {NULL, NULL}
};

int luaopen_webview(lua_State* L) {
    hydra_add_doc_group(L, "webview", "For showing stuff in web views!");
    hydra_add_doc_item(L, &doc_webview_settitle);
    hydra_add_doc_item(L, &doc_webview_setborderless);
    hydra_add_doc_item(L, &doc_webview_loadstring);
    
    luaL_newlib(L, webviewlib);
    return 1;
}
