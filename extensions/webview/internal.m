// #define _WV_DEBUG

// Need to delve deeper into NSURL and see what else we might want to include in callback/history list/url method
// can we choose native viewer over plugin (e.g. not use Adobe for PDF)?

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG        "hs.webview"
int refTable ;

static WKProcessPool *HSWebViewProcessPool ;

// #define get_objectFromUserdata(objType, L, idx) (__bridge objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

// typedef struct _webview_t {
//     void *window;
// } webview_t;

#pragma mark - Classes and Delegates

@interface HSWebViewWindow : NSWindow <NSWindowDelegate>
@property BOOL allowKeyboardEntry ;
@end

@interface HSWebViewView : WKWebView <WKNavigationDelegate, WKUIDelegate>
#ifdef _WV_DEBUG
@property BOOL barfToConsole ;
#endif
@property int navigationCallback ;
@property int policyCallback ;
// @property BOOL allowMouseClicks ;
// @property BOOL allowContextMenu ;
@end

@implementation HSWebViewWindow
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation {

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        [self setDelegate:self];
        contentRect.origin.y=[[NSScreen screens][0] frame].size.height - contentRect.origin.y - contentRect.size.height;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor = [NSColor whiteColor];
        self.opaque = YES;
        self.hasShadow = NO;
        self.ignoresMouseEvents = NO;
        self.allowKeyboardEntry = NO ;
        self.restorable = NO;
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        self.level = NSNormalWindowLevel;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return self.allowKeyboardEntry ;
}

// NSWindowDelegate method. We decline to close the window because we don't want external things interfering with the user's decisions to display these objects.
- (BOOL)windowShouldClose:(id __unused)sender {
    if ((self.styleMask & NSClosableWindowMask) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}
@end

@implementation HSWebViewView
- (id)initWithFrame:(NSRect)frameRect configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frameRect configuration:configuration] ;
    if (self) {
        self.navigationDelegate = self ;
        self.UIDelegate = self ;
#ifdef _WV_DEBUG
        self.barfToConsole = NO ;
#endif
        self.navigationCallback = LUA_NOREF ;
        self.policyCallback = LUA_NOREF ;
//         self.allowMouseClicks = YES ;
//         self.allowContextMenu = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    return YES ;
}

// - (void)mouseDown:(NSEvent *)theEvent {
//     if (self.allowMouseClicks) [super mouseDown:theEvent] ;
// }
//
// - (void)rightMouseDown:(NSEvent *)theEvent {
//     if (self.allowMouseClicks && self.allowContextMenu) [super rightMouseDown:theEvent] ;
// }

#pragma mark - WKNavigationDelegate stuff

- (void)webView:(WKWebView *)theView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didReceiveServerRedirectForProvisionalNavigation" forView:theView
                                                                            withNavigation:navigation
                                                                                 withError:nil] ;
}

- (void)webView:(WKWebView *)theView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didStartProvisionalNavigation" forView:theView
                                                         withNavigation:navigation
                                                              withError:nil] ;
}

- (void)webView:(WKWebView *)theView didCommitNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didCommitNavigation" forView:theView
                                               withNavigation:navigation
                                                    withError:nil] ;
}

- (void)webView:(WKWebView *)theView didFinishNavigation:(WKNavigation *)navigation {
    [self navigationCallbackFor:"didFinishNavigation" forView:theView
                                               withNavigation:navigation
                                                    withError:nil] ;
}

- (void)webView:(WKWebView *)theView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailNavigation" forView:theView
                                                 withNavigation:navigation
                                                      withError:error]) {
        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailProvisionalNavigation" forView:theView
                                                            withNavigation:navigation
                                                                 withError:error]) {
        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                                                     completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
// TODO: need to cache credentials and try them before prompting each time
//       callback to get username and password?
//       can we get user and password in same dialog?

#ifdef _WV_DEBUG
if (self.barfToConsole) {
        lua_getglobal([[LuaSkin shared] L], "print") ;
        lua_pushstring([[LuaSkin shared] L], "didReceiveAuthenticationChallenge") ;
        [[LuaSkin shared] pushNSObject:theView] ;
        [[LuaSkin shared] pushNSObject:challenge] ;
        lua_pcall([[LuaSkin shared] L], 3, 0, 0) ;
    }
#endif

    NSString *hostName = theView.URL.host;

    NSString *authenticationMethod = [[challenge protectionSpace] authenticationMethod];
    if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest]) {

        NSString *title = @"Authentication Challenge";

        NSAlert *alert1 = [[NSAlert alloc] init] ;
        [alert1 addButtonWithTitle:@"OK"];
        [alert1 addButtonWithTitle:@"Cancel"];
        [alert1 setMessageText:title] ;
        [alert1 setInformativeText:[NSString stringWithFormat:@"Username for %@", hostName]] ;
        NSTextField *user = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] ;
        user.editable = YES ;
        [alert1 setAccessoryView:user] ;

        [alert1 beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode){
            if (returnCode == NSAlertFirstButtonReturn) {
                NSAlert *alert2 = [[NSAlert alloc] init] ;
                [alert2 addButtonWithTitle:@"OK"];
                [alert2 addButtonWithTitle:@"Cancel"];
                [alert2 setMessageText:title] ;
                [alert2 setInformativeText:[NSString stringWithFormat:@"password for %@", hostName]] ;
                NSSecureTextField *pass = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 36, 200, 24)];
                pass.editable = YES ;
                [alert2 setAccessoryView:pass] ;
                [alert2 beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode){
                    if (returnCode == NSAlertFirstButtonReturn) {
                        NSString *userName = user.stringValue ;
                        NSString *password = pass.stringValue ;

                        NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName
                                                                                   password:password
                                                                                persistence:NSURLCredentialPersistenceNone];

                        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);

                    } else {
                        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                    }
                }] ;
            } else {
                completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            }
        }] ;
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                                             decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
#ifdef _WV_DEBUG
    if (self.barfToConsole) {
        lua_getglobal([[LuaSkin shared] L], "print") ;
        lua_pushstring([[LuaSkin shared] L], "decidePolicyForNavigationAction") ;
        [[LuaSkin shared] pushNSObject:theView] ;
        [[LuaSkin shared] pushNSObject:navigationAction] ;
        lua_pcall([[LuaSkin shared] L], 3, 0, 0) ;
    }
#endif

    decisionHandler(WKNavigationActionPolicyAllow) ;

    // WKNavigationActionPolicy
    // The policy to pass back to the decision handler from the webView:decidePolicyForNavigationAction:decisionHandler: method.
    // typedef enum WKNavigationActionPolicy : NSInteger {
    //    WKNavigationActionPolicyCancel,
    //    WKNavigationActionPolicyAllow,
    // } WKNavigationActionPolicy;
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                                                               decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
#ifdef _WV_DEBUG
    if (self.barfToConsole) {
        lua_getglobal([[LuaSkin shared] L], "print") ;
        lua_pushstring([[LuaSkin shared] L], "decidePolicyForNavigationResponse") ;
        [[LuaSkin shared] pushNSObject:theView] ;
        [[LuaSkin shared] pushNSObject:navigationResponse] ;
        lua_pcall([[LuaSkin shared] L], 3, 0, 0) ;
    }
#endif

    decisionHandler(WKNavigationResponsePolicyAllow) ;

    // WKNavigationResponsePolicy
    // The policy to pass back to the decision handler from the webView:decidePolicyForNavigationResponse:decisionHandler: method.
    // typedef enum WKNavigationResponsePolicy : NSInteger {
    //    WKNavigationResponsePolicyCancel,
    //    WKNavigationResponsePolicyAllow,
    // } WKNavigationResponsePolicy;
}

#pragma mark - WKUIDelegate stuff

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                                                       forNavigationAction:(WKNavigationAction *)navigationAction
                                                            windowFeatures:(WKWindowFeatures *)windowFeatures {
#ifdef _WV_DEBUG
    if (self.barfToConsole) {
        lua_getglobal([[LuaSkin shared] L], "print") ;
        lua_pushstring([[LuaSkin shared] L], "WKUIDelegate createWebView:") ;
        [[LuaSkin shared] pushNSObject:webView] ;
        [[LuaSkin shared] pushNSObject:configuration] ;
        [[LuaSkin shared] pushNSObject:navigationAction] ;
        [[LuaSkin shared] pushNSObject:windowFeatures] ;
        lua_pcall([[LuaSkin shared] L], 5, 0, 0) ;
    }
#endif

    return nil ;
}

- (void)webView:(WKWebView *)theView runJavaScriptAlertPanelWithMessage:(NSString *)message
                                                       initiatedByFrame:(WKFrameInfo *)frame
                                                      completionHandler:(void (^)())completionHandler {
    NSAlert *alertPanel = [[NSAlert alloc] init] ;
    [alertPanel addButtonWithTitle:@"OK"];
    [alertPanel setMessageText:[NSString stringWithFormat:@"JavaScript Alert for %@", frame.request.URL.host]] ;
    [alertPanel setInformativeText:message] ;

    [alertPanel beginSheetModalForWindow:theView.window completionHandler:^(__unused NSModalResponse returnCode){
        completionHandler() ;
    }] ;
}

- (void)webView:(WKWebView *)theView runJavaScriptConfirmPanelWithMessage:(NSString *)message
                                                         initiatedByFrame:(WKFrameInfo *)frame
                                                        completionHandler:(void (^)(BOOL result))completionHandler{
    NSAlert *confirmPanel = [[NSAlert alloc] init] ;
    [confirmPanel addButtonWithTitle:@"OK"] ;
    [confirmPanel addButtonWithTitle:@"Cancel"] ;
    [confirmPanel setMessageText:[NSString stringWithFormat:@"JavaScript Confirm for %@", frame.request.URL.host]] ;
    [confirmPanel setInformativeText:message] ;

    [confirmPanel beginSheetModalForWindow:theView.window completionHandler:^(NSModalResponse returnCode){
        completionHandler((returnCode == NSAlertFirstButtonReturn) ? YES : NO) ;
    }] ;
}


- (void)webView:(WKWebView *)theView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                                                               defaultText:(NSString *)defaultText
                                                          initiatedByFrame:(WKFrameInfo *)frame
                                                         completionHandler:(void (^)(NSString *result))completionHandler{
    NSAlert *inputPanel = [[NSAlert alloc] init] ;
    [inputPanel addButtonWithTitle:@"OK"] ;
    [inputPanel addButtonWithTitle:@"Cancel"] ;
    [inputPanel setMessageText:[NSString stringWithFormat:@"JavaScript Input for %@", frame.request.URL.host]] ;
    [inputPanel setInformativeText:prompt] ;
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] ;
    input.stringValue = defaultText ;
    input.editable = YES ;
    [inputPanel setAccessoryView:input] ;

    [inputPanel beginSheetModalForWindow:theView.window completionHandler:^(NSModalResponse returnCode){
        if (returnCode == NSAlertFirstButtonReturn)
            completionHandler(input.stringValue) ;
        else
            completionHandler(nil) ;
    }] ;
}

#pragma mark - Helper methods to reduce code replication

- (void)handleNavigationFailure:(NSError *)error forView:(WKWebView *)theView {
// TODO: Really need to figure out how NSErrorRecoveryAttempting works so self-signed certs don't have to be pre-approved via Safari

    NSMutableString *theErrorPage = [[NSMutableString alloc] init] ;
    [theErrorPage appendFormat:@"<html><head><title>Webview Error %ld</title></head><body>"
                                "<b>An Error code: %ld in %@ occurred during navigation:</b><br>"
                                "<hr>", (long)error.code, (long)error.code, error.domain] ;

    if (error.localizedDescription)   [theErrorPage appendFormat:@"<i>Description:</i> %@<br>", error.localizedDescription] ;
    if (error.localizedFailureReason) [theErrorPage appendFormat:@"<i>Reason:</i> %@<br>", error.localizedFailureReason] ;
    [theErrorPage appendFormat:@"</body></html>"] ;

    [theView loadHTMLString:theErrorPage baseURL:nil] ;
}


- (BOOL)navigationCallbackFor:(const char *)action forView:(WKWebView *)theView
                                            withNavigation:(WKNavigation *)navigation
                                                 withError:(NSError *)error {
#ifdef _WV_DEBUG
    if (self.barfToConsole) {
        lua_getglobal([[LuaSkin shared] L], "print") ;
        lua_pushstring([[LuaSkin shared] L], action) ;
        [[LuaSkin shared] pushNSObject:theView] ;
        [[LuaSkin shared] pushNSObject:navigation] ;
        if (!error) {
            lua_pcall([[LuaSkin shared] L], 3, 0, 0) ;
        } else {
            [[LuaSkin shared] pushNSObject:error] ;
            lua_pcall([[LuaSkin shared] L], 4, 0, 0) ;
        }
    }
#endif

    BOOL actionRequiredAfterReturn = YES ;

    if (self.navigationCallback != LUA_NOREF) {
        lua_State *L = [[LuaSkin shared] L];

        int numberOfArguments = 3 ;

        [[LuaSkin shared] pushLuaRef:refTable ref:self.navigationCallback];

        lua_pushstring(L, action) ;

//         [[LuaSkin shared] pushNSObject:[theView URL]] ;
        size_t size = [[[theView URL] description] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
        lua_pushlstring(L, [[[theView URL] description] UTF8String], size) ;

        lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", navigation] UTF8String]) ;

        if (error) {
            numberOfArguments++ ;
            lua_newtable(L) ;
                lua_pushinteger(L, (lua_Integer)error.code) ; lua_setfield(L, -2, "code") ;
                size = [[error domain] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(L, [[error domain] UTF8String], size) ; lua_setfield(L, -2, "domain") ;
                size = [[error localizedDescription] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(L, [[error localizedDescription] UTF8String], size) ; lua_setfield(L, -2, "description") ;
                size = [[error localizedFailureReason] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(L, [[error localizedFailureReason] UTF8String], size) ; lua_setfield(L, -2, "reason") ;
        }

        if (![[LuaSkin shared]  protectedCallAndTraceback:numberOfArguments nresults:1]) {
            const char *errorMsg = lua_tostring(L, -1);
            CLS_NSLOG(@"%s", errorMsg);
            showError(L, (char *)errorMsg);
        } else {
            if (error) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    lua_getglobal(L, "hs") ; lua_getfield(L, -1, "cleanUTF8forConsole") ;
                    lua_pushvalue(L, -3) ;
                    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
                        showError(L, (char *)[[NSString stringWithFormat:@"unable to validate HTML: %s", lua_tostring(L, -1)] UTF8String]);
                    } else {
                    //     NSString *theHTML = [[LuaSkin shared] toNSObjectAtIndex:-1] ;
                        size_t size ;
                        unsigned char *string = (unsigned char *)lua_tolstring(L, -1, &size) ;
                        NSString *theHTML = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size]
                                                                  encoding:NSUTF8StringEncoding] ;
                        lua_pop(L, 2) ; // remove "hs" and the return value

                        [theView loadHTMLString:theHTML baseURL:nil] ;
                        actionRequiredAfterReturn = NO ;
                    }
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) {
                    actionRequiredAfterReturn = NO ;
                }
            }
        }
    }

    return actionRequiredAfterReturn ;
}

@end


// @interface WKPreferences (WKPrivate)
// @property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
// @end

// Yeah, I know the distinction is a little blurry and arbitrary, but it helps my thinking.
#pragma mark - WKWebView Related Methods

/// hs.webview:url([URL]) -> webviewObject, navigationIdentifier | url
/// Method
/// Get or set the URL to render for the webview.
///
/// Parameters:
///  * URL - an optional string representing the URL to display.
///
/// Returns:
///  * If a URL is specified, then this method returns the webview Object and a navigation identifier; otherwise it returns the current url being displayed.
///
/// Notes:
///  * The navigation identifier can be used to track a web request as it is processed and loaded by using the `hs.webview:navigationCallback` method.
static int webview_url(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
//         [[LuaSkin shared] pushNSObject:[theView URL]] ;
        size_t size = [[[theView URL] description] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
        lua_pushlstring(L, [[[theView URL] description] UTF8String], size) ;
        return 1 ;
    } else {
//         NSString *theURL = [[LuaSkin shared] toNSObjectAtIndex:2] ;
        size_t size ;
        unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
        NSString *theURL = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;

        if (theURL) {
            WKNavigation *navID = [theView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:theURL]]] ;
            lua_pushvalue(L, 1) ;
            lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", navID] UTF8String]) ;
            return 2 ;
        } else {
            return luaL_error(L, "Invalid URL type.  String expected.") ;
        }
    }
}

/// hs.webview:title() -> title
/// Method
/// Get the title of the page displayed in the webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the title
///
/// Notes:
///  * This method can be used with `hs.webview:windowTitle` to set the window title if the window style is titled.  E.g. `hs.webview:windowTitle(hs.webview:title())`
static int webview_title(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

//         [[LuaSkin shared] pushNSObject:[theView title]] ;
    size_t size = [[theView title] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
    lua_pushlstring(L, [[theView title] UTF8String], size) ;

    return 1 ;
}

/// hs.webview:loading() -> boolean
/// Method
/// Returns a boolean value indicating whether or not the vebview is still loading content.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the content is still being loaded, or false if it has completed.
static int webview_loading(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushboolean(L, [theView isLoading]) ;

    return 1 ;
}

/// hs.webview:stopLoading() -> webviewObject
/// Method
/// Stop loading content if the webview is still loading content.  Does nothing if content has already completed loading.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_stopLoading(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [theView stopLoading] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:estimatedProgress() -> number
/// Method
/// Returns the estimated percentage of expected content that has been loaded.  Will equal 1.0 when all content has been loaded.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a numerical value between 0.0 and 1.0 indicating the percentage of expected content which has been loaded.
static int webview_estimatedProgress(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushnumber(L, [theView estimatedProgress]) ;

    return 1 ;
}

/// hs.webview:isOnlySecureContent() -> bool
/// Method
/// Returns a boolean value indicating if all content current displayed in the webview was loaded over securely encrypted connections.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if all content current displayed in the web view was loaded over securely encrypted connections; otherwise false.
static int webview_isOnlySecureContent(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushboolean(L, [theView hasOnlySecureContent]) ;

    return 1 ;
}

/// hs.webview:goForward() -> webviewObject
/// Method
/// Move to the next page in the webview's history, if possible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview Object
static int webview_goForward(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goForward:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:goBack() -> webviewObject
/// Method
/// Move to the previous page in the webview's history, if possible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview Object
static int webview_goBack(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goBack:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:reload([validate]) -> webviewObject, navigationIdentifier
/// Method
/// Reload the page in the webview, optionally performing end-to-end revalidation using cache-validating conditionals if possible.
///
/// Parameters:
///  * validate - an optional boolean indicating whether or not an attempt to perform end-to-end revalidation of cached data should be performed.  Defaults to false.
///
/// Returns:
///  * The webview Object and a navigation identifier
///
/// Notes:
///  * The navigation identifier can be used to track a web request as it is processed and loaded by using the `hs.webview:navigationCallback` method.
static int webview_reload(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    WKNavigation *navID ;
    if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2))
        navID = [theView reload] ;
    else
        navID = [theView reloadFromOrigin] ;

    lua_pushvalue(L, 1) ;
    lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", navID] UTF8String]) ;
    return 2 ;
}

/// hs.webview:allowMagnificationGestures([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview will respond to magnification gestures from a trackpad or magic mouse.  Default is false.
///
/// Parameters:
///  * value - an optional boolean value indicating whether or not the webview should respond to magnification gestures.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowMagnificationGestures(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [theView allowsMagnification]) ;
    } else {
        [theView setAllowsMagnification:(BOOL)lua_toboolean(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:allowNavigationGestures([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview will respond to the navigation gestures from a trackpad or magic mouse.  Default is false.
///
/// Parameters:
///  * value - an optional boolean value indicating whether or not the webview should respond to navigation gestures.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowNavigationGestures(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, [theView allowsBackForwardNavigationGestures]) ;
    } else {
        [theView setAllowsBackForwardNavigationGestures:(BOOL)lua_toboolean(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:magnification([value]) -> webviewObject | current value
/// Method
/// Get or set the webviews current magnification level. Default is 1.0.
///
/// Parameters:
///  * value - an optional number specifying the webviews magnification level.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_magnification(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushnumber(L, [theView magnification]) ;
    } else {
        luaL_checktype(L, 2, LUA_TNUMBER) ;
        NSPoint centerOn ;

// Center point doesn't seem to do anything... will investigate further later...
//         if (lua_type(L, 3) == LUA_TTABLE) {
// //             centerOn = [[LuaSkin shared] tableToPointAtIndex:3] ;
//             CGFloat x = (lua_getfield(L, 3, "x"), luaL_checknumber(L, -1));
//             CGFloat y = (lua_getfield(L, 3, "y"), luaL_checknumber(L, -1));
//             lua_pop(L, 2);
//             centerOn = NSMakePoint(x, y);
//         } else if (lua_type(L, 3) != LUA_TNONE) {
//             return luaL_error(L, "invalid type specified for magnification center: %s", lua_typename(L, lua_type(L, 3))) ;
//         }

        [theView setMagnification:lua_tonumber(L, 2) centeredAtPoint:centerOn] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:html(html,[baseURL]) -> webviewObject, navigationIdentifier
/// Method
/// Render the given HTML in the webview with an optional base URL for relative links.
///
/// Parameters:
///  * html    - the html to be rendered in the webview
///  * baseURL - an optional Base URL to use as the starting point for any relative links within the provided html.
///
/// Returns:
///  * The webview Object and a navigation identifier
///
/// Notes:
///  * This method runs the html through `hs.cleanUTF8forConsole` to ensure that the data provided is displayable.
///  * Web Pages generated in this manner are not added to the webview history list
///  * The navigation identifier can be used to track a web request as it is processed and loaded by using the `hs.webview:navigationCallback` method.
static int webview_html(lua_State *L) {
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;

    luaL_checkstring(L, 2) ;

    lua_getglobal(L, "hs") ; lua_getfield(L, -1, "cleanUTF8forConsole") ;
    lua_pushvalue(L, 2) ;
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        return luaL_error(L, "unable to validate HTML: %s", lua_tostring(L, -1)) ;
    }
//     NSString *theHTML = [[LuaSkin shared] toNSObjectAtIndex:-1] ;
    size_t size ;
    unsigned char *string = (unsigned char *)lua_tolstring(L, -1, &size) ;
    NSString *theHTML = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
    lua_pop(L, 2) ; // remove "hs" and the return value

    NSString *theBaseURL ;
    if (lua_type(L, 3) == LUA_TSTRING) {
//       theBaseURL = [[LuaSkin shared] toNSObjectAtIndex:2] ;
      size_t size ;
      unsigned char *string = (unsigned char *)lua_tolstring(L, 3, &size) ;
      theBaseURL = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
    } else if (lua_type(L, 3) != LUA_TNONE) {
        return luaL_error(L, "baseURL should be string or none: found %s",lua_typename(L, lua_type(L, 3))) ;
    }

    WKNavigation *navID = [theView loadHTMLString:theHTML baseURL:[NSURL URLWithString:theBaseURL]] ;

    lua_pushvalue(L, 1) ; // strictly not necessary here, but it makes it clearer what we're returning
    lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", navID] UTF8String]) ;
    return 2 ;
}

/// hs.webview:navigationCallback(fn) -> webviewObject
/// Method
/// Sets a callback for tracking a webview's navigation process.
///
/// Parameters:
///  * fn - the function to be called when the navigation status of a webview cahnges.  To disable the callback function, explicitly specify nil.  The function should expect 3 or 4 arguments and may optionally return 1.  The function arguments are defined as follows:
///    * action - a string indicating the webview's current status.  It will be one of the following:
///      * didStartProvisionalNavigation                    - a request or action to change the contents of the main frame has occurred
///      * didReceiveServerRedirectForProvisionalNavigation - a server redirect was received for the main frame
///      * didCommitNavigation                              - content has started arriving for the main frame
///      * didFinishNavigation                              - the webview's main frame has completed loading.
///      * didFailNavigation                                - an error has occurred after content started arriving
///      * didFailProvisionalNavigation                     - an error has occurred as or before content has started arriving
///    * url    - the current url for the webview
///    * navID  - a navigationIdentifier which can be used to link this event back to a specific request made by a `hs.webview:url`, `hs.webview:html`, or `hs.webview:reload` method.
///    * error  - a table which will only be provided when `action` is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If provided, it will contain at leas some of the following keys:
///      * code        - a numerical value indicating the type of error code.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * domain      - a string indcating the error domain of the error.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * description - a string describing the condition or problem that has occurred.
///      * reason      - if available, more information about what may have caused the problem to occur.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * The return value of the callback function is ignored except when the `action` argument is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If the return value when the action argument is one of these values is a string, it will be treated as html and displayed in the webview.  If the return value is the boolean value true, then no change will be made to the webview (it will continue to display the previous web page).  All other return values, or no return value at all, will cause a default error page to be displayed in the webview.
static int webview_navigationCallback(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNIL || lua_type(L, 2) == LUA_TFUNCTION) {
        // We're either removing a callback, or setting a new one. Either way, we want to make clear out any callback that exists
        if (theView.navigationCallback != LUA_NOREF) {
            theView.navigationCallback = [[LuaSkin shared] luaUnref:refTable ref:theView.navigationCallback] ;
        }

        // Set a new callback if we have a function
        if (lua_type(L, 2) == LUA_TFUNCTION) {
            lua_pushvalue(L, 2);
            theView.navigationCallback = [[LuaSkin shared] luaRef:refTable] ;
        }
    } else {
        return luaL_error(L, ":navigationCallback() expected function or nil, not %s", lua_typename(L, lua_type(L, 2)));
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int fn_pushWKBackForwardListItem(lua_State *L, WKBackForwardListItem *theItem) {
    size_t size ;

    lua_newtable(L) ;
//       [[LuaSkin shared] pushNSObject:[theItem URL]] ;
      size = [[[theItem URL] description] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
      lua_pushlstring(L, [[[theItem URL] description] UTF8String], size) ;
      lua_setfield(L, -2, "URL") ;

//       [[LuaSkin shared] pushNSObject:[theItem initialURL]] ;
      size = [[[theItem initialURL] description] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
      lua_pushlstring(L, [[[theItem initialURL] description] UTF8String], size) ;
      lua_setfield(L, -2, "initialURL") ;

//       [[LuaSkin shared] pushNSObject:[theItem title]] ;
      size = [[theItem title] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
      lua_pushlstring(L, [[theItem title] UTF8String], size) ;
      lua_setfield(L, -2, "title") ;

    return 1 ;
}

/// hs.webview:historyList() -> historyTable
/// Method
/// Returns the URL history for the current webview as an array.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table which is an array of the URLs viewed within this webview and a key named `current` which is equal to the index corresponding to the currently visible entry.  Each array element will be a table with the following keys:
///    * URL        - the URL of the web page
///    * initialURL - the URL of the initial request that led to this item
///    * title      - the web page title
static int webview_historyList(lua_State *L) {
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;

    lua_newtable(L) ;

    WKBackForwardList *theList = [theView backForwardList] ;
    if (theList) {
        NSArray *previousList = [theList backList] ;
        NSArray *nextList = [theList forwardList] ;

        for(id value in previousList) {
            // [[LuaSkin shared] pushNSObject:value] ;
            fn_pushWKBackForwardListItem(L, value) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        // [[LuaSkin shared] pushNSObject:[theList currentItem]] ;
        if ([theList currentItem]) {
            fn_pushWKBackForwardListItem(L, [theList currentItem]) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_pushinteger(L, luaL_len(L, -1)) ; lua_setfield(L, -2, "current") ;

        for(id value in nextList) {
            // [[LuaSkin shared] pushNSObject:value] ;
            fn_pushWKBackForwardListItem(L, value) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        lua_pushinteger(L, 0) ; lua_setfield(L, -2, "current") ;
    }
    return 1 ;
}

#ifdef _WV_DEBUG
static int webview_verbose(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.barfToConsole) ;
    } else {
        theView.barfToConsole = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

static int webview_preferences(lua_State *L) {
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;
    WKWebViewConfiguration *theConfiguration = [theView configuration] ;
    WKPreferences          *thePreferences = [theConfiguration preferences] ;

    lua_newtable(L) ;
        lua_pushnumber(L, [thePreferences minimumFontSize]) ;                        lua_setfield(L, -2, "minimumFontSize") ;
        lua_pushboolean(L, [thePreferences javaEnabled]) ;                           lua_setfield(L, -2, "javaEnabled") ;
        lua_pushboolean(L, [thePreferences javaScriptEnabled]) ;                     lua_setfield(L, -2, "javaScriptEnabled") ;
        lua_pushboolean(L, [thePreferences plugInsEnabled]) ;                        lua_setfield(L, -2, "plugInsEnabled") ;
        lua_pushboolean(L, [thePreferences javaScriptCanOpenWindowsAutomatically]) ; lua_setfield(L, -2, "javaScriptCanOpenWindowsAutomatically") ;
        lua_pushboolean(L, [theConfiguration suppressesIncrementalRendering]) ;      lua_setfield(L, -2, "suppressesIncrementalRendering") ;
    return 1 ;
}
#endif

#pragma mark - Window Related Methods

/// hs.webview.new(rect, [preferencesTable]) -> webviewObject
/// Constructor
/// Create a webviewObject and optionally modify its preferences.
///
/// Parameters:
///  * rect - a rectangle specifying where the webviewObject should be displayed.
///  * preferencesTable - an optional table which can include one of more of the following keys:
///   * javaEnabled                           - java is enabled (default false)
///   * javaScriptEnabled                     - javascript is enabled (default true)
///   * javaScriptCanOpenWindowsAutomatically - can javascript open windows without user intervention (default true)
///   * minimumFontSize                       - minimum font size (default 0.0)
///   * plugInsEnabled                        - plug-ins are enabled (default false)
///   * developerExtrasEnabled                - include "Inspect Element" in the context menu
///   * suppressesIncrementalRendering        - suppresses content rendering until fully loaded into memory (default false)
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * To set the initial URL, use the `hs.webview:url` method before showing the webview object.
///  * Preferences can only be set when the webview object is created.  To change the preferences of an open webview, you will need to close it and recreate it with this method.
///  * developerExtrasEnabled is not listed in Apple's documentation, but is included in the WebKit2 documentation.
static int webview_new(lua_State *L) {

    if (lua_type(L, 2) != LUA_TNONE) {
        luaL_checktype(L, 2, LUA_TTABLE) ;
    }

//     NSRect windowRect = [[LuaSkin shared] tableToRectAtIndex:1] ;
    luaL_checktype(L, 1, LUA_TTABLE);
    CGFloat x = (lua_getfield(L, 1, "x") != LUA_TNIL) ? luaL_checknumber(L, -1) : 0.0 ;
    CGFloat y = (lua_getfield(L, 1, "y") != LUA_TNIL) ? luaL_checknumber(L, -1) : 0.0 ;
    CGFloat w = (lua_getfield(L, 1, "w") != LUA_TNIL) ? luaL_checknumber(L, -1) : 0.0 ;
    CGFloat h = (lua_getfield(L, 1, "h") != LUA_TNIL) ? luaL_checknumber(L, -1) : 0.0 ;
    lua_pop(L, 4);
    NSRect windowRect = NSMakeRect(x, y, w, h);

    HSWebViewWindow *theWindow = [[HSWebViewWindow alloc] initWithContentRect:windowRect
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:YES];

    if (theWindow) {
        void** windowPtr = lua_newuserdata(L, sizeof(HSWebViewWindow *));
        *windowPtr = (__bridge_retained void *)theWindow ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        if (!HSWebViewProcessPool) HSWebViewProcessPool = [[WKProcessPool alloc] init] ;
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init] ;
        config.processPool = HSWebViewProcessPool ;

        if (lua_type(L, 2) == LUA_TTABLE) {
            WKPreferences *myPreferences = [[WKPreferences alloc] init] ;

            if (lua_getfield(L, 2, "javaEnabled") == LUA_TBOOLEAN)
                myPreferences.javaEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "javaScriptEnabled") == LUA_TBOOLEAN)
                myPreferences.javaScriptEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "javaScriptCanOpenWindowsAutomatically") == LUA_TBOOLEAN)
                myPreferences.javaScriptCanOpenWindowsAutomatically = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "plugInsEnabled") == LUA_TBOOLEAN)
                myPreferences.plugInsEnabled = (BOOL)lua_toboolean(L, -1) ;
            if (lua_getfield(L, 2, "minimumFontSize") == LUA_TNUMBER)
                myPreferences.minimumFontSize = lua_tonumber(L, -1) ;

            // this is undocumented in Apples Documentation, but is in the WebKit2 docs
            if (lua_getfield(L, 2, "developerExtrasEnabled") == LUA_TBOOLEAN)
                [myPreferences setValue:@((BOOL)lua_toboolean(L, -1)) forKey:@"developerExtrasEnabled"] ;

            // Technically not in WKPreferences, but it makes sense to set it here
            if (lua_getfield(L, 2, "suppressesIncrementalRendering") == LUA_TBOOLEAN)
                config.suppressesIncrementalRendering = (BOOL)lua_toboolean(L, -1) ;

            lua_pop(L, 7) ;
            config.preferences = myPreferences ;
        }

        HSWebViewView *theView = [[HSWebViewView alloc] initWithFrame:((NSView *)theWindow.contentView).bounds
                                                        configuration:config];
        theWindow.contentView = theView;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs.webview:show() -> webviewObject
/// Method
/// Displays the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_show(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    [theWindow makeKeyAndOrderFront:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:hide() -> webviewObject
/// Method
/// Hides the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
static int webview_hide(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    [theWindow orderOut:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:allowTextEntry([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview can accept keyboard for web form entry. Defaults to false.
///
/// Parameters:
///  * value - an optional boolean value which sets whether or not the webview will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowTextEntry(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.allowKeyboardEntry) ;
    } else {
        theWindow.allowKeyboardEntry = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

// // Not working... may need to break down and use Javascript in UserContentController...
//
// /// hs.webview:allowMouseClicks([value]) -> webviewObject | current value
// /// Method
// /// Get or set whether or not the webview can accept mouse clicks for web navigation. Defaults to true.
// ///
// /// Parameters:
// ///  * value - an optional boolean value which sets whether or not the webview will accept mouse clicks.
// ///
// /// Returns:
// ///  * If a value is provided, then this method returns the webview object; otherwise the current value
// ///
// /// Notes:
// ///  * If this is set to false, then right clicks are ignored as well, regardless of the setting for `hs.webview:allowContextMenu()`.
// static int webview_allowMouseClicks(lua_State *L) {
//     HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
//     HSWebViewView   *theView = theWindow.contentView ;
//     if (lua_type(L, 2) == LUA_TNONE) {
//         lua_pushboolean(L, theView.allowMouseClicks) ;
//     } else {
//         theView.allowMouseClicks = (BOOL)lua_toboolean(L, 2) ;
//         lua_settop(L, 1) ;
//     }
//     return 1 ;
// }
//
// /// hs.webview:allowContextMenu([value]) -> webviewObject | current value
// /// Method
// /// Get or set whether or not a right click in the webview shows the web context menu on right mouse button click. Defaults to true.
// ///
// /// Parameters:
// ///  * value - an optional boolean value which sets whether or not the webview will accept right mouse button clicks.
// ///
// /// Returns:
// ///  * If a value is provided, then this method returns the webview object; otherwise the current value
// ///
// /// Notes:
// ///  * If `hs.webview:allowMouseClicks()` is set to false, this value is ignored.
// static int webview_allowContextMenu(lua_State *L) {
//     HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
//     HSWebViewView   *theView = theWindow.contentView ;
//     if (lua_type(L, 2) == LUA_TNONE) {
//         lua_pushboolean(L, theView.allowContextMenu) ;
//     } else {
//         theView.allowContextMenu = (BOOL)lua_toboolean(L, 2) ;
//         lua_settop(L, 1) ;
//     }
//     return 1 ;
// }

// // too inclusive -- can't even bring window to the front anymore -- mouse click goes to window behind and brings it forward
//
// /// hs.webview:ignoreMouseEvents([value]) -> webviewObject | current value
// /// Method
// /// Get or set whether or not the webview ignores mouse events completely. Defaults to false.
// ///
// /// Parameters:
// ///  * value - an optional boolean value which sets whether or not the webview ignores mouse events.
// /// Returns:
// ///  * If a value is provided, then this method returns the webview object; otherwise the current value
// static int webview_ignoreMouseEvents(lua_State *L) {
//     HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
//     if (lua_type(L, 2) == LUA_TNONE) {
//         lua_pushboolean(L, !theWindow.ignoresMouseEvents) ;
//     } else {
//         theWindow.ignoresMouseEvents = !(BOOL)lua_toboolean(L, 2) ;
//         lua_settop(L, 1) ;
//     }
//     return 1 ;
// }

/// hs.webview:asHSWindow() -> hs.window object
/// Method
/// Returns an hs.window object for the webview so that you can use hs.window methods on it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
///
/// Notes:
///  * hs.window:minimize only works if the webview is minimizable (see `hs.webview.windowStyle`)
///  * hs.window:setSize only works if the webview is resizable (see `hs.webview.windowStyle`)
///  * hs.window:close only works if the webview is closable (see `hs.webview.windowStyle`)
///  * hs.window:maximize will reposition the webview to the upper left corner of your screen, but will only resize the webview if the webview is resizable (see `hs.webview.windowStyle`)
static int webview_hswindow(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    CGWindowID windowID = (CGWindowID)[theWindow windowNumber];
    lua_getglobal(L, "require"); lua_pushstring(L, "hs.window"); lua_call(L, 1, 1);
    lua_getfield(L, -1, "windowForID") ;
    lua_pushinteger(L, windowID) ;
    lua_call(L, 1, 1) ;
    return 1 ;
}

typedef struct _drawing_t {
    void *window;
} drawing_t;

/// hs.webview:asHSDrawing() -> hs.drawing object
/// Method
/// Returns an hs.drawing object for the webview so that you can use hs.drawing methods on it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
///
/// Notes:
///  * Methods in hs.drawing which are specific to a single drawing type will not work with this object.
static int webview_hsdrawing(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    lua_getglobal(L, "require"); lua_pushstring(L, "hs.drawing"); lua_call(L, 1, 1);

    drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
    memset(drawingObject, 0, sizeof(drawing_t));
    drawingObject->window = (__bridge_retained void*)theWindow;
    luaL_getmetatable(L, "hs.drawing");
    lua_setmetatable(L, -2);

    return 1 ;
}

/// hs.webView:windowTitle(title) -> webviewObject
/// Method
/// Sets the title for the webview window.
///
/// Parameters:
///  * title - the title to set for the webview window
///
/// Returns:
///  * The webview Object
///
/// Notes:
///  * If you wish this to match the web page title, you can use `hs.webview:windowTitle(hs.webview:title())` after making sure `hs.webview:loading == false`.
///  * Any title set with this method will be hidden unless the window style includes the "titled" style (see `hs.webview.windowStyle` and `hs.webview.windowMasks`)
static int webview_windowTitle(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;

//     NSString        *theTitle = [[LuaSkin shared] toNSObjectAtIndex:2] ;
    size_t size ;
    unsigned char *string = (unsigned char *)lua_tolstring(L, 2, &size) ;
    NSString *theTitle = [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;

    [theWindow setTitle:theTitle] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview.windowMasks[]
/// Constant
/// A table containing valid masks for the webview window.
///
/// Table Keys:
///  * borderless         - The window has no border decorations (default)
///  * titled             - The window title bar is displayed
///  * closable           - The window has a close button
///  * miniaturizable     - The window has a minimize button
///  * resizable          - The window is resizable
///  * texturedBackground - The window has a texturized background
///
/// Notes:
///  * The Maximize button is also provided when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.
static int webview_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
      lua_pushinteger(L, NSBorderlessWindowMask) ;         lua_setfield(L, -2, "borderless") ;
      lua_pushinteger(L, NSTitledWindowMask) ;             lua_setfield(L, -2, "titled") ;
      lua_pushinteger(L, NSClosableWindowMask) ;           lua_setfield(L, -2, "closable") ;
      lua_pushinteger(L, NSMiniaturizableWindowMask) ;     lua_setfield(L, -2, "miniaturizable") ;
      lua_pushinteger(L, NSResizableWindowMask) ;          lua_setfield(L, -2, "resizable") ;
      lua_pushinteger(L, NSTexturedBackgroundWindowMask) ; lua_setfield(L, -2, "texturedBackground") ;
    return 1 ;
}

static int webview_windowStyle(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)theWindow.styleMask) ;
    } else {
        [theWindow setStyleMask:(NSUInteger)luaL_checkinteger(L, 2)] ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Lua Framework Stuff

static int userdata_tostring(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    NSString *title ;
    if (theWindow) {
        title = [theView title] ;
    } else {
        title = @"<deleted>" ;
    }

    if (!title) {
        title = @"" ;
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// static int userdata_eq(lua_State* L) {
// }

/// hs.webview:delete()
/// Method
/// Destroys the webview object
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is automatically called during garbage collection, when Hammerspoon quits, and when its configuration is reloaded.
static int userdata_gc(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge_transfer HSWebViewWindow, L, 1) ;
    [theWindow close];
    theWindow = nil;

    void** windowPtr = lua_touserdata(L, 1);
    *windowPtr = nil ;
    return 0;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    // Webview Related
    {"goBack",                     webview_goBack},
    {"goForward",                  webview_goForward},
    {"url",                        webview_url},
    {"title",                      webview_title},
    {"reload",                     webview_reload},
    {"magnification",              webview_magnification},
    {"allowMagnificationGestures", webview_allowMagnificationGestures},
    {"allowNavigationGestures",    webview_allowNavigationGestures},
    {"isOnlySecureContent",        webview_isOnlySecureContent},
    {"estimatedProgress",          webview_estimatedProgress},
    {"loading",                    webview_loading},
    {"stopLoading",                webview_stopLoading},
    {"html",                       webview_html},
    {"historyList",                webview_historyList},
    {"navigationCallback",         webview_navigationCallback},
//     {"allowMouseClicks",           webview_allowMouseClicks},
//     {"allowContextMenu",           webview_allowContextMenu},
//     {"ignoreMouseEvents",          webview_ignoreMouseEvents},

#ifdef _WV_DEBUG
    {"verbose",                    webview_verbose},
    {"preferences",                webview_preferences},
#endif

    // Window related
    {"show",                       webview_show},
    {"hide",                       webview_hide},
    {"delete",                     userdata_gc},
    {"allowTextEntry",             webview_allowTextEntry},
    {"asHSWindow",                 webview_hswindow} ,
    {"asHSDrawing",                webview_hsdrawing},
    {"windowTitle",                webview_windowTitle},
    {"_windowStyle",               webview_windowStyle},

    {"__tostring",                 userdata_tostring},
//     {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", webview_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_webview_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:fn_pushWKBackForwardListItem forClass:"WKBackForwardListItem"] ;

    webview_windowMasksTable(L) ;
    lua_setfield(L, -2, "windowMasks") ;

    return 1;
}
