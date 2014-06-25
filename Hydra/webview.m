#import "hydra.h"
#import <WebKit/WebKit.h>
void new_window_for_nswindow(lua_State* L, NSWindow* win);

@interface PHWebViewController : NSWindowController <NSWindowDelegate>

@property IBOutlet WebView* webview;

@property (copy) void(^clicked)(NSString* str);
@property (copy) dispatch_block_t closed;

@end

@interface PHWebViewController ()
@end

@implementation PHWebViewController

- (NSString*) windowNibName { return @"webview"; }

- (void) windowWillClose:(NSNotification *)notification {
    
}

- (void) webView:(WebView *)webView
decidePolicyForNavigationAction:(NSDictionary *)info // lol apple
         request:(NSURLRequest *)request
           frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener
{
    if ([[info objectForKey:WebActionNavigationTypeKey] intValue] == WebNavigationTypeLinkClicked)
    {
        NSURL* url = [info objectForKey:WebActionOriginalURLKey];
        
        if ([[url scheme] isEqualToString: @"hydra"]) {
            NSString* str = [[url absoluteString] substringFromIndex:6];
            self.clicked(str);
            
            [listener ignore];
            return;
        }
    }
    [listener use];
}

@end

static hydradoc doc_webview_clicked = {
    "webview", "clicked", "api.webview.clicked = function(str)",
    "When a link is clicked with a URL like 'hydra:foo', this function is called (if set) with 'foo' as its argument."
};

static hydradoc doc_webview_closed = {
    "webview", "closed", "api.webview.closed = function()",
    "Called (if set) when the webview closes."
};

int webview_open(lua_State* L) {
    PHWebViewController* wc = [[PHWebViewController alloc] init];
    [wc showWindow: nil];
    
    lua_newtable(L);
    
    lua_pushvalue(L, -1);
    int tableref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    wc.clicked = ^(NSString* tag) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
        lua_getfield(L, -1, "clicked");
        lua_remove(L, -2);
        
        if (lua_isfunction(L, -1)) {
            lua_pushstring(L, [tag UTF8String]);
            if (lua_pcall(L, 1, 0, 0))
                hydra_handle_error(L);
        }
        else {
            lua_pop(L, 1);
        }
    };
    
    wc.closed = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
        lua_getfield(L, -1, "closed");
        
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0))
                hydra_handle_error(L);
            
            lua_pop(L, 1);
        }
        else {
            lua_pop(L, 2);
        }
        
        luaL_unref(L, LUA_REGISTRYINDEX, tableref);
    };
    
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

static hydradoc doc_webview_sethasshadow = {
    "webview", "sethasshadow", "api.webview:sethasshadow(bool)",
    "Set whether a webview window has a shadow."
};

int webview_sethasshadow(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL hasshadow = lua_toboolean(L, 2);
    
    [[wc window] setHasShadow:hasshadow];
    
    return 0;
}

static hydradoc doc_webview_loadstring = {
    "webview", "loadstring", "api.webview:loadstring(string, basepath)",
    "Loads the given string in the webview; basepath must be an absolute path."
};

int webview_loadstring(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    NSString* string = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    NSString* basepath = [NSString stringWithUTF8String: lua_tostring(L, 3)];
    
    [[[wc webview] mainFrame] loadHTMLString:string baseURL:[NSURL fileURLWithPath:basepath]];
    
    return 0;
}

static hydradoc doc_webview_loadurl = {
    "webview", "loadurl", "api.webview:loadurl(url)",
    "Loads the given URL in the webview."
};

int webview_loadurl(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    NSString* url = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    
    [[wc webview] setMainFrameURL:url];
    
    return 0;
}

static hydradoc doc_webview_setignoresmouse = {
    "webview", "setignoresmouse", "api.webview:setignoresmouse(bool)",
    "Set whether a webview window can be interacted with via the mouse."
};

int webview_setignoresmouse(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL ignoresmouse = lua_toboolean(L, 2);
    
    [[wc window] setIgnoresMouseEvents:ignoresmouse];
    [[wc window] setAcceptsMouseMovedEvents:!ignoresmouse];
    
    return 0;
}

static hydradoc doc_webview_window = {
    "webview", "window", "api.webview:window() -> window",
    "Return the api.window that represents the given webview."
};

int webview_window(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    new_window_for_nswindow(L, [wc window]);
    return 1;
}

static const luaL_Reg webviewlib[] = {
    {"_open", webview_open},
    {"settitle", webview_settitle},
    {"setborderless", webview_setborderless},
    {"sethasshadow", webview_sethasshadow},
    {"loadstring", webview_loadstring},
    {"loadurl", webview_loadurl},
    {"setignoresmouse", webview_setignoresmouse},
    {"window", webview_window},
    {NULL, NULL}
};

int luaopen_webview(lua_State* L) {
    hydra_add_doc_group(L, "webview", "For showing stuff in web views!");
    hydra_add_doc_item(L, &doc_webview_settitle);
    hydra_add_doc_item(L, &doc_webview_setborderless);
    hydra_add_doc_item(L, &doc_webview_sethasshadow);
    hydra_add_doc_item(L, &doc_webview_loadstring);
    hydra_add_doc_item(L, &doc_webview_loadurl);
    hydra_add_doc_item(L, &doc_webview_setignoresmouse);
    hydra_add_doc_item(L, &doc_webview_clicked);
    hydra_add_doc_item(L, &doc_webview_closed);
    hydra_add_doc_item(L, &doc_webview_window);
    
    luaL_newlib(L, webviewlib);
    return 1;
}
