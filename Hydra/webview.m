#import "helpers.h"
#import <WebKit/WebKit.h>

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



#define hydra_webview(L, idx) (__bridge PHWebViewController*)*((void**)luaL_checkudata(L, idx, "webview"))

static int webview_create(lua_State* L) {
    PHWebViewController* wc = [[PHWebViewController alloc] init];
    
    void** ptr = lua_newuserdata(L, sizeof(void*));
    *ptr = (__bridge_retained void*)wc;
    
    luaL_getmetatable(L, "webview");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_setuservalue(L, -2);
    
    return 1;
}

static void replace_webview_callback(lua_State* L, const char* key, int ref) {
    lua_getfield(L, -1, key);
    if (lua_isnumber(L, -1))
        luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, -1));
    lua_pop(L, 1);
    
    lua_pushnumber(L, ref);
    lua_setfield(L, -2, key);
}

static hydradoc doc_webview_clicked = {
    "webview", "clicked", "webview:clicked(fn(str))",
    "When a link is clicked with a URL like 'hydra:foo', the given function is called with 'foo' as its argument."
};

static int webview_clicked(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    luaL_checktype(L, LUA_REGISTRYINDEX, 2);
    
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_getuservalue(L, 1);
    replace_webview_callback(L, "clicked_ref", ref);
    
    wc.clicked = ^(NSString* tag) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pushstring(L, [tag UTF8String]);
        if (lua_pcall(L, 1, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

static hydradoc doc_webview_hidden = {
    "webview", "hidden", "webview:hidden(fn())",
    "Sets the callback for when the webview is hidden."
};

static int webview_hidden(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    luaL_checktype(L, LUA_REGISTRYINDEX, 2);
    
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lua_getuservalue(L, 1);
    replace_webview_callback(L, "hidden_ref", ref);
    
    wc.closed = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    };
    
    return 0;
}

static hydradoc doc_webview_show = {
    "webview", "show", "webview:show()",
    "Makes the webview not hidden."
};

static int webview_show(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    [[wc window] orderFront: nil];
    return 0;
}

static hydradoc doc_webview_hide = {
    "webview", "hide", "webview:hide()",
    "Makes the webview hidden."
};

static int webview_hide(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    [wc close];
    return 0;
}

static hydradoc doc_webview_settitle = {
    "webview", "settitle", "webview:settitle(string)",
    "Set the title of a webview window."
};

static int webview_settitle(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    [[wc window] setTitle: [NSString stringWithUTF8String: luaL_checkstring(L, 2)]];
    return 0;
}

static hydradoc doc_webview_setlevel = {
    "webview", "setlevel", "webview:setlevel(level)",
    "When level is -1, window is always below all others; when 0, window is normal; when 1, window is above all others."
};

static int webview_setlevel(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    NSInteger level = luaL_checknumber(L, 2);
    
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
    PHWebViewController* wc = hydra_webview(L, 1);
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
    PHWebViewController* wc = hydra_webview(L, 1);
    [[wc window] setHasShadow:lua_toboolean(L, 2)];
    return 0;
}

static hydradoc doc_webview_loadstring = {
    "webview", "loadstring", "webview:loadstring(string, basepath)",
    "Loads the given string in the webview; basepath must be an absolute path."
};

static int webview_loadstring(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    NSString* string = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    NSString* basepath = [NSString stringWithUTF8String: luaL_checkstring(L, 3)];
    [[[wc webview] mainFrame] loadHTMLString:string baseURL:[NSURL fileURLWithPath:basepath]];
    return 0;
}

static hydradoc doc_webview_loadurl = {
    "webview", "loadurl", "webview:loadurl(url)",
    "Loads the given URL in the webview."
};

static int webview_loadurl(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    NSString* url = [NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    [[wc webview] setMainFrameURL:url];
    return 0;
}

static hydradoc doc_webview_setignoresmouse = {
    "webview", "setignoresmouse", "webview:setignoresmouse(bool)",
    "Set whether a webview window can be interacted with via the mouse."
};

static int webview_setignoresmouse(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    BOOL ignoresmouse = lua_toboolean(L, 2);
    [[wc window] setIgnoresMouseEvents:ignoresmouse];
    [[wc window] setAcceptsMouseMovedEvents:!ignoresmouse];
    return 0;
}

static hydradoc doc_webview_id = {
    "webview", "id", "webview:id() -> number",
    "Return a unique identifier for the webview's window."
};

static int webview_id(lua_State* L) {
    PHWebViewController* wc = hydra_webview(L, 1);
    lua_pushnumber(L, [[wc window] windowNumber]);
    return 1;
}

static const luaL_Reg webviewlib[] = {
    {"_create", webview_create},
    
    // methods
    {"show", webview_show},
    {"hide", webview_hide},
    {"settitle", webview_settitle},
    {"setlevel", webview_setlevel},
    {"sethasborder", webview_sethasborder},
    {"sethasshadow", webview_sethasshadow},
    {"loadstring", webview_loadstring},
    {"loadurl", webview_loadurl},
    {"setignoresmouse", webview_setignoresmouse},
    {"id", webview_id},
    
    // callbacks
    {"clicked", webview_clicked},
    {"hidden", webview_hidden},
    
    {NULL, NULL}
};

int luaopen_webview(lua_State* L) {
    hydra_add_doc_group(L, "webview", "For showing stuff in web views!");
    hydra_add_doc_item(L, &doc_webview_show);
    hydra_add_doc_item(L, &doc_webview_hide);
    hydra_add_doc_item(L, &doc_webview_settitle);
    hydra_add_doc_item(L, &doc_webview_setlevel);
    hydra_add_doc_item(L, &doc_webview_sethasborder);
    hydra_add_doc_item(L, &doc_webview_sethasshadow);
    hydra_add_doc_item(L, &doc_webview_loadstring);
    hydra_add_doc_item(L, &doc_webview_loadurl);
    hydra_add_doc_item(L, &doc_webview_setignoresmouse);
    hydra_add_doc_item(L, &doc_webview_id);
    hydra_add_doc_item(L, &doc_webview_clicked);
    hydra_add_doc_item(L, &doc_webview_hidden);
    
    luaL_newlib(L, webviewlib);
    return 1;
}
