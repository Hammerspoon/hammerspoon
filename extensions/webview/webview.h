// #define _WK_DEBUG
// #define _WK_DEBUG_TYPES

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG        "hs.webview"
#define USERDATA_UCC_TAG    "hs.webview.usercontent"

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
#define get_uccObjFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_UCC_TAG))

// @interface HSWebViewWindow : NSWindow <NSWindowDelegate>
@interface HSWebViewWindow : NSPanel <NSWindowDelegate>
@property HSWebViewWindow *parent ;
@property NSMutableArray  *children ;
@property int             udRef ;
@property int             hsDrawingUDRef ;
@property BOOL            allowKeyboardEntry ;
@property BOOL            titleFollow ;
@property BOOL            deleteOnClose ;
@property BOOL            closeOnEscape ;
@end

@interface HSWebViewView : WKWebView <WKNavigationDelegate, WKUIDelegate>
@property int          navigationCallback ;
@property int          policyCallback ;
@property BOOL         allowNewWindows ;
@property WKNavigation *trackingID ;
@end

@interface HSUserContentController : WKUserContentController <WKScriptMessageHandler>
@property NSString *name ;
@property int      userContentCallback ;
@property int      udRef ;
@end
