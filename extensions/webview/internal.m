#import "webview.h"

// TODO: or ideas for updates
//   single dialog for credentials
//   downloads, save - where? intercept/redirect?
//   cookies and cache?
//   handle self-signed ssl
//   can we adjust context menu?
//   can we choose native viewer over plugin if plugins enabled (e.g. not use Adobe for PDF)?

static int           refTable ;
static WKProcessPool *HSWebViewProcessPool ;

#pragma mark - Classes and Delegates

// forward declare so we can use in windowShouldClose:
static int userdata_gc(lua_State* L) ;

#pragma mark - our window object

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
        self.backgroundColor    = [NSColor whiteColor];
        self.opaque             = YES;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = NO;
        self.allowKeyboardEntry = NO;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.closeOnEscape      = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSNormalWindowLevel;

        self.parent             = nil ;
        self.children           = [[NSMutableArray alloc] init] ;
        self.udRef              = LUA_NOREF ;
        self.hsDrawingUDRef     = LUA_NOREF ;
        self.titleFollow        = YES ;
        self.deleteOnClose      = NO ;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return self.allowKeyboardEntry ;
}

- (BOOL)windowShouldClose:(id __unused)sender {
    if ((self.styleMask & NSClosableWindowMask) != 0) {
        if (self.deleteOnClose) {
            LuaSkin *skin = [LuaSkin shared] ;
            lua_pushcfunction([skin L], userdata_gc) ;
            [skin pushNSObject:self] ;
            if (![skin protectedCallAndTraceback:1 nresults:0]) {
                lua_getglobal([skin L], "print") ; lua_insert([skin L], -2) ;
                lua_pushstring([skin L], "deleteOnClose:") ; lua_insert([skin L], -2) ;
                [skin protectedCallAndTraceback:2 nresults:0] ;
                NSLog(@"webview deleteOnClose: %s", lua_tostring([skin L], -1)) ;
            }
        }
        return YES ;
    } else {
        return NO ;
    }
}

- (void)cancelOperation:(id)sender {
    if (self.closeOnEscape)
        [super cancelOperation:sender] ;
}

@end

#pragma mark - our wkwebview object

@implementation HSWebViewView
- (id)initWithFrame:(NSRect)frameRect configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frameRect configuration:configuration] ;
    if (self) {
        self.navigationDelegate = self ;
        self.UIDelegate = self ;
        self.navigationCallback = LUA_NOREF ;
        self.policyCallback = LUA_NOREF ;
        self.allowNewWindows = YES ;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES ;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    return YES ;
}

#pragma mark -- WKNavigationDelegate stuff

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
    if (((HSWebViewWindow *)theView.window).titleFollow) [theView.window setTitle:[theView title]] ;

    [self navigationCallbackFor:"didFinishNavigation" forView:theView
                                               withNavigation:navigation
                                                    withError:nil] ;

}

- (void)webView:(WKWebView *)theView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailNavigation" forView:theView
                                                 withNavigation:navigation
                                                      withError:error]) {
//         NSLog(@"didFail: %@", error) ;
        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self navigationCallbackFor:"didFailProvisionalNavigation" forView:theView
                                                            withNavigation:navigation
                                                                 withError:error]) {
//         NSLog(@"provisionalFail: %@", error) ;
        if (error.code == NSURLErrorUnsupportedURL) {
            NSDictionary *userInfo = error.userInfo ;
            if ([[NSWorkspace sharedWorkspace] openURL:[userInfo objectForKey:NSURLErrorFailingURLErrorKey]])
                return ;
        }

        [self handleNavigationFailure:error forView:theView] ;
    }
}

- (void)webView:(WKWebView *)theView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                                                     completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSString *hostName = theView.URL.host;

    NSString *authenticationMethod = [[challenge protectionSpace] authenticationMethod];
    if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]
        || [authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest]) {

        NSURLCredential *previousCredential = [challenge proposedCredential] ;

        if (self.policyCallback != LUA_NOREF && [challenge previousFailureCount] < 3) { // don't get in a loop if the callback isn't working
            LuaSkin *skin = [LuaSkin shared] ;
            [skin pushLuaRef:refTable ref:self.policyCallback];
            lua_pushstring([skin L], "authenticationChallenge") ;
            [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
            [skin pushNSObject:challenge] ;

            if (![skin  protectedCallAndTraceback:3 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() authenticationChallenge callback error: %s", errorMsg]];
                // allow prompting if error -- fall through
            } else {
                if (lua_type([skin L], -1) == LUA_TTABLE) { // if it's a table, we'll get the username and password from it
                    lua_getfield([skin L], -1, "user") ;
                    NSString *userName = (lua_type([skin L], -1) == LUA_TSTRING) ? [skin toNSObjectAtIndex:-1] : @"" ;
                    lua_pop([skin L], 1) ;

                    lua_getfield([skin L], -1, "password") ;
                    NSString *password = (lua_type([skin L], -1) == LUA_TSTRING) ? [skin toNSObjectAtIndex:-1] : @"" ;
                    lua_pop([skin L], 1) ;

                    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:userName
                                                                               password:password
                                                                            persistence:NSURLCredentialPersistenceForSession];
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                    lua_pop([skin L], 1) ; // pop return value
                    return ;
                } else if (!lua_toboolean([skin L], -1)) { // if false, don't go forward
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                    lua_pop([skin L], 1) ; // pop return value
                    return ;
                } // fall through
                lua_pop([skin L], 1) ; // pop return value
            }
        }

        NSString *title = @"Authentication Challenge";
        if (previousCredential && [challenge previousFailureCount] > 0) {
            title = [NSString stringWithFormat:@"%@, attempt %ld", title, [challenge previousFailureCount] + 1] ;
        }
        NSAlert *alert1 = [[NSAlert alloc] init] ;
        [alert1 addButtonWithTitle:@"OK"];
        [alert1 addButtonWithTitle:@"Cancel"];
        [alert1 setMessageText:title] ;
        [alert1 setInformativeText:[NSString stringWithFormat:@"Username for %@", hostName]] ;
        NSTextField *user = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] ;
        if (previousCredential) {
            user.stringValue = [previousCredential user] ;
        }
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
                                                                                persistence:NSURLCredentialPersistenceForSession];

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
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationAction") ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        [skin pushNSObject:navigationAction] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() navigationAction callback error: %s", errorMsg]];
            decisionHandler(WKNavigationActionPolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationActionPolicyAllow) ;
            } else {
                decisionHandler(WKNavigationActionPolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    } else {
        decisionHandler(WKNavigationActionPolicyAllow) ;
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                                                       decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationResponse") ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        [skin pushNSObject:navigationResponse] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() navigationResponse callback error: %s", errorMsg]];
            decisionHandler(WKNavigationResponsePolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationResponsePolicyAllow) ;
            } else {
                decisionHandler(WKNavigationResponsePolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow) ;
    }
}

#pragma mark -- WKUIDelegate stuff

- (WKWebView *)webView:(WKWebView *)theView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                                                       forNavigationAction:(WKNavigationAction *)navigationAction
                                                            windowFeatures:(__unused WKWindowFeatures *)windowFeatures {
// TODO: maybe prevent when not titled/movable, include toggle to prevent new windows...
// copy window settings... what else?
    if (((HSWebViewView *)theView).allowNewWindows) {
        LuaSkin *skin = [LuaSkin shared] ;

        HSWebViewWindow *parent = (HSWebViewWindow *)theView.window ;
        NSRect theRect = [parent contentRectForFrameRect:parent.frame] ;

        theRect.origin.x = theRect.origin.x + 20 ;
        // correct for flipped origin in HS
        theRect.origin.y = [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height ;
        theRect.origin.y = theRect.origin.y + 20 ;

        HSWebViewWindow *newWindow = [[HSWebViewWindow alloc] initWithContentRect:theRect
                                                                        styleMask:parent.styleMask
                                                                          backing:NSBackingStoreBuffered
                                                                            defer:YES];
        newWindow.level              = parent.level ;
        newWindow.allowKeyboardEntry = parent.allowKeyboardEntry ;
        newWindow.titleFollow        = parent.titleFollow ;
        newWindow.parent             = parent ;
        newWindow.titleFollow        = parent.titleFollow ;
        newWindow.deleteOnClose      = YES ;

        HSWebViewView *newView = [[HSWebViewView alloc] initWithFrame:((NSView *)newWindow.contentView).bounds
                                                        configuration:configuration];
        newWindow.contentView = newView;

        newView.allowNewWindows                     = ((HSWebViewView *)theView).allowNewWindows ;
        newView.allowsMagnification                 = theView.allowsMagnification ;
        newView.allowsBackForwardNavigationGestures = theView.allowsBackForwardNavigationGestures ;

        if (((HSWebViewView *)theView).navigationCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:((HSWebViewView *)theView).navigationCallback];
            newView.navigationCallback = [skin luaRef:refTable] ;
        }
        if (((HSWebViewView *)theView).policyCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:((HSWebViewView *)theView).policyCallback];
            newView.policyCallback = [skin luaRef:refTable] ;
        }

        if (self.policyCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:self.policyCallback];
            lua_pushstring([skin L], "newWindow") ;
            [skin pushNSObject:newWindow] ;
            [skin pushNSObject:navigationAction] ;

            if (![skin  protectedCallAndTraceback:3 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1); lua_pop([skin L], 1) ;
                [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() newWindow callback error: %s", errorMsg]];

                lua_pushcfunction([skin L], userdata_gc) ;
                [skin pushNSObject:newWindow] ;
                if (![skin protectedCallAndTraceback:1 nresults:0]) {
                    const char *errorMsg = lua_tostring([skin L], -1); lua_pop([skin L], 1) ;
                    [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() newWindow removal due to error: %s", errorMsg]];
                }
                return nil ;
            } else {
                if (!lua_toboolean([skin L], -1)) {
                    lua_pushcfunction([skin L], userdata_gc) ;
                    [skin pushNSObject:newWindow] ;
                    if (![skin protectedCallAndTraceback:1 nresults:0]) {
                        const char *errorMsg = lua_tostring([skin L], -1); lua_pop([skin L], 1) ;
                        [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() newWindow removal due rejection: %s", errorMsg]];
                    }
                    return nil ;
                }
            }
            lua_pop([skin L], 1) ; // clean up after ourselves
        }

        [parent.children addObject:newWindow] ;
        [newWindow makeKeyAndOrderFront:nil];

        return newView ;
    } else {
        return nil ;
    }
}

- (void)webView:(WKWebView *)theView runJavaScriptAlertPanelWithMessage:(NSString *)message
                                                       initiatedByFrame:(WKFrameInfo *)frame
                                                      completionHandler:(void (^)(void))completionHandler {
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

#pragma mark -- Helper methods to reduce code replication

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

    ((HSWebViewView *)theView).trackingID = navigation ;

    BOOL actionRequiredAfterReturn = YES ;

    if (self.navigationCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        int numberOfArguments = 3 ;
        [skin pushLuaRef:refTable ref:self.navigationCallback];
        lua_pushstring([skin L], action) ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%p", navigation] UTF8String]) ;

        if (error) {
            numberOfArguments++ ;
            [skin pushNSObject:error] ;
        }

        if (![skin  protectedCallAndTraceback:numberOfArguments nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:navigationCallback() %s callback error: %s", action, errorMsg]];
        } else {
            if (error) {
                if (lua_type([skin L], -1) == LUA_TSTRING) {
//                     lua_getglobal([skin L], "hs") ; lua_getfield([skin L], -1, "cleanUTF8forConsole") ;
//                     lua_pushvalue([skin L], -3) ;
//                     if (![skin protectedCallAndTraceback:1 nresults:1]) {
//                         [skin logError:[NSString stringWithFormat:@"hs.webview:navigationCallback() %s unable to validate HTML: %s", action, lua_tostring(skin.L, -1)]];
//                     } else {
//                         NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
//                         lua_pop([skin L], 2) ; // remove "hs" and the return value
//
//                         [theView loadHTMLString:theHTML baseURL:nil] ;
//                         actionRequiredAfterReturn = NO ;
//                     }
                    luaL_tolstring([skin L], -1, NULL) ;
                    NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
                    lua_pop([skin L], 1) ;

                    [theView loadHTMLString:theHTML baseURL:nil] ;
                    actionRequiredAfterReturn = NO ;

                } else if (lua_type([skin L], -1) == LUA_TBOOLEAN && lua_toboolean([skin L], -1)) {
                    actionRequiredAfterReturn = NO ;
                }
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
    }

    return actionRequiredAfterReturn ;
}

@end

// @interface WKPreferences (WKPrivate)
// @property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
// @end

// Yeah, I know the distinction is a little blurry and arbitrary, but it helps my thinking.
#pragma mark - WKWebView Related Methods

#ifdef _WK_DEBUG
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

/// hs.webview:children() -> array
/// Method
/// Returns an array of webview objects which have been opened as children of this webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array containing the webview objects of all child windows opened from this webview.
static int webview_children(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;

    lua_newtable(L) ;
    for (HSWebViewWindow *webView in theWindow.children) {
        [skin pushNSObject:webView] ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }

    return 1 ;
}

/// hs.webview:parent() -> webviewObject | nil
/// Method
/// Get the parent webview object for the calling webview object, or nil if the webview has no parent.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the parent webview object for the calling webview object, or nil if the webview has no parent
static int webview_parent(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;

    if (theWindow.parent) {
        [skin pushNSObject:theWindow.parent] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs.webview:url([URL]) -> webviewObject, navigationIdentifier | url
/// Method
/// Get or set the URL to render for the webview.
///
/// Parameters:
///  * URL - an optional string or table representing the URL to display.  If you provide a table, it should contain one or more of the following keys (note that URL is the only required key):
///    * URL                     - the URL of the desired content
///    * mainDocumentURL         - the URL of the main document, if it differs.  This usually only matters for cookie negotiation and currently has no effect in this module.
///    * HTTPBody                - the message body of the request, as in an HTTP POST request
///    * HTTPMethod              - the HTTP Method of the request, default GET.
///    * timeoutInterval         - the timeout interval for the request in seconds, default 60.0.
///    * HTTPShouldHandleCookies - whether or not cookies should be managed automatically, default true.  Currently there is no support for the manual handling of cookies, though this may change in the future.
///    * HTTPShouldUsePipelining - whether or not the request can continue to transmit data before receiving a response from the remote server.  Default false.
///    * cachePolicy             - a string value representing the cache policy for the request.  It should match one of the following:
///      * protocolCachePolicy     - (default) the cache policy defined as the default for the protocol of the URL request
///      * ignoreLocalCache        - ignore any locally cached content and request all content from the remote server
///      * returnCacheOrLoad       - return cached data, regardless of its age or expiration date. If there is no existing data in the cache corresponding to the request, load data from the originating source.
///      * returnCacheDontLoad     - treat the request as if offline - return cached data, regardless of its age or expiration date. If there is no existing data in the cache corresponding to the request, the load is considered to have failed.
///    * networkServiceType      - a string value representing the network service type of the request.  It should match one of the following:
///      * default                 - (default) standard network traffic.  You should rarely use a value other than this as it can affect the responsiveness of your computer and other applications.
///      * VoIP                    - with the VoIP service type, the kernel continues to listen for incoming traffic while your app is in the background, then wakes up your app whenever new data arrives. This should be used only for connections that are used to communicate with a VoIP service.
///      * video                   - specifies that this is video traffic
///      * background              - use this for data if your are performing a download that was not requested by the user — for example, prefetching content so that it will be available when the user chooses to view it.
///      * voice                   - specifies that this is voice traffic
///    * HTTPHeaderFields        - a table containing key-value pairs corresponding to additional headers you wish to include in your request.  Because the HTTP specification requires that both keys and values are strings, any key which is not a string is ignored, and any value which is not a string or number is also ignored.  In addition, the following keys are handled automatically behind the scenes and will be ignored if you specify them:
///      * Authorization
///      * Connection
///      * Host
///      * WWW-Authenticate
///      * Content-Length
///
/// Returns:
///  * If a URL is specified, then this method returns the webview Object and a navigation identifier; otherwise it returns the current url being displayed.
///
/// Notes:
///  * The navigation identifier can be used to track a web request as it is processed and loaded by using the `hs.webview:navigationCallback` method.
///  * The networkServiceType field of the URL request table is a hint to the operating system about what the underlying traffic is used for. This hint enhances the system's ability to prioritize traffic, determine how quickly it needs to wake up the Wi-Fi radio, and so on. By providing accurate information, you improve the ability of the system to optimally balance battery life, performance, and other considerations.  Likewise, inaccurate information can have a deleterious effect on your system performance and battery life.
static int webview_url(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        [skin pushNSObject:[theView URL]] ;
        return 1 ;
    } else {
        NSURLRequest *theNSURL = [skin luaObjectAtIndex:2 toClass:"NSURLRequest"] ;
        if (theNSURL) {
            WKNavigation *navID = [theView loadRequest:theNSURL] ;
            theView.trackingID = navID ;
            lua_pushvalue(L, 1) ;
            [skin pushNSObject:navID] ;
            return 2 ;
        } else {
            return luaL_error(L, "Invalid URL type.  String or table expected.") ;
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
static int webview_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [skin pushNSObject:[theView title]] ;
    return 1 ;
}

/// hs.webview:navigationID() -> navigationID
/// Method
/// Get the most recent navigation identifier for the specified webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the navigation identifier
///
/// Notes:
///  * This navigation identifier can be used to track the progress of a webview with the navigation callback function - see `hs.webview.navigationCallback`.
static int webview_navigationID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [skin pushNSObject:theView.trackingID] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    WKNavigation *navID ;
    if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2))
        navID = [theView reload] ;
    else
        navID = [theView reloadFromOrigin] ;

    theView.trackingID = navID ;

    lua_pushvalue(L, 1) ;
    [skin pushNSObject:navID] ;
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

/// hs.webview:allowNewWindows([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview allows new windows to be opened from it by any method.  Defaults to true.
///
/// Parameters:
///  * value - an optional boolean value indicating whether or not the webview should allow new windows to be opened from it.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes
///  * This method allows you to prevent a webview from being able to open a new window by any method.   This includes right-clicking on a link and selecting "Open in a New Window", JavaScript pop-ups, links with the target of "__blank", etc.
///  * If you just want to prevent automatic JavaScript windows, set the preference value javaScriptCanOpenWindowsAutomatically to false when creating the web view - this method blocks *all* methods.
static int webview_allowNewWindows(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.allowNewWindows) ;
    } else {
        theView.allowNewWindows = (BOOL)lua_toboolean(L, 2) ;
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
//     LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushnumber(L, [theView magnification]) ;
    } else {
        luaL_checktype(L, 2, LUA_TNUMBER) ;
        NSPoint centerOn = NSZeroPoint;

// Center point doesn't seem to do anything... will investigate further later...
//         if (lua_type(L, 3) == LUA_TTABLE) {
//             centerOn = [skin tableToPointAtIndex:3] ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;

//     luaL_checkstring(L, 2) ;
//
//     lua_getglobal(L, "hs") ; lua_getfield(L, -1, "cleanUTF8forConsole") ;
//     lua_pushvalue(L, 2) ;
//     if (![skin protectedCallAndTraceback:1 nresults:1]) {
//         return luaL_error(L, "unable to validate HTML: %s", lua_tostring(L, -1)) ;
//     }
    luaL_tolstring(L, 2, NULL) ;

    NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
//     lua_pop(L, 2) ; // remove "hs" and the return value
    lua_pop(L, 1) ;

    NSString *theBaseURL ;
    if (lua_type(L, 3) == LUA_TSTRING || lua_type(L, 3) == LUA_TTABLE) {
      theBaseURL = [skin toNSObjectAtIndex:3] ;
    } else if (lua_type(L, 3) != LUA_TNONE) {
        return luaL_error(L, "baseURL should be string or none: found %s",lua_typename(L, lua_type(L, 3))) ;
    }

    WKNavigation *navID = [theView loadHTMLString:theHTML baseURL:[NSURL URLWithString:theBaseURL]] ;
    theView.trackingID = navID ;

    lua_pushvalue(L, 1) ; // strictly not necessary here, but it makes it clearer what we're returning
    [skin pushNSObject:navID] ;
    return 2 ;
}

/// hs.webview:navigationCallback(fn) -> webviewObject
/// Method
/// Sets a callback for tracking a webview's navigation process.
///
/// Parameters:
///  * fn - the function to be called when the navigation status of a webview cahnges.  To disable the callback function, explicitly specify nil.  The function should expect 3 or 4 arguments and may optionally return 1.  The function arguments are defined as follows:
///    * action  - a string indicating the webview's current status.  It will be one of the following:
///      * didStartProvisionalNavigation                    - a request or action to change the contents of the main frame has occurred
///      * didReceiveServerRedirectForProvisionalNavigation - a server redirect was received for the main frame
///      * didCommitNavigation                              - content has started arriving for the main frame
///      * didFinishNavigation                              - the webview's main frame has completed loading.
///      * didFailNavigation                                - an error has occurred after content started arriving
///      * didFailProvisionalNavigation                     - an error has occurred as or before content has started arriving
///    * webView - the webview object the navigation is occurring for.
///    * navID   - a navigation identifier which can be used to link this event back to a specific request made by a `hs.webview:url`, `hs.webview:html`, or `hs.webview:reload` method.
///    * error   - a table which will only be provided when `action` is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If provided, it will contain at leas some of the following keys, possibly others as well:
///      * code        - a numerical value indicating the type of error code.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * domain      - a string indcating the error domain of the error.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * description - a string describing the condition or problem that has occurred.
///      * reason      - if available, more information about what may have caused the problem to occur.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * The return value of the callback function is ignored except when the `action` argument is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If the return value when the action argument is one of these values is a string, it will be treated as html and displayed in the webview as the error message.  If the return value is the boolean value true, then no change will be made to the webview (it will continue to display the previous web page).  All other return values or no return value at all, if these navigation actions occur, will cause a default error page to be displayed in the webview.
static int webview_navigationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TFUNCTION | LS_TNIL,
                                LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.navigationCallback = [skin luaUnref:refTable ref:theView.navigationCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.navigationCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:policyCallback(fn) -> webviewObject
/// Method
/// Sets a callback to approve or deny web navigation activity.
///
/// Parameters:
///  * fn - the function to be called to approve or deny web navigation activity.  To disable the callback function, explicitly specify nil.  The callback function will accept three arguments and must return 1 argument which will determine if the action is approved or denied.  The first argument will specify the type of policy request and will determine the second and third arguments as follows:
///
///    * `navigationAction`: This applies to any connection to a server or service which supplies content for the webview and occurs before any connection has actually been made.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table about the navigation action requested and may contain any of the following keys:
///        * request        - a table containing the request for that generated this policy action request.  See `hs.webview.url` for details on what keys may be present in this table.
///        * sourceFrame    - a table describing the frame in which the request occurred containing the following keys:
///          * mainFrame      - a boolean value indicating if this is the main view frame of the webview or not
///          * request        - a table containing the request for this frame.  See `hs.webview.url` for details on what keys may be present in this table.
///        * targetFrame    - a table with the same keys as `sourceFrame`, but describing the target of the request, if it differs.
///        * buttonNumber   - a number indicating the mouse button pressed that initiated this action or 0 if no mouse button was involved (for example, a url specified via `hs.webview.url` or a request for an image, etc. as part of rendering an earlier request).
///        * modifierFlags  - a table containing keys for the keyboard modifiers which were pressed when the navigation generating this policy request was generated.
///        * navigationType - a string indicating how the navigation was requested: `linkActivated`, `formSubmitted`, `backForward`, `reload`, `formResubmitted`, or `other`
///    * The callback function should return `true` if the navigation should proceed or false if it should be denied.
///
///    * `navigationResponse`: This applies to any connection to a server or service which supplies content for the webview and occurs after the connection has been made but before it has been rendered in the webview.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table about the response received and may contain any of the following keys:
///        * canShowMIMEType - a boolean indicating whether or not the webview can display the content either natively or with a plugin.  If this value is false, it is likely the content either cannot be displayed at all or will appear as gibberish in the webview.
///        * forMainFrame    - a boolean indicating if the response is for a navigation of the main frames primary content (i.e. not an image or sub-frame, etc.)
///        * response        - a table describing the response to the URL request and may contain any of the following keys:
///          * expectedContentLength - the expected length of the response content
///          * suggestedFileName     - a suggested filename for the response data
///          * MIMEType              - the MIME type of the response data
///          * textEncodingName      - if the response is text, then this will contain the encoding type used
///          * URL                   - the URL of the actual response.  Note that this may differ from the original request due to redirects, etc.
///          * statusCode            - the HTTP response code for the request
///          * statusCodeDescription - a localized description of the response code
///          * allHeaderFields       - a table containing the header fields and values provided in the response
///    * The callback function should return `true` if the navigation should proceed or false if it should be denied.
///
///    * `newWindow`: This applies to any request to create a new window from a webview.  This includes JavaScript, the user selecting "Open in a new window", etc.
///      * the second argument will be the new webview this request is generating.
///      * the third argument will be a table about the navigation action requested.  See the description above for `navigationAction` for details about this parameter.
///    * The callback function should return `true` if the new window should be created or false if it should not.
///
///    * `authenticationChallenge`:  This applies to a web page which requires a log in credential for HTTPBasic or HTTPDigest authentication.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table containing the challenge details and may contain any of the following keys:
///        * previousFailureCount - an integer indicating the number of previously failed login attempts.  This will be 0 for the first try.
///        * failureResponse      - the response data as described for `navigationResponse` above for the last authentication failureResponse
///        * proposedCredential   - a table containing the previously failed credential containing any of the following keys:
///          * hasPassword          - a boolean value indicating if a password was provided with this credential
///          * persistence          - a string value identifying the persistence of this credential.  This value will be one of the following:
///            * none                 - the credential is for this URL request only and no other
///            * session              - the credential is for this session and will be forgotten once the webview is deleted
///            * permanent            - the credential is stored in the user's keychain
///            * synchronized         - the credential is stored in the user's keychain and may be shared with other devices with the same owning Apple ID.
///          * user                 - the username of the failed credential
///          * password             - the password of the failed credential
///        * protectionSpace      - a table describing the realm for the authentication and may contain any of the following keys:
///          * port                       - the port of the server with which communication for this request is occurring
///          * receivesCredentialSecurely - a boolean value indicating whether or not the credential can be sent to the server securely
///          * authenticationMethod       - a string indicating the authentication type: default, HTTPBasic, or HTTPDigest.  Other types exists but are not currently supported with this module or do not apply to webview activities.
///          * host                       - the host name of the server with which communication for this request is occurring
///          * protocol                   - the protocol for which the authentication is occurring
///          * isProxy                    - a boolean indicating whether or not the authentication is occurring with a proxy server
///          * proxyType                  - a string representing the type of proxy server: http, https, ftp, or socks.
///          * realm                      - a string representing the realm name for the authentication.
///    * The callback function should return true if the user should be prompted for the username and password credentials, a table with the keys `user` and `password` containing the username and password to log in with, or false if the login request should be cancelled.  Note that if your function returns a table and fails to authenticate three times, the user will be prompted anyways to prevent loops.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * With the `newWindow` action, the navigationCallback and policyCallback are automatically replicated for the new window from its parent.  If you wish to disable these for the new window or assign a different set of callback functions, you can do so before returning true in the callback function with the webview argument provided.
static int webview_policyCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TFUNCTION | LS_TNIL,
                                LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.policyCallback = [skin luaUnref:refTable ref:theView.policyCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.policyCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
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
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;

    [skin pushNSObject:[theView backForwardList]] ;
    return 1 ;
}

/// hs.webview:evaluateJavaScript(script, [callback]) -> webviewObject
/// Method
/// Execute JavaScript within the context of the current webview and optionally receive its result or error in a callback function.
///
/// Parameters:
///  * script - the JavaScript to execute within the context of the current webview's display
///  * callback - an optional function which should accept two parameters as the result of the executed JavaScript.  The function paramaters are as follows:
///    * result - the result of the executed JavaScript code or nil if there was no result or an error occurred.
///    * error  - an NSError table describing any error that occurred during the JavaScript execution or nil if no error occurred.
///
/// Returns:
///  * the webview object
static int webview_evaluateJavaScript(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TSTRING,
                                LS_TFUNCTION | LS_TOPTIONAL,
                                LS_TBREAK] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView          *theView = theWindow.contentView ;

    NSString *javascript = [skin toNSObjectAtIndex:2] ;
    int      callbackRef = LUA_NOREF ;

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3) ;
        callbackRef = [skin luaRef:refTable] ;
    }

    [theView evaluateJavaScript:javascript
              completionHandler:^(id obj, NSError *error){

        if (callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:obj] ;
            [skin pushNSObject:error] ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                const char *errorMsg = lua_tostring([skin L], -1); lua_pop([skin L], 1) ;
                [skin logError:[NSString stringWithFormat:@"hs.webview:evaluateJavaScript() callback error: %s", errorMsg]];
            }
            [skin luaUnref:refTable ref:callbackRef] ;
        }
    }] ;

    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Window Related Methods

/// hs.webview.new(rect, [preferencesTable], [userContentController]) -> webviewObject
/// Constructor
/// Create a webviewObject and optionally modify its preferences.
///
/// Parameters:
///  * rect - a rectangle specifying where the webviewObject should be displayed.
///  * preferencesTable - an optional table which can include one of more of the following keys:
///   * javaEnabled                           - java is enabled (default false)
///   * javaScriptEnabled                     - JavaScript is enabled (default true)
///   * javaScriptCanOpenWindowsAutomatically - can JavaScript open windows without user intervention (default true)
///   * minimumFontSize                       - minimum font size (default 0.0)
///   * plugInsEnabled                        - plug-ins are enabled (default false)
///   * developerExtrasEnabled                - include "Inspect Element" in the context menu
///   * suppressesIncrementalRendering        - suppresses content rendering until fully loaded into memory (default false)
///  * userContentController - an optional `hs.webview.usercontent` object to provide script injection and JavaScript messaging with Hammerspoon from the webview.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * To set the initial URL, use the `hs.webview:url` method before showing the webview object.
///  * Preferences can only be set when the webview object is created.  To change the preferences of an open webview, you will need to close it and recreate it with this method.
///  * developerExtrasEnabled is not listed in Apple's documentation, but is included in the WebKit2 documentation.
static int webview_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;

// This is still buggy when a userdata is optional.  Need to build a test suite and fix...
//     [skin checkArgs:LS_TTABLE,
//                                 LS_TTABLE    | LS_TOPTIONAL,
//                                 LS_TUSERDATA | LS_TOPTIONAL, USERDATA_UCC_TAG,
//                                 LS_TBREAK] ;

    NSRect windowRect = [skin tableToRectAtIndex:1] ;

    HSWebViewWindow *theWindow = [[HSWebViewWindow alloc] initWithContentRect:windowRect
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:YES];

    if (theWindow) {

        // Don't create until actually used...
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

            // this is undocumented in Apples Documentation, but is in the WebKit2 stuff... and it works
            if (lua_getfield(L, 2, "developerExtrasEnabled") == LUA_TBOOLEAN)
                [myPreferences setValue:@((BOOL)lua_toboolean(L, -1)) forKey:@"developerExtrasEnabled"] ;

            // Technically not in WKPreferences, but it makes sense to set it here
            if (lua_getfield(L, 2, "suppressesIncrementalRendering") == LUA_TBOOLEAN)
                config.suppressesIncrementalRendering = (BOOL)lua_toboolean(L, -1) ;

            lua_pop(L, 7) ;
            config.preferences = myPreferences ;
            if (lua_type(L, 3) != LUA_TNONE)
                config.userContentController = get_uccObjFromUserdata(__bridge HSUserContentController, L, 3) ;
        } else {
            if (lua_type(L, 2) != LUA_TNONE)
                config.userContentController = get_uccObjFromUserdata(__bridge HSUserContentController, L, 2) ;
        }

        HSWebViewView *theView = [[HSWebViewView alloc] initWithFrame:((NSView *)theWindow.contentView).bounds
                                                        configuration:config];
        theWindow.contentView = theView;

        [skin pushNSObject:theWindow] ;
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

/// hs.webview:deleteOnClose([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview should delete itself when its window is closed.
///
/// Parameters:
///  * value - an optional boolean value which sets whether or not the webview will delete itself when its window is closed by any method.  Defaults to false for a window created with `hs.webview.new` and true for any webview windows created by the main webview (user selects "Open Link in New Window", etc.)
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * If set to true, a webview object will be deleted when the user clicks on the close button of a titled and closable webview (see `hs.webview.windowStyle`).
///  * Children of an explicitly created webview automatically have this attribute set to true.  To cause closed children to remain after the user closes them, you can set this with a policy callback function when it receives the "newWindow" action.
static int webview_deleteOnClose(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.deleteOnClose) ;
    } else {
        theWindow.deleteOnClose = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:closeOnEscape([flag]) -> webviewObject | current value
/// Method
/// If the webview is closable, this will get or set whether or not the Escape key is allowed to close the webview window.
///
/// Parameters:
///  * flag - an optional boolean value which indicates whether a webview, when it's style includes Closable (see `hs.webview:windowStyle`), should allow the Escape key to be a shortcut for closing the webview window.  Defaults to false.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * If this is set to true, Escape will only close the window if no other element responds to the Escape key first (e.g. if you are editing a text input field, the Escape will be captured by the text field, not by the webview Window.)
static int webview_closeOnEscape(lua_State *L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.closeOnEscape) ;
    } else {
        theWindow.closeOnEscape = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

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
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    CGWindowID windowID = (CGWindowID)[theWindow windowNumber];

    [skin requireModule:"hs.window"] ;
    lua_getfield(L, -1, "windowForID") ;
    lua_pushinteger(L, windowID) ;
    lua_call(L, 1, 1) ;
    return 1 ;
}

typedef struct _drawing_t {
    void *window;
    BOOL skipClose ;
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
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;

    // We cache the drawing userdata so it doesn't get garbage collected if not saved in lua.. otherwise
    // the window would close at some random time when garbage collection occurred.  asHSWindow doesn't
    // need this because its __gc doesn't have any side effects.
    if (theWindow.hsDrawingUDRef == LUA_NOREF) {
        [skin requireModule:"hs.drawing"] ; // make sure its loaded
        lua_pop(L, 1) ;                                 // but we don't really need its table

        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = YES ;
        luaL_getmetatable(L, "hs.drawing");
        lua_setmetatable(L, -2);
        theWindow.hsDrawingUDRef = [skin luaRef:refTable] ;
    }

    [skin pushLuaRef:refTable ref:theWindow.hsDrawingUDRef] ;
    return 1 ;
}

/// hs.webview:windowTitle([title]) -> webviewObject
/// Method
/// Sets the title for the webview window.
///
/// Parameters:
///  * title - if specified and not nil, the title to set for the webview window.  If this parameter is not present or is nil, the title will follow the title of the webview's content.
///
/// Returns:
///  * The webview Object
///
/// Notes:
///  * The title will be hidden unless the window style includes the "titled" style (see `hs.webview.windowStyle` and `hs.webview.windowMasks`)
static int webview_windowTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;

    if (lua_isnoneornil(L, 2)) {
        theWindow.titleFollow = YES ;
        [theWindow setTitle:[theWindow.contentView title]] ;
    } else {
        luaL_checktype(L, 2, LUA_TSTRING) ;
        theWindow.titleFollow = NO ;

        [theWindow setTitle:[skin toNSObjectAtIndex:2]] ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview.windowMasks[]
/// Constant
/// A table containing valid masks for the webview window.
///
/// Table Keys:
///  * borderless             - The window has no border decorations (default)
///  * titled                 - The window title bar is displayed
///  * closable               - The window has a close button
///  * miniaturizable         - The window has a minimize button
///  * resizable              - The window is resizable
///  * texturedBackground     - The window has a texturized background
///  * fullSizeContentView    - If titled, the titlebar is within the frame size specified at creation, not above it.  Shrinks actual content area by the size of the titlebar, if present.
///  * utility                - If titled, the window shows a utility panel titlebar (thinner than normal)
///  * nonactivating          - If the window is activated, it won't bring other Hammerspoon windows forward as well
///  * HUD                    - Requires utility; the window titlebar is shown dark and can only show the close button and title (if they are set)
///
/// Notes:
///  * The Maximize button in the window title is enabled when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.

//  * unifiedTitleAndToolbar - may be more useful if/when toolbar support is added.
//  * fullScreen             - I think because we're using NSPanel rather than NSWindow... may see about fixing later
//  * docModal               - We're not using this as a modal sheet or modal alert, so just sets some things we already override or don't use

static int webview_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
      lua_pushinteger(L, NSBorderlessWindowMask) ;             lua_setfield(L, -2, "borderless") ;
      lua_pushinteger(L, NSTitledWindowMask) ;                 lua_setfield(L, -2, "titled") ;
      lua_pushinteger(L, NSClosableWindowMask) ;               lua_setfield(L, -2, "closable") ;
      lua_pushinteger(L, NSMiniaturizableWindowMask) ;         lua_setfield(L, -2, "miniaturizable") ;
      lua_pushinteger(L, NSResizableWindowMask) ;              lua_setfield(L, -2, "resizable") ;
      lua_pushinteger(L, NSTexturedBackgroundWindowMask) ;     lua_setfield(L, -2, "texturedBackground") ;
//       lua_pushinteger(L, NSUnifiedTitleAndToolbarWindowMask) ; lua_setfield(L, -2, "unifiedTitleAndToolbar") ;
//       lua_pushinteger(L, NSFullScreenWindowMask) ;             lua_setfield(L, -2, "fullScreen") ;
      lua_pushinteger(L, NSFullSizeContentViewWindowMask) ;    lua_setfield(L, -2, "fullSizeContentView") ;
      lua_pushinteger(L, NSUtilityWindowMask) ;                lua_setfield(L, -2, "utility") ;
//       lua_pushinteger(L, NSDocModalWindowMask) ;               lua_setfield(L, -2, "docModal") ;
      lua_pushinteger(L, NSNonactivatingPanelMask) ;           lua_setfield(L, -2, "nonactivating") ;
      lua_pushinteger(L, NSHUDWindowMask) ;                    lua_setfield(L, -2, "HUD") ;
    return 1 ;
}

static int webview_windowStyle(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)theWindow.styleMask) ;
    } else {
            @try {
            // Because we're using NSPanel, the title is reset when the style is changed
                NSString *theTitle = [theWindow title] ;
            // Also, some styles don't get properly set unless we start from a clean slate
                [theWindow setStyleMask:0] ;
                [theWindow setStyleMask:(NSUInteger)luaL_checkinteger(L, 2)] ;
                if (theTitle) [theWindow setTitle:theTitle] ;
            }
            @catch ( NSException *theException ) {
                return luaL_error(L, "Invalid style mask: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
            }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

#pragma mark - NS<->lua conversion tools

static int HSWebViewWindow_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    HSWebViewWindow *theWindow = obj ;

    if (theWindow.udRef == LUA_NOREF) {
        void** windowPtr = lua_newuserdata(L, sizeof(HSWebViewWindow *)) ;
        *windowPtr = (__bridge_retained void *)theWindow ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
        theWindow.udRef = [skin luaRef:refTable] ;
    }

    [skin pushLuaRef:refTable ref:theWindow.udRef] ;
    return 1 ;
}

static int WKNavigationAction_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKNavigationAction *navAction = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[navAction request]] ;      lua_setfield(L, -2, "request") ;
      [skin pushNSObject:[navAction sourceFrame]] ;  lua_setfield(L, -2, "sourceFrame") ;
      [skin pushNSObject:[navAction targetFrame]] ;  lua_setfield(L, -2, "targetFrame") ;
      lua_pushinteger(L, [navAction buttonNumber]) ; lua_setfield(L, -2, "buttonNumber") ;
      unsigned long theFlags = [navAction modifierFlags] ;
      lua_newtable(L) ;
        if (theFlags & NSAlphaShiftKeyMask) { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "capslock") ; }
        if (theFlags & NSShiftKeyMask)      { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "shift") ; }
        if (theFlags & NSControlKeyMask)    { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "ctrl") ; }
        if (theFlags & NSAlternateKeyMask)  { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "alt") ; }
        if (theFlags & NSCommandKeyMask)    { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "cmd") ; }
        if (theFlags & NSFunctionKeyMask)   { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "fn") ; }
        lua_pushinteger(L, (lua_Integer)theFlags); lua_setfield(L, -2, "_raw");
      lua_setfield(L, -2, "modifierFlags") ;
      switch([navAction navigationType]) {
          case WKNavigationTypeLinkActivated:   lua_pushstring(L, "linkActivated") ; break ;
          case WKNavigationTypeFormSubmitted:   lua_pushstring(L, "formSubmitted") ; break ;
          case WKNavigationTypeBackForward:     lua_pushstring(L, "backForward") ; break ;
          case WKNavigationTypeReload:          lua_pushstring(L, "reload") ; break ;
          case WKNavigationTypeFormResubmitted: lua_pushstring(L, "formResubmitted") ; break ;
          case WKNavigationTypeOther:           lua_pushstring(L, "other") ; break ;
          default:                              lua_pushstring(L, "unknown") ; break ;
      }
      lua_setfield(L, -2, "navigationType") ;

    return 1 ;
}

static int WKNavigationResponse_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKNavigationResponse *navResponse = obj ;

    lua_newtable(L) ;
      lua_pushboolean(L, [navResponse canShowMIMEType]) ; lua_setfield(L, -2, "canShowMIMEType") ;
      lua_pushboolean(L, [navResponse isForMainFrame]) ;  lua_setfield(L, -2, "forMainFrame") ;
      [skin pushNSObject:[navResponse response]] ;        lua_setfield(L, -2, "response") ;
    return 1 ;
}

static int WKFrameInfo_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKFrameInfo *frameInfo = obj ;

    lua_newtable(L) ;
      lua_pushboolean(L, [frameInfo isMainFrame]) ; lua_setfield(L, -2, "mainFrame") ;
      [skin pushNSObject:[frameInfo request]] ;     lua_setfield(L, -2, "request") ;
    return 1 ;
}

static int WKBackForwardListItem_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKBackForwardListItem *item = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[item URL]] ;        lua_setfield(L, -2, "URL") ;
      [skin pushNSObject:[item initialURL]] ; lua_setfield(L, -2, "initialURL") ;
      [skin pushNSObject:[item title]] ;      lua_setfield(L, -2, "title") ;
    return 1 ;
}

static int WKBackForwardList_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    WKBackForwardList *theList = obj ;

    lua_newtable(L) ;
    if (theList) {
        NSArray *previousList = [theList backList] ;
        NSArray *nextList = [theList forwardList] ;

        for(id value in previousList) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        if ([theList currentItem]) {
            [skin pushNSObject:[theList currentItem]] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_pushinteger(L, luaL_len(L, -1)) ; lua_setfield(L, -2, "current") ;

        for(id value in nextList) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        lua_pushinteger(L, 0) ; lua_setfield(L, -2, "current") ;
    }
    return 1 ;
}

static int WKNavigation_toLua(lua_State *L, id obj) {
    WKNavigation *navID = obj ;
    lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", navID] UTF8String]) ;
    return 1 ;
}

static int NSError_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSError *theError = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [theError code]) ;                        lua_setfield(L, -2, "code") ;
        [skin pushNSObject:[theError domain]] ;                      lua_setfield(L, -2, "domain") ;
        [skin pushNSObject:[theError helpAnchor]] ;                  lua_setfield(L, -2, "helpAnchor") ;
        [skin pushNSObject:[theError localizedDescription]] ;        lua_setfield(L, -2, "localizedDescription") ;
        [skin pushNSObject:[theError localizedRecoveryOptions]] ;    lua_setfield(L, -2, "localizedRecoveryOptions") ;
        [skin pushNSObject:[theError localizedRecoverySuggestion]] ; lua_setfield(L, -2, "localizedRecoverySuggestion") ;
        [skin pushNSObject:[theError localizedFailureReason]] ;      lua_setfield(L, -2, "localizedFailureReason") ;
        [skin pushNSObject:[theError recoveryAttempter]] ;           lua_setfield(L, -2, "recoveryAttempter") ;
        [skin pushNSObject:[theError userInfo]] ;                    lua_setfield(L, -2, "userInfo") ;
    return 1 ;
}

static int NSURLAuthenticationChallenge_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLAuthenticationChallenge *challenge = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [challenge previousFailureCount]) ; lua_setfield(L, -2, "previousFailureCount") ;
        [skin pushNSObject:[challenge error]] ;                lua_setfield(L, -2, "error") ;
        [skin pushNSObject:[challenge failureResponse]] ;      lua_setfield(L, -2, "failureResponse") ;
        [skin pushNSObject:[challenge proposedCredential]] ;   lua_setfield(L, -2, "proposedCredential") ;
        [skin pushNSObject:[challenge protectionSpace]] ;      lua_setfield(L, -2, "protectionSpace") ;

#ifdef _WK_DEBUG_TYPES
        [skin pushNSObject:[challenge sender]] ;               lua_setfield(L, -2, "sender") ;
#endif
    return 1 ;
}

static int NSURLProtectionSpace_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLProtectionSpace *theSpace = obj ;

    lua_newtable(L) ;
        lua_pushboolean(L, [theSpace isProxy]) ;                    lua_setfield(L, -2, "isProxy") ;
        lua_pushinteger(L, [theSpace port]) ;                       lua_setfield(L, -2, "port") ;
        lua_pushboolean(L, [theSpace receivesCredentialSecurely]) ; lua_setfield(L, -2, "receivesCredentialSecurely") ;
        NSString *method = @"unknown" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodDefault])           method = @"default" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTTPBasic])         method = @"HTTPBasic" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTTPDigest])        method = @"HTTPDigest" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodHTMLForm])          method = @"HTMLForm" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodNegotiate])         method = @"negotiate" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodNTLM])              method = @"NTLM" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate]) method = @"clientCertificate" ;
        if ([[theSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust])       method = @"serverTrust" ;
        [skin pushNSObject:method] ;              lua_setfield(L, -2, "authenticationMethod") ;
        [skin pushNSObject:[theSpace host]] ;     lua_setfield(L, -2, "host") ;
        [skin pushNSObject:[theSpace protocol]] ; lua_setfield(L, -2, "protocol") ;
        NSString *proxy = @"unknown" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceHTTPProxy])  proxy = @"http" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceHTTPSProxy]) proxy = @"https" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceFTPProxy])   proxy = @"ftp" ;
        if ([[theSpace proxyType] isEqualToString:NSURLProtectionSpaceSOCKSProxy]) proxy = @"socks" ;
        [skin pushNSObject:proxy] ;            lua_setfield(L, -2, "proxyType") ;
        [skin pushNSObject:[theSpace realm]] ; lua_setfield(L, -2, "realm") ;

#ifdef _WK_DEBUG_TYPES
        lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%p", [theSpace serverTrust]] UTF8String]) ;
        lua_setfield(L, -2, "serverTrust") ;
#endif

    return 1 ;
}

static int NSURLCredential_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSURLCredential *credential = obj ;

    lua_newtable(L) ;
        lua_pushboolean(L, [credential hasPassword]) ; lua_setfield(L, -2, "hasPassword") ;
        switch([credential persistence]) {
            case NSURLCredentialPersistenceNone:           lua_pushstring(L, "none") ; break ;
            case NSURLCredentialPersistenceForSession:     lua_pushstring(L, "session") ; break ;
            case NSURLCredentialPersistencePermanent:      lua_pushstring(L, "permanent") ; break ;
            case NSURLCredentialPersistenceSynchronizable: lua_pushstring(L, "synchronized") ; break ;
            default:                                       lua_pushstring(L, "unknown") ; break ;
        }
      lua_setfield(L, -2, "persistence") ;

        [skin pushNSObject:[credential user]] ;     lua_setfield(L, -2, "user") ;
        [skin pushNSObject:[credential password]] ; lua_setfield(L, -2, "password") ;

#ifdef _WK_DEBUG_TYPES
        [skin pushNSObject:[credential certificates]] ; lua_setfield(L, -2, "certificates") ;
        lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%p", [credential identity]] UTF8String]) ;
        lua_setfield(L, -2, "identity") ;
#endif

    return 1 ;
}

#pragma mark - Lua Framework Stuff

static int userdata_tostring(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView = theWindow.contentView ;
    NSString *title ;

    if (theWindow) { title = [theView title] ; } else { title = @"<deleted>" ; }
    if (!title) { title = @"" ; }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1) ;
    HSWebViewWindow *otherWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 2) ;

    lua_pushboolean(L, theWindow.udRef == otherWindow.udRef) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge_transfer HSWebViewWindow, L, 1) ;
    HSWebViewView   *theView   = theWindow.contentView ;

    if (theWindow) {
        LuaSkin *skin = [LuaSkin shared];
        [theWindow close] ;

        theWindow.udRef            = [skin luaUnref:refTable ref:theWindow.udRef] ;
        theWindow.hsDrawingUDRef   = [skin luaUnref:refTable ref:theWindow.hsDrawingUDRef] ;
        theView.navigationCallback = [skin luaUnref:refTable ref:theView.navigationCallback] ;
        theView.policyCallback     = [skin luaUnref:refTable ref:theView.policyCallback] ;

        // emancipate us from our parent
        if (theWindow.parent) {
            [theWindow.parent.children removeObject:theWindow] ;
            theWindow.parent = nil ;
        }

        // orphan our children
        for(HSWebViewWindow *child in theWindow.children) {
            child.parent = nil ;
        }

        theWindow.contentView = nil ;
        theView = nil ;
        theWindow = nil;
    }
// I think this may be too aggressive... removing the metatable is sufficient to make sure lua doesn't use it again
// // Clear the pointer so it's no longer dangling
//     void** windowPtr = lua_touserdata(L, 1);
//     *windowPtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    if (HSWebViewProcessPool) {
        HSWebViewProcessPool = nil ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    // Webview Related
    {"goBack",                     webview_goBack},
    {"goForward",                  webview_goForward},
    {"url",                        webview_url},
    {"title",                      webview_title},
    {"navigationID",               webview_navigationID},
    {"reload",                     webview_reload},
    {"magnification",              webview_magnification},
    {"allowMagnificationGestures", webview_allowMagnificationGestures},
    {"allowNewWindows",            webview_allowNewWindows},
    {"allowNavigationGestures",    webview_allowNavigationGestures},
    {"isOnlySecureContent",        webview_isOnlySecureContent},
    {"estimatedProgress",          webview_estimatedProgress},
    {"loading",                    webview_loading},
    {"stopLoading",                webview_stopLoading},
    {"html",                       webview_html},
    {"historyList",                webview_historyList},
    {"navigationCallback",         webview_navigationCallback},
    {"policyCallback",             webview_policyCallback},
    {"children",                   webview_children},
    {"parent",                     webview_parent},
    {"evaluateJavaScript",         webview_evaluateJavaScript},
#ifdef _WK_DEBUG
    {"preferences",                webview_preferences},
#endif

    // Window related
    {"show",                       webview_show},
    {"hide",                       webview_hide},
    {"closeOnEscape",              webview_closeOnEscape},
    {"_delete",                    userdata_gc},
    {"allowTextEntry",             webview_allowTextEntry},
    {"asHSWindow",                 webview_hswindow} ,
    {"asHSDrawing",                webview_hsdrawing},
    {"windowTitle",                webview_windowTitle},
    {"deleteOnClose",              webview_deleteOnClose},
    {"_windowStyle",               webview_windowStyle},

    {"__tostring",                 userdata_tostring},
    {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",      webview_new},
    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_webview_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:module_metaLib
                                           objectFunctions:userdata_metaLib];

    // module userdata specific conversions
    [skin registerPushNSHelper:HSWebViewWindow_toLua              forClass:"HSWebViewWindow"] ;

    // classes used primarily (solely?) by this module
    [skin registerPushNSHelper:WKBackForwardListItem_toLua        forClass:"WKBackForwardListItem"] ;
    [skin registerPushNSHelper:WKBackForwardList_toLua            forClass:"WKBackForwardList"] ;
    [skin registerPushNSHelper:WKNavigationAction_toLua           forClass:"WKNavigationAction"] ;
    [skin registerPushNSHelper:WKNavigationResponse_toLua         forClass:"WKNavigationResponse"] ;
    [skin registerPushNSHelper:WKFrameInfo_toLua                  forClass:"WKFrameInfo"] ;
    [skin registerPushNSHelper:WKNavigation_toLua                 forClass:"WKNavigation"] ;

    // classes that may find a better home elsewhere someday... (hs.http perhaps)
    [skin registerPushNSHelper:NSURLAuthenticationChallenge_toLua forClass:"NSURLAuthenticationChallenge"] ;
    [skin registerPushNSHelper:NSURLProtectionSpace_toLua         forClass:"NSURLProtectionSpace"] ;
    [skin registerPushNSHelper:NSURLCredential_toLua              forClass:"NSURLCredential"] ;

    // classes that definitely should find a more general/universal home someday...
    [skin registerPushNSHelper:NSError_toLua                      forClass:"NSError"] ;

    webview_windowMasksTable(L) ;
    lua_setfield(L, -2, "windowMasks") ;

    return 1;
}
