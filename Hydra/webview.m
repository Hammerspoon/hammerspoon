#import "helpers.h"
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
    "webview", "clicked", "webview.clicked = function(str)",
    "When a link is clicked with a URL like 'hydra:foo', this function is called (if set) with 'foo' as its argument."
};

static hydradoc doc_webview_closed = {
    "webview", "closed", "webview.closed = function()",
    "Called (if set) when the webview closes."
};

static int webview_open(lua_State* L) {
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
    "webview", "settitle", "webview:settitle(string)",
    "Set the title of a webview window."
};

static int webview_settitle(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    
    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    [[wc window] setTitle:title];
    
    return 0;
}

static hydradoc doc_webview_setlevel = {
    "webview", "setlevel", "webview:setlevel(level)",
    "When level is -1, window is always below all others; when 0, window is normal; when 1, window is above all others."
};

static int webview_setlevel(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    
    NSInteger level = lua_tonumber(L, 2);
    NSWindowCollectionBehavior coBehave = NSWindowAnimationBehaviorDefault;
    switch (level) {
        case -1: level = kCGDesktopIconWindowLevel + 1; coBehave = NSWindowCollectionBehaviorStationary; break;
        case  0: level = NSNormalWindowLevel; break;
        case  1: level = NSFloatingWindowLevel; break;
    }
    [[wc window] setLevel:level];
    [[wc window] setCollectionBehavior:coBehave];
    
    return 0;
}

static hydradoc doc_webview_sethasborder = {
    "webview", "sethasborder", "webview:sethasborder(bool)",
    "Set whether a webview window has a border."
};

static int webview_sethasborder(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL hasborder = lua_toboolean(L, 2);
    
    NSUInteger mask = [[wc window] styleMask];
    
    if (hasborder) mask = mask & NSBorderlessWindowMask;
    else mask = mask ^ NSBorderlessWindowMask;
    
    [[wc window] setStyleMask:mask];
    
    return 0;
}

static hydradoc doc_webview_sethasshadow = {
    "webview", "sethasshadow", "webview:sethasshadow(bool)",
    "Set whether a webview window has a shadow."
};

static int webview_sethasshadow(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL hasshadow = lua_toboolean(L, 2);
    
    [[wc window] setHasShadow:hasshadow];
    
    return 0;
}

static hydradoc doc_webview_loadstring = {
    "webview", "loadstring", "webview:loadstring(string, basepath)",
    "Loads the given string in the webview; basepath must be an absolute path."
};

static int webview_loadstring(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    NSString* string = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    NSString* basepath = [NSString stringWithUTF8String: lua_tostring(L, 3)];
    
    [[[wc webview] mainFrame] loadHTMLString:string baseURL:[NSURL fileURLWithPath:basepath]];
    
    return 0;
}

static hydradoc doc_webview_loadurl = {
    "webview", "loadurl", "webview:loadurl(url)",
    "Loads the given URL in the webview."
};

static int webview_loadurl(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    NSString* url = [NSString stringWithUTF8String: lua_tostring(L, 2)];
    
    [[wc webview] setMainFrameURL:url];
    
    return 0;
}

static hydradoc doc_webview_setignoresmouse = {
    "webview", "setignoresmouse", "webview:setignoresmouse(bool)",
    "Set whether a webview window can be interacted with via the mouse."
};

static int webview_setignoresmouse(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    BOOL ignoresmouse = lua_toboolean(L, 2);
    
    [[wc window] setIgnoresMouseEvents:ignoresmouse];
    [[wc window] setAcceptsMouseMovedEvents:!ignoresmouse];
    
    return 0;
}

static hydradoc doc_webview_window = {
    "webview", "window", "webview:window() -> window",
    "Return the window that represents the given webview."
};

static int webview_window(lua_State* L) {
    PHWebViewController* wc = get_window_controller(L, 1);
    new_window_for_nswindow(L, [wc window]);
    return 1;
}

static const luaL_Reg webviewlib[] = {
    {"_open", webview_open},
    {"settitle", webview_settitle},
    {"setlevel", webview_setlevel},
    {"sethasborder", webview_sethasborder},
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
    hydra_add_doc_item(L, &doc_webview_setlevel);
    hydra_add_doc_item(L, &doc_webview_sethasborder);
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
