
// #pragma clang diagnostic push
// #pragma clang diagnostic ignored "-Wreserved-id-macro"
// #define _WK_DEBUG
// #pragma clang diagnostic pop

@import Cocoa ;
@import WebKit ;

@import LuaSkin ;

#define USERDATA_TAG     "hs.webview"
#define USERDATA_UCC_TAG "hs.webview.usercontent"
#define USERDATA_DS_TAG  "hs.webview.datastore"
#define USERDATA_TB_TAG  "hs.webview.toolbar"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

// @interface HSWebViewWindow : NSWindow <NSWindowDelegate>
@interface HSWebViewWindow : NSPanel <NSWindowDelegate>
@property HSWebViewWindow *parent ;
@property NSMutableArray  *children ;
@property int             udRef ;
@property int             windowCallback ;
@property BOOL            allowKeyboardEntry ;
@property BOOL            darkMode ;
@property BOOL            titleFollow ;
@property BOOL            deleteOnClose ;
@property BOOL            closeOnEscape ;
@property LSGCCanary          lsCanary ;
@end

@interface HSWebViewView : WKWebView <WKNavigationDelegate, WKUIDelegate>
@property int          navigationCallback ;
@property int          policyCallback ;
@property int          sslCallback ;
@property BOOL         allowNewWindows ;
@property BOOL         examineInvalidCertificates ;
@property WKNavigation *trackingID ;
@end

@interface HSUserContentController : WKUserContentController <WKScriptMessageHandler>
@property NSString *name ;
@property int      userContentCallback ;
@property int      udRef ;
@end
