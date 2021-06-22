#import "webview.h"

// TODO: or ideas for updates
//   single dialog for credentials
//   downloads, save - where? intercept/redirect?
//   cookies and cache?
//   handle self-signed ssl
//   can we adjust context menu?
//   can we choose native viewer over plugin if plugins enabled (e.g. not use Adobe for PDF)?

static LSRefTable     refTable ;
static WKProcessPool *HSWebViewProcessPool ;

static NSMapTable    *delayTimers ;

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

#pragma mark - Classes and Delegates

// forward declare so we can use in class definitions
static int userdata_gc(lua_State* L) ;
static int NSError_toLua(lua_State *L, id obj) ;
static int SecCertificateRef_toLua(lua_State *L, SecCertificateRef certRef) ;

void delayUntilViewStopsLoading(HSWebViewView *theView, dispatch_block_t block) {
    if (!delayTimers) delayTimers = [NSMapTable strongToWeakObjectsMapTable] ;

//     if (theView.loading) [theView stopLoading] ;

    NSTimer *existingTimer = [delayTimers objectForKey:theView] ;
    if (existingTimer) {
        [existingTimer invalidate] ;
        [delayTimers removeObjectForKey:theView] ;
        existingTimer = nil ;
    }

    NSTimer *newDelay = [NSTimer timerWithTimeInterval:0.001
                                               repeats:YES
                                                 block:^(NSTimer *timer) {
        // make sure were wenen't queued in the runloop before the timer was invalidated by another "load" event
        if (timer.valid) {
            if (!theView.loading) {
                [theView stopLoading] ; // stop loading other resources
                [delayTimers removeObjectForKey:theView] ;
                [timer invalidate] ;
                block() ;
            }
        }
    }] ;

    [delayTimers setObject:newDelay forKey:theView] ;

    // fire immediately
    newDelay.fireDate = [NSDate dateWithTimeIntervalSinceNow:0] ;
    [[NSRunLoop currentRunLoop] addTimer:newDelay forMode:NSRunLoopCommonModes];
}

#pragma mark - our window object

@implementation HSWebViewWindow
// Apple's stupid API change gave this an enum name (finally) in 10.12, but clang complains about using the underlying
// type directly, which we have to do to maintain Xcode 7 compilability, so to keep Xcode 8 quite... this:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Woverriding-method-mismatch"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)windowStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation
#pragma clang diagnostic pop
#pragma clang diagnostic pop
{

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];

    if (self) {
        contentRect = RectWithFlippedYCoordinate(contentRect) ;
        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor clearColor];
        self.opaque             = YES;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = NO;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSNormalWindowLevel;

        _parent             = nil ;
        _children           = [[NSMutableArray alloc] init] ;
        _udRef              = LUA_NOREF ;
        _windowCallback     = LUA_NOREF ;
        _titleFollow        = YES ;
        _deleteOnClose      = NO ;
        _allowKeyboardEntry = NO;
        _closeOnEscape      = NO;
        _darkMode           = NO;
//        _lsCanary        = nil;

        // can't be set before the callback which acts on delegate methods is defined
        self.delegate       = self;
    }
    return self;
}

- (BOOL)darkModeEnabled {
    return _darkMode ;
}

- (BOOL)canBecomeKeyWindow {
    return _allowKeyboardEntry ;
}

- (BOOL)windowShouldClose:(id __unused)sender {
    if ((self.styleMask & NSWindowStyleMaskClosable) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}

- (void)windowWillClose:(__unused NSNotification *)notification {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    lua_State *L = [skin L] ;

    if (![skin checkGCCanary:self.lsCanary]) {
        return;
    }
    _lua_stackguard_entry(L);

    if (_windowCallback != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:_windowCallback] ;
        [skin pushNSObject:@"closing"] ;
        [skin pushNSObject:self] ;
        [skin protectedCallAndError:@"hs.webview:windowCallback:closing" nargs:2 nresults:0];
    }
    if (_deleteOnClose) {
        lua_pushcfunction(L, userdata_gc) ;
        [skin pushNSObject:self] ;
        // FIXME: Can we convert this lua_pcall() to a LuaSkin protectedCallAndError?
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            [skin logError:[NSString stringWithFormat:@"%s:error invoking _gc for deleteOnClose:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
    _lua_stackguard_exit(L);
}

- (void)windowDidBecomeKey:(__unused NSNotification *)notification {
	dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_windowCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:self->_windowCallback] ;
			[skin pushNSObject:@"focusChange"] ;
			[skin pushNSObject:self] ;
			lua_pushboolean(skin.L, YES) ;
			[skin protectedCallAndError:@"hs.webview:windowCallback:focusChange" nargs:3 nresults:0];
			_lua_stackguard_exit(skin.L);
		};
	});
}

- (void)windowDidResignKey:(__unused NSNotification *)notification {
	dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_windowCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:self->_windowCallback] ;
			[skin pushNSObject:@"focusChange"] ;
			[skin pushNSObject:self] ;
			lua_pushboolean(skin.L, NO) ;
			[skin protectedCallAndError:@"hs.webview:windowCallback:focusChange" nargs:3 nresults:0];
			_lua_stackguard_exit(skin.L);
		};
	});
}

- (void)windowDidResize:(__unused NSNotification *)notification {
	dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_windowCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:self->_windowCallback] ;
			[skin pushNSObject:@"frameChange"] ;
			[skin pushNSObject:self] ;
			[skin pushNSRect:RectWithFlippedYCoordinate(self.frame)] ;
			[skin protectedCallAndError:@"hs.webview:windowCallback:frameChange:resize" nargs:3 nresults:0];
			_lua_stackguard_exit(skin.L);
		};
	});
}

- (void)windowDidMove:(__unused NSNotification *)notification {
	dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_windowCallback != LUA_NOREF) {
			LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
			_lua_stackguard_entry(skin.L);
			[skin pushLuaRef:refTable ref:self->_windowCallback] ;
			[skin pushNSObject:@"frameChange"] ;
			[skin pushNSObject:self] ;
			[skin pushNSRect:RectWithFlippedYCoordinate(self.frame)] ;
			[skin protectedCallAndError:@"hs.webview:windowCallback:frameChange:move" nargs:3 nresults:0];
			_lua_stackguard_exit(skin.L);
		};
	});
}

- (void)cancelOperation:(id)sender {
    if (_closeOnEscape)
        [super cancelOperation:sender] ;
}

- (void)fadeIn:(NSTimeInterval)fadeTime {
    [self setAlphaValue:0.0];
    [self makeKeyAndOrderFront:nil];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:fadeTime];
    [[self animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}

- (void)fadeOut:(NSTimeInterval)fadeTime andDelete:(BOOL)deleteWindow withState:(lua_State *)L {
    [NSAnimationContext beginGrouping];
#if __has_feature(objc_arc)
      __weak HSWebViewWindow *bself = self; // in ARC, __block would increase retain count
#else
      __block HSWebViewWindow *bself = self;
#endif
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[NSAnimationContext currentContext] setCompletionHandler:^{
          // unlikely that bself will go to nil after this starts, but this keeps the warnings down from [-Warc-repeated-use-of-weak]
          HSWebViewWindow *mySelf = bself ;
          if (mySelf) {
              if (deleteWindow) {
              LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//                   lua_State *L = [skin L] ;
                  [mySelf close] ; // trigger callback, if set, then cleanup
                  lua_pushcfunction(L, userdata_gc) ;
                  [skin pushLuaRef:refTable ref:mySelf.udRef] ;
                  // FIXME: Can we convert this lua_pcall() to a LuaSkin protectedCallAndError?
                  if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                      [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete (with fade) method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                      lua_pop(L, 1) ;
                  }
              } else {
                  [mySelf orderOut:nil];
                  [mySelf setAlphaValue:1.0];
              }
          }
      }];
      [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}
@end


#pragma mark - our wkwebview object

@implementation HSWebViewView
- (id)initWithFrame:(NSRect)frameRect configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frameRect configuration:configuration] ;
    if (self) {
        self.navigationDelegate   = self ;
        self.UIDelegate           = self ;
        _navigationCallback       = LUA_NOREF ;
        _policyCallback           = LUA_NOREF ;
        _sslCallback              = LUA_NOREF ;
        _allowNewWindows          = YES ;
        _examineInvalidCertificates = NO ;
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
    NSString *windowTitle = [theView title] ? [theView title] : @"<no title>" ;
    if (((HSWebViewWindow *)theView.window).titleFollow) [theView.window setTitle:windowTitle] ;

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
            NSURL *destinationURL = [userInfo objectForKey:NSURLErrorFailingURLErrorKey] ;
            if (destinationURL) {
                if ([[NSWorkspace sharedWorkspace] openURL:destinationURL]) return ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didFailProvisionalNavigation missing NSURLErrorFailingURLErrorKey", USERDATA_TAG]] ;
            }
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
            LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self.policyCallback];
            lua_pushstring([skin L], "authenticationChallenge") ;
            [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
            [skin pushNSObject:challenge] ;

            if (![skin  protectedCallAndTraceback:3 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() authenticationChallenge callback error: %s", errorMsg]];
                // No lua_pop() here, it's handled below
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
                    _lua_stackguard_exit(skin.L);
                    return ;
                } else if (!lua_toboolean([skin L], -1)) { // if false, don't go forward
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                    lua_pop([skin L], 1) ; // pop return value
                    _lua_stackguard_exit(skin.L);
                    return ;
                } // fall through
            }
            lua_pop([skin L], 1) ; // pop return value if fall through
            _lua_stackguard_exit(skin.L);
        }

        NSWindow *targetWindow = self.window ;
        if (targetWindow) {
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
                NSString *previousUser = [previousCredential user] ? [previousCredential user] : @"" ;
                user.stringValue = previousUser ;
            }
            user.editable = YES ;
            [alert1 setAccessoryView:user] ;

            [alert1 beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
                if (returnCode == NSAlertFirstButtonReturn) {
                    NSAlert *alert2 = [[NSAlert alloc] init] ;
                    [alert2 addButtonWithTitle:@"OK"];
                    [alert2 addButtonWithTitle:@"Cancel"];
                    [alert2 setMessageText:title] ;
                    [alert2 setInformativeText:[NSString stringWithFormat:@"password for %@", hostName]] ;
                    NSSecureTextField *pass = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 36, 200, 24)];
                    pass.editable = YES ;
                    [alert2 setAccessoryView:pass] ;
                    [alert2 beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode2){
                        if (returnCode2 == NSAlertFirstButtonReturn) {
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
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didReceiveAuthenticationChallenge no target window", USERDATA_TAG]] ;
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    } else if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
        SecTrustResultType status ;
        SecTrustEvaluate(serverTrust, &status);

        if (status == kSecTrustResultRecoverableTrustFailure && self.sslCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self.sslCallback];
            [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
            [skin pushNSObject:challenge.protectionSpace] ;

            if (![skin  protectedCallAndTraceback:2 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                [skin logError:[NSString stringWithFormat:@"hs.webview:sslCallback callback error: %s", errorMsg]];
                // No lua_pop() here, it's handled below
                completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            } else {
                if ((lua_type([skin L], -1) == LUA_TBOOLEAN) && lua_toboolean([skin L], -1) && _examineInvalidCertificates) {
                    CFDataRef exceptions = SecTrustCopyExceptions(serverTrust);
                    SecTrustSetExceptions(serverTrust, exceptions);
                    CFRelease(exceptions);
                    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
                } else {
                    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
                }
            }
            lua_pop([skin L], 1) ;
            _lua_stackguard_exit(skin.L);
        } else {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:didReceiveAuthenticationChallenge unhandled challenge type:%@", USERDATA_TAG, [[challenge protectionSpace] authenticationMethod]]] ;
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                                                     decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationAction") ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        [skin pushNSObject:navigationAction] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() navigationAction callback error: %s", errorMsg]];
            // No lua_pop() here, it's handled below
            decisionHandler(WKNavigationActionPolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationActionPolicyAllow) ;
            } else {
                decisionHandler(WKNavigationActionPolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
        _lua_stackguard_exit(skin.L);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow) ;
    }
}

- (void)webView:(WKWebView *)theView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                                                       decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (self.policyCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.policyCallback];
        lua_pushstring([skin L], "navigationResponse") ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        [skin pushNSObject:navigationResponse] ;

        if (![skin  protectedCallAndTraceback:3 nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() navigationResponse callback error: %s", errorMsg]];
            // No lua_pop() here, it's handled below
            decisionHandler(WKNavigationResponsePolicyCancel) ;
        } else {
            if (lua_toboolean([skin L], -1)) {
                decisionHandler(WKNavigationResponsePolicyAllow) ;
            } else {
                decisionHandler(WKNavigationResponsePolicyCancel) ;
            }
        }
        lua_pop([skin L], 1) ; // clean up after ourselves
        _lua_stackguard_exit(skin.L);
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow) ;
    }
}

// - (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView ;

#pragma mark -- WKUIDelegate stuff

- (WKWebView *)webView:(WKWebView *)theView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                                                       forNavigationAction:(WKNavigationAction *)navigationAction
                                                            windowFeatures:(WKWindowFeatures *)windowFeatures {
// TODO: maybe prevent when not titled/movable, include toggle to prevent new windows...
// copy window settings... what else?
    if (((HSWebViewView *)theView).allowNewWindows) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L); // FIXME: Are we 100% sure this method is called from C and not Lua?

        HSWebViewWindow *parent = (HSWebViewWindow *)theView.window ;
        NSRect theRect = [parent contentRectForFrameRect:parent.frame] ;

        // correct for flipped origin in HS
        theRect = RectWithFlippedYCoordinate(theRect) ;
        theRect.origin.x = theRect.origin.x + 20 ;
        theRect.origin.y = theRect.origin.y + 20 ;

        HSWebViewWindow *newWindow = [[HSWebViewWindow alloc] initWithContentRect:theRect
                                                                        styleMask:parent.styleMask
                                                                          backing:NSBackingStoreBuffered
                                                                            defer:YES];
        newWindow.level              = parent.level ;
        newWindow.allowKeyboardEntry = parent.allowKeyboardEntry ;
        newWindow.titleFollow        = parent.titleFollow ;
        newWindow.parent             = parent ;
        newWindow.deleteOnClose      = YES ;
        newWindow.opaque             = parent.opaque ;
        newWindow.lsCanary           = [skin createGCCanary];

        if (((HSWebViewWindow *)theView.window).windowCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:((HSWebViewWindow *)theView.window).windowCallback];
            newWindow.windowCallback = [skin luaRef:refTable] ;
        }

        HSWebViewView *newView = [[HSWebViewView alloc] initWithFrame:((NSView *)newWindow.contentView).bounds
                                                        configuration:configuration];
        newWindow.contentView = newView;

        newView.allowNewWindows                     = ((HSWebViewView *)theView).allowNewWindows ;
        newView.allowsMagnification                 = theView.allowsMagnification ;
        newView.allowsBackForwardNavigationGestures = theView.allowsBackForwardNavigationGestures ;
        [newView setValue:@(newWindow.opaque) forKey:@"drawsTransparentBackground"];

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
            [skin pushNSObject:windowFeatures] ;

            if (![skin  protectedCallAndTraceback:4 nresults:1]) {
                const char *errorMsg = lua_tostring([skin L], -1);
                lua_pop([skin L], 1) ;
                [skin logError:[NSString stringWithFormat:@"hs.webview:policyCallback() newWindow callback error: %s", errorMsg]];

                lua_pushcfunction([skin L], userdata_gc) ;
                [skin pushNSObject:newWindow] ;
                [skin protectedCallAndError:@"hs.webview:policyCallback() newWindow removal" nargs:1 nresults:0];
                _lua_stackguard_exit(skin.L);
                return nil ;
            } else {
                if (!lua_toboolean([skin L], -1)) {
                    lua_pop([skin L], 1) ;
                    lua_pushcfunction([skin L], userdata_gc) ;
                    [skin pushNSObject:newWindow] ;
                    [skin protectedCallAndError:@"hs.webview:policyCallback() newWindow removal rejection" nargs:1 nresults:0];
                    _lua_stackguard_exit(skin.L);
                    return nil ;
                }
            }
            lua_pop([skin L], 1) ; // clean up after ourselves
        }

        [parent.children addObject:newWindow] ;
        [newWindow makeKeyAndOrderFront:nil];

        _lua_stackguard_exit(skin.L);
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

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [alertPanel beginSheetModalForWindow:targetWindow completionHandler:^(__unused NSModalResponse returnCode){
            completionHandler() ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptAlertPanelWithMessage no target window", USERDATA_TAG]] ;
    }
}

- (void)webView:(WKWebView *)theView runJavaScriptConfirmPanelWithMessage:(NSString *)message
                                                         initiatedByFrame:(WKFrameInfo *)frame
                                                        completionHandler:(void (^)(BOOL result))completionHandler{
    NSAlert *confirmPanel = [[NSAlert alloc] init] ;
    [confirmPanel addButtonWithTitle:@"OK"] ;
    [confirmPanel addButtonWithTitle:@"Cancel"] ;
    [confirmPanel setMessageText:[NSString stringWithFormat:@"JavaScript Confirm for %@", frame.request.URL.host]] ;
    [confirmPanel setInformativeText:message] ;

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [confirmPanel beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
            completionHandler((returnCode == NSAlertFirstButtonReturn) ? YES : NO) ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptConfirmPanelWithMessage no target window", USERDATA_TAG]] ;
    }
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

    NSWindow *targetWindow = theView.window ;
    if (targetWindow) {
        [inputPanel beginSheetModalForWindow:targetWindow completionHandler:^(NSModalResponse returnCode){
            if (returnCode == NSAlertFirstButtonReturn)
                completionHandler(input.stringValue) ;
            else
                completionHandler(nil) ;
        }] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:runJavaScriptTextInputPanelWithPrompt no target window", USERDATA_TAG]] ;
    }
}

// - (void)webViewDidClose:(WKWebView *)webView ;

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
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        int numberOfArguments = 3 ;
        [skin pushLuaRef:refTable ref:self.navigationCallback];
        lua_pushstring([skin L], action) ;
        [skin pushNSObject:(HSWebViewWindow *)theView.window] ;
        lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%@", (void *)navigation] UTF8String]) ;

        if (error) {
            numberOfArguments++ ;
            NSError_toLua(skin.L, error) ;
        }

        if (![skin  protectedCallAndTraceback:numberOfArguments nresults:1]) {
            const char *errorMsg = lua_tostring([skin L], -1);
            [skin logError:[NSString stringWithFormat:@"hs.webview:navigationCallback() %s callback error: %s", action, errorMsg]];
            // No lua_pop() here, it's handled below
        } else {
            if (error) {
                if (lua_type([skin L], -1) == LUA_TSTRING) {
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
        _lua_stackguard_exit(skin.L);
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
        lua_pushboolean(L, [[theConfiguration websiteDataStore] isPersistent]) ;     lua_setfield(L, -2, "persistent") ;
        lua_pushboolean(L, [theConfiguration allowsAirPlayForMediaPlayback]) ;       lua_setfield(L, -2, "allowsAirPlayForMediaPlayback") ;
        [skin pushNSObject:[theView customUserAgent]] ;                              lua_setfield(L, -2, "customUserAgent") ;
        [skin pushNSObject:[theConfiguration applicationNameForUserAgent]];          lua_setfield(L, -2, "applicationNameForUserAgent") ;
    return 1 ;
}
#endif

/// hs.webview:privateBrowsing() -> boolean
/// Method
/// Returns whether or not the webview browser is set up for private browsing (i.e. uses a non-persistent datastore)
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not the datastore is non-persistent.
///
/// Notes:
///  * This method is only supported by OS X 10.11 and newer
///
///  * See `hs.webview.datastore` and [hs.webview.new](#new) for more information.
static int webview_privateBrowsing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    if (NSClassFromString(@"WKWebsiteDataStore")) {
        HSWebViewView          *theView = theWindow.contentView ;
        WKWebViewConfiguration *theConfiguration = [theView configuration] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        lua_pushboolean(L, !theConfiguration.websiteDataStore.persistent) ;
#pragma clang diagnostic push
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:private browsing requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}



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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

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
///  * `URL` - an optional string or table representing the URL to display.  If you provide a table, it should contain one or more of the following keys (note that URL is the only required key):
///    * `URL`                     - the URL of the desired content
///    * `mainDocumentURL`         - the URL of the main document, if it differs.  This usually only matters for cookie negotiation and currently has no effect in this module.
///    * `HTTPBody`                - the message body of the request, as in an HTTP POST request
///    * `HTTPMethod`              - the HTTP Method of the request, default GET.
///    * `timeoutInterval`         - the timeout interval for the request in seconds, default 60.0.
///    * `HTTPShouldHandleCookies` - whether or not cookies should be managed automatically, default true.  Currently there is no support for the manual handling of cookies, though this may change in the future.
///    * `HTTPShouldUsePipelining` - whether or not the request can continue to transmit data before receiving a response from the remote server.  Default false.
///    * `cachePolicy`             - a string value representing the cache policy for the request.  It should match one of the following:
///      * `protocolCachePolicy`     - (default) the cache policy defined as the default for the protocol of the URL request
///      * `ignoreLocalCache`        - ignore any locally cached content and request all content from the remote server
///      * `returnCacheOrLoad`       - return cached data, regardless of its age or expiration date. If there is no existing data in the cache corresponding to the request, load data from the originating source.
///      * `returnCacheDontLoad`     - treat the request as if offline - return cached data, regardless of its age or expiration date. If there is no existing data in the cache corresponding to the request, the load is considered to have failed.
///    * `networkServiceType`      - a string value representing the network service type of the request.  It should match one of the following:
///      * `default`                 - (default) standard network traffic.  You should rarely use a value other than this as it can affect the responsiveness of your computer and other applications.
///      * `VoIP`                    - with the VoIP service type, the kernel continues to listen for incoming traffic while your app is in the background, then wakes up your app whenever new data arrives. This should be used only for connections that are used to communicate with a VoIP service.
///      * `video`                   - specifies that this is video traffic
///      * `background`              - use this for data if your are performing a download that was not requested by the user — for example, prefetching content so that it will be available when the user chooses to view it.
///      * `voice`                   - specifies that this is voice traffic
///    * `HTTPHeaderFields`        - a table containing key-value pairs corresponding to additional headers you wish to include in your request.  Because the HTTP specification requires that both keys and values are strings, any key which is not a string is ignored, and any value which is not a string or number is also ignored.  In addition, the following keys are handled automatically behind the scenes and will be ignored if you specify them:
///      * `Authorization`
///      * `Connection`
///      * `Host`
///      * `WWW-Authenticate`
///      * `Content-Length`
///
/// Returns:
///  * If a URL is specified, then this method returns the webview Object; otherwise it returns the current url being displayed.
///
/// Notes:
///  * The networkServiceType field of the URL request table is a hint to the operating system about what the underlying traffic is used for. This hint enhances the system's ability to prioritize traffic, determine how quickly it needs to wake up the Wi-Fi radio, and so on. By providing accurate information, you improve the ability of the system to optimally balance battery life, performance, and other considerations.  Likewise, inaccurate information can have a deleterious effect on your system performance and battery life.
static int webview_url(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        [skin pushNSObject:[[theView URL] absoluteString]] ;
        return 1 ;
    } else {
        NSURLRequest *theNSURL = [skin luaObjectAtIndex:2 toClass:"NSURLRequest"] ;
        if (theNSURL) {

            delayUntilViewStopsLoading(theView, ^{
                WKNavigation *navID = [theView loadRequest:theNSURL] ;
                theView.trackingID = navID ;
            }) ;

            lua_pushvalue(L, 1) ;
            return 1 ;
        } else {
            return luaL_error(L, "Invalid URL type.  String or table expected.") ;
        }
    }
}

/// hs.webview:userAgent([agent]) -> webviewObject | current value
/// Method
/// Get or set the webview's user agent string
///
/// Parameters:
///  * `agent` - an options string specifying the user agent string to include in all URL requests made by the webview object.
///
/// Returns:
///  * if a parameter is specified, returns the webviewObject, otherwise returns the current value
///
/// Notes:
///  * This method is only supported by OS X 10.11 and newer
///
///  * The default user string used by webview objects will be something like this (the exact version numbers will differ, depending upon your OS X version):
///   * "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/601.6.17 (KHTML, like Gecko)"
///  * By default, this method will return the empty string ("") when queried -- this indicates that the default, shown above, is used.  You can also return to this default by setting the user agent to "" with this method (e.g. `hs.webview:userAgent("")`).
///
///  * Some web sites tailor content based on the user string or use it for other internal purposes (tracking, statistics, page availability, layout, etc.).  Common user-agent strings can be found at http://www.useragentstring.com/pages/useragentstring.php.
///
///  * If you have set the user agent application name with the `applicationName` parameter to the [hs.webview.new](#new) constructor, it will be ignored unless this value is "", i.e. the default user agent string.  If you wish to specify an application name after the user agent string and use a custom string, include the application name in your custom string.
static int webview_userAgent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if ([theView respondsToSelector:NSSelectorFromString(@"customUserAgent")]) {
        if (lua_type(L, 2) == LUA_TNONE) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            [skin pushNSObject:theView.customUserAgent] ;
        } else {
    //         NSString *userAgent = [skin toNSObjectAtIndex:2] ;
            theView.customUserAgent = [skin toNSObjectAtIndex:2] ;
#pragma clang diagnostic push
            lua_pushvalue(L, 1) ;
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:userAgent requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.webview:certificateChain() -> table | nil
/// Method
/// Returns the certificate chain for the most recently committed navigation of the webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the certificates that make up the SSL certificate chain securing the most recent committed navigation.  Each certificate is described in a table with the following keys:
///    * `commonName` - the common name for the certificate; most commonly this will be a string matching the server portion of the URL request or other descriptor of the certificate's purpose.
///    * `values`     - a table containing key-value pairs describing the certificate.  The keys will be certificate OIDs.  Common OIDs and their meaning can be found in [hs.webview.certificateOIDs](#certificateOIDs). The value for each key will be a table with the following keys:
///      * `label`           - a description or label for the entry
///      * `localized label` - a localized version of `label`
///      * `type`            - a description of the data type for this value
///      * `value`           - the value
///
/// Notes:
///  * This method is only supported by OS X 10.11 and newer
///  * A navigation which was performed via HTTP instead of HTTPS will return an empty array.
///
///  * For OIDs which specify a type of "date" -- e.g. "2.5.29.24" (invalidityDate) -- the number provided represents the number of seconds since 12:00:00 AM, January 1, 1970 and can be used directly with the Lua `os.date` command.
///  * For OIDs which are known to represent a date, but specify its type as a "number" -- e.g. "2.16.840.1.113741.2.1.1.1.7" (X509V1ValidityNotAfter) or "2.16.840.1.113741.2.1.1.1.6" (X509V1ValidityNotBefore) -- the epoch is 12:00:00 AM, Jan 1, 2001.  To convert these dates into a format usable by Lua, you will need to do something similar to the following:  `os.date("%c", value + os.time({year=2001,month=1,day=1,hour=0,min=0,sec=0})`
static int webview_certificateChain(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if ([theView respondsToSelector:NSSelectorFromString(@"certificateChain")]) {
        lua_newtable(L) ;
        SecTrustRef certificateChain = theView.serverTrust;
        for (CFIndex i = 0; i < SecTrustGetCertificateCount(certificateChain); i++) {
            SecCertificateRef_toLua(L, SecTrustGetCertificateAtIndex(certificateChain, i));
            lua_rawseti(L, -2, luaL_len(L, -2) + 1);
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:certificateChain requires OS X 10.11 and newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    lua_pushboolean(L, [theView isLoading]) ;

    return 1 ;
}

/// hs.webview:stopLoading() -> webviewObject
/// Method
/// Stop loading additional content for the webview.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * this method does not stop the loading of the primary content for the page at the specified URL
///  * if [hs.webview:loading](#loading) would return true, this method does nothing -- see notes:
///    * The documentation from Apple is unclear and experimentation has shown that if this method is applied before the content of the specified URL has loaded, it can cause the webview to lock up; however it appears to stop the loading of addiional resources specified for the content (external script files, external style files, AJAX queries, etc.) and should be used in this context.
static int webview_stopLoading(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (!theView.loading) [theView stopLoading] ;

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goForward] ;

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;
    [theView goBack] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:reload([validate]) -> webviewObject, navigationIdentifier
/// Method
/// Reload the page in the webview, optionally performing end-to-end revalidation using cache-validating conditionals if possible.
///
/// Parameters:
///  * `validate` - an optional boolean indicating whether or not an attempt to perform end-to-end revalidation of cached data should be performed.  Defaults to false.
///
/// Returns:
///  * The webview Object
static int webview_reload(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    BOOL validate = (lua_type(L, 2) == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, 2) : NO ;

    delayUntilViewStopsLoading(theView, ^{
        WKNavigation *navID ;
        if (validate)
            navID = [theView reloadFromOrigin] ;
        else
            navID = [theView reload] ;
        theView.trackingID = navID ;
    }) ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview:transparent([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview background is transparent.  Default is false.
///
/// Parameters:
///  * `value` - an optional boolean value indicating whether or not the webview should be transparent.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * When enabled, the webview's background color is equal to the body's `background-color` (transparent by default)
///  * Setting `background-color:rgba(0, 225, 0, 0.3)` on `<body>` will give a translucent green webview background
static int webview_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG);

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, !(BOOL)theWindow.opaque);
    } else {
        theWindow.opaque = !(lua_toboolean(L, 2));
        [theWindow.contentView setValue:@(lua_toboolean(L, 2)) forKey:@"drawsTransparentBackground"];
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:allowMagnificationGestures([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview will respond to magnification gestures from a trackpad or magic mouse.  Default is false.
///
/// Parameters:
///  * `value` - an optional boolean value indicating whether or not the webview should respond to magnification gestures.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowMagnificationGestures(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
///  * `value` - an optional boolean value indicating whether or not the webview should allow new windows to be opened from it.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * This method allows you to prevent a webview from being able to open a new window by any method.   This includes right-clicking on a link and selecting "Open in a New Window", JavaScript pop-ups, links with the target of "__blank", etc.
///  * If you just want to prevent automatic JavaScript windows, set the preference value javaScriptCanOpenWindowsAutomatically to false when creating the web view - this method blocks *all* methods.
static int webview_allowNewWindows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.allowNewWindows) ;
    } else {
        theView.allowNewWindows = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:examineInvalidCertificates([flag]) -> webviewObject | current value
/// Method
/// Get or set whether or not invalid SSL server certificates that are approved by the ssl callback function are accepted as valid for browsing with the webview.
///
/// Parameters:
///  * `flag` - an optional boolean, default false, specifying whether or not an invalid SSL server certificate should be  accepted if it is approved by the ssl callback function.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * In order for this setting to have any effect, you must also register an ssl callback function with [hs.webview:sslCallback](#sslCallback) which should return true if the certificate should be granted an exception or false if it should not.  For a certificate to be granted an exception, both this method and the result of the callback *must* be true.
///
///  * A server certificate may be invalid for a variety of reasons:
///    * it is not signed by a recognized certificate authority - most commonly this means the certificate is self-signed.
///    * the certificate has expired
///    * the certificate has a common name (web site server name) other than the one requested (e.g. the certificate's common name is www.site.com, but it is being used for something else, possibly just https://site.com, possibly something else entirely
///    * some corporate proxy servers don't handle SSL properly and can cause a certificate to appear invalid even when they are valid (this is less common then it used to be, but does still occur occasionally)
///    * potentially nefarious reasons including man-in-the-middle attacks or phishing scams.
///
///  * The Hammerspoon server provided by `hs.httpserver` uses a self-signed certificate when set to use SSL, so it will be considered invalid for reason 1 above.
///
/// * If the certificate has been granted an exception in another application which registers the exception in the user's keychain (e.g. Safari), then the certificate is no longer considered invalid and this setting has no effect for that certificate.
static int webview_examineInvalidCertificates(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theView.examineInvalidCertificates) ;
    } else {
        theView.examineInvalidCertificates = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:allowNavigationGestures([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview will respond to the navigation gestures from a trackpad or magic mouse.  Default is false.
///
/// Parameters:
///  * `value` - an optional boolean value indicating whether or not the webview should respond to navigation gestures.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowNavigationGestures(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
///  * `value` - an optional number specifying the webviews magnification level.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
///  * `html`    - the html to be rendered in the webview
///  * `baseURL` - an optional Base URL to use as the starting point for any relative links within the provided html.
///
/// Returns:
///  * The webview Object
///
/// Notes:
///  * Web Pages generated in this manner are not added to the webview history list
static int webview_html(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow        *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView          *theView = theWindow.contentView ;

    luaL_tolstring(L, 2, NULL) ;

    NSString *theHTML = [skin toNSObjectAtIndex:-1] ;
    lua_pop(L, 1) ;

    NSString *theBaseURL = (lua_type(L, 3) == LUA_TSTRING) ? [skin toNSObjectAtIndex:3] : nil ;

    delayUntilViewStopsLoading(theView, ^{
        WKNavigation *navID = [theView loadHTMLString:theHTML baseURL:[NSURL URLWithString:theBaseURL]] ;
        theView.trackingID = navID ;
    }) ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview:navigationCallback(fn) -> webviewObject
/// Method
/// Sets a callback for tracking a webview's navigation process.
///
/// Parameters:
///  * `fn` - the function to be called when the navigation status of a webview cahnges.  To disable the callback function, explicitly specify nil.  The function should expect 3 or 4 arguments and may optionally return 1.  The function arguments are defined as follows:
///    * `action`  - a string indicating the webview's current status.  It will be one of the following:
///      * `didStartProvisionalNavigation`                    - a request or action to change the contents of the main frame has occurred
///      * `didReceiveServerRedirectForProvisionalNavigation` - a server redirect was received for the main frame
///      * `didCommitNavigation`                              - content has started arriving for the main frame
///      * `didFinishNavigation`                              - the webview's main frame has completed loading.
///      * `didFailNavigation`                                - an error has occurred after content started arriving
///      * `didFailProvisionalNavigation`                     - an error has occurred as or before content has started arriving
///    * `webView` - the webview object the navigation is occurring for.
///    * `navID`   - a navigation identifier which can be used to link this event back to a specific request made by a `hs.webview:url`, `hs.webview:html`, or `hs.webview:reload` method.
///    * `error`   - a table which will only be provided when `action` is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If provided, it will contain at leas some of the following keys, possibly others as well:
///      * `code`        - a numerical value indicating the type of error code.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * `domain`      - a string indcating the error domain of the error.  This will mostly be of use to developers or in debugging and may be removed in the future.
///      * `description` - a string describing the condition or problem that has occurred.
///      * `reason`      - if available, more information about what may have caused the problem to occur.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * The return value of the callback function is ignored except when the `action` argument is equal to `didFailNavigation` or `didFailProvisionalNavigation`.  If the return value when the action argument is one of these values is a string, it will be treated as html and displayed in the webview as the error message.  If the return value is the boolean value true, then no change will be made to the webview (it will continue to display the previous web page).  All other return values or no return value at all, if these navigation actions occur, will cause a default error page to be displayed in the webview.
static int webview_navigationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
///  * `fn` - the function to be called to approve or deny web navigation activity.  To disable the callback function, explicitly specify nil.  The callback function will accept three or four arguments and must return 1 argument which will determine if the action is approved or denied.  The first argument will specify the type of policy request and will determine the second and third arguments as follows:
///
///    * `navigationAction`: This applies to any connection to a server or service which supplies content for the webview and occurs before any connection has actually been made.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table about the navigation action requested and may contain any of the following keys:
///        * `request`        - a table containing the request for that generated this policy action request.  See `hs.webview.url` for details on what keys may be present in this table.
///        * `sourceFrame`    - a table describing the frame in which the request occurred containing the following keys:
///          * `mainFrame`      - a boolean value indicating if this is the main view frame of the webview or not
///          * `request`        - a table containing the request for this frame.  See `hs.webview.url` for details on what keys may be present in this table.
///        * `targetFrame`    - a table with the same keys as `sourceFrame`, but describing the target of the request, if it differs.
///        * `buttonNumber`   - a number indicating the mouse button pressed that initiated this action or 0 if no mouse button was involved (for example, a url specified via `hs.webview.url` or a request for an image, etc. as part of rendering an earlier request).
///        * `modifierFlags`  - a table containing keys for the keyboard modifiers which were pressed when the navigation generating this policy request was generated.
///        * `navigationType` - a string indicating how the navigation was requested: `linkActivated`, `formSubmitted`, `backForward`, `reload`, `formResubmitted`, or `other`
///    * The callback function should return `true` if the navigation should proceed or false if it should be denied.
///
///    * `navigationResponse`: This applies to any connection to a server or service which supplies content for the webview and occurs after the connection has been made but before it has been rendered in the webview.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table about the response received and may contain any of the following keys:
///        * `canShowMIMEType` - a boolean indicating whether or not the webview can display the content either natively or with a plugin.  If this value is false, it is likely the content either cannot be displayed at all or will appear as gibberish in the webview.
///        * `forMainFrame`    - a boolean indicating if the response is for a navigation of the main frames primary content (i.e. not an image or sub-frame, etc.)
///        * `response`        - a table describing the response to the URL request and may contain any of the following keys:
///          * `expectedContentLength` - the expected length of the response content
///          * `suggestedFileName`     - a suggested filename for the response data
///          * `MIMEType`              - the MIME type of the response data
///          * `textEncodingName`      - if the response is text, then this will contain the encoding type used
///          * `URL`                   - the URL of the actual response.  Note that this may differ from the original request due to redirects, etc.
///          * `statusCode`            - the HTTP response code for the request
///          * `statusCodeDescription` - a localized description of the response code
///          * `allHeaderFields`       - a table containing the header fields and values provided in the response
///    * The callback function should return `true` if the navigation should proceed or false if it should be denied.
///
///    * `newWindow`: This applies to any request to create a new window from a webview.  This includes JavaScript, the user selecting "Open in a new window", etc.
///      * the second argument will be the new webview this request is generating.
///      * the third argument will be a table about the navigation action requested.  See the description above for `navigationAction` for details about this parameter.
///      * the fourth argument will be a table containing features requested for the new window (none of these will be addressed by default -- you can choose to honor or disregard the feature requests in the callback yourself) and may contain any of the following keys:
///        * `menuBarVisibility`   - Whether the menu bar should be visible. (Not a feature provided for windows under OS X)
///        * `statusBarVisibility` - Whether the status bar should be visible. (Not currently supported by this module)
///        * `toolbarsVisibility`  - Whether toolbars should be visible.
///        * `allowsResizing`      - Whether the new window should be resizable.
///        * `x`                   - The x coordinate of the new window.
///        * `y`                   - The y coordinate of the new window.
///        * `h`                   - The height coordinate of the new window.
///        * `w`                   - The width coordinate of the new window.
///    * The callback function should return `true` if the new window should be created or false if it should not.
///
///    * `authenticationChallenge`:  This applies to a web page which requires a log in credential for HTTPBasic or HTTPDigest authentication.
///      * the second argument will be the webview this request originates from.
///      * the third argument will be a table containing the challenge details and may contain any of the following keys:
///        * `previousFailureCount` - an integer indicating the number of previously failed login attempts.  This will be 0 for the first try.
///        * `failureResponse`      - the response data as described for `navigationResponse` above for the last authentication failureResponse
///        * `proposedCredential`   - a table containing the previously failed credential containing any of the following keys:
///          * `hasPassword`          - a boolean value indicating if a password was provided with this credential
///          * `persistence`          - a string value identifying the persistence of this credential.  This value will be one of the following:
///            * None                 - the credential is for this URL request only and no other
///            * `session`              - the credential is for this session and will be forgotten once the webview is deleted
///            * `permanent`            - the credential is stored in the user's keychain
///            * `synchronized`         - the credential is stored in the user's keychain and may be shared with other devices with the same owning Apple ID.
///          * `user`                 - the username of the failed credential
///          * `password`             - the password of the failed credential
///        * `protectionSpace`      - a table describing the realm for the authentication and may contain any of the following keys:
///          * `port`                       - the port of the server with which communication for this request is occurring
///          * `receivesCredentialSecurely` - a boolean value indicating whether or not the credential can be sent to the server securely
///          * `authenticationMethod`       - a string indicating the authentication type: default, HTTPBasic, or HTTPDigest.  Other types exists but are not currently supported with this module or do not apply to webview activities.
///          * `host`                       - the host name of the server with which communication for this request is occurring
///          * `protocol`                   - the protocol for which the authentication is occurring
///          * `isProxy`                    - a boolean indicating whether or not the authentication is occurring with a proxy server
///          * `proxyType`                  - a string representing the type of proxy server: http, https, ftp, or socks.
///          * `realm`                      - a string representing the realm name for the authentication.
///    * The callback function should return true if the user should be prompted for the username and password credentials, a table with the keys `user` and `password` containing the username and password to log in with, or false if the login request should be cancelled.  Note that if your function returns a table and fails to authenticate three times, the user will be prompted anyways to prevent loops.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * With the `newWindow` action, the navigationCallback and policyCallback are automatically replicated for the new window from its parent.  If you wish to disable these for the new window or assign a different set of callback functions, you can do so before returning true in the callback function with the webview argument provided.
static int webview_policyCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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

/// hs.webview:sslCallback(fn) -> webviewObject
/// Method
/// Sets a callback to examine an invalid SSL certificate and determine if an exception should be granted.
///
/// Parameters:
///  * `fn` - the function to be called to examine the SSL certificate to determine if an exception should be granted.  To disable the callback function, explicitly specify nil.  The callback function will accept two arguments and must return 1 argument which will determine if the action is approved or denied.  The first argument will be the webview this request originates from.  The second argument will be a table containing the protection space details and may include the following keys:
///
///    * `port`                       - the port of the server with which communication for this request is occurring
///    * `receivesCredentialSecurely` - a boolean value indicating whether or not the credential can be sent to the server securely
///    * `authenticationMethod`       - a string indicating the authentication type, in this case "serverTrust".
///    * `host`                       - the host name of the server with which communication for this request is occurring
///    * `protocol`                   - the protocol for which the authentication is occurring
///    * `isProxy`                    - a boolean indicating whether or not the authentication is occurring with a proxy server
///    * `proxyType`                  - a string representing the type of proxy server: http, https, ftp, or socks.
///    * `realm`                      - a string representing the realm name for the authentication.
///    * `certificates` - an array of tables, each table describing a certificate in the SSL certificate chain provided by the server responding to the webview's request.  Each table will contain the following keys:
///      * `commonName` - the common name for the certificate; most commonly this will be a string matching the server portion of the URL request or other descriptor of the certificate's purpose.
///      * `values`     - a table containing key-value pairs describing the certificate.  The keys will be certificate OIDs.  Common OIDs and their meaning can be found in [hs.webview.certificateOIDs](#certificateOIDs). The value for each key will be a table with the following keys:
///        * `label`           - a description or label for the entry
///        * `localized label` - a localized version of `label`
///        * `type`            - a description of the data type for this value
///        * `value`           - the value
///
///  * The callback function should return true if an exception should be granted for this certificate or false if it should be rejected.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * even if this callback returns `true`, the certificate will only be granted an exception if [hs.webview:examineInvalidCertificates](#examineInvalidCertificates) has also been set to `true`.
///  * once an invalid certificate has been granted an exception, the exception will remain in effect until the webview object is deleted.
///  * the callback is only invoked for invalid certificates -- if a certificate is valid, or once an exception has been granted, the callback will not (no longer) be called for that certificate.
///
/// * If the certificate has been granted an exception in another application which registers the exception in the user's keychain (e.g. Safari), then the certificate is no longer considered invalid and this callback will not be invoked.
static int webview_sslCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theView.sslCallback = [skin luaUnref:refTable ref:theView.sslCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theView.sslCallback = [skin luaRef:refTable] ;
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
///    * `URL`        - the URL of the web page
///    * `initialURL` - the URL of the initial request that led to this item
///    * `title`      - the web page title
static int webview_historyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    [skin pushNSObject:[theView backForwardList]] ;
    return 1 ;
}

/// hs.webview:evaluateJavaScript(script, [callback]) -> webviewObject
/// Method
/// Execute JavaScript within the context of the current webview and optionally receive its result or error in a callback function.
///
/// Parameters:
///  * `script` - the JavaScript to execute within the context of the current webview's display
///  * `callback` - an optional function which should accept two parameters as the result of the executed JavaScript.  The function parameters are as follows:
///    * `result` - the result of the executed JavaScript code or nil if there was no result or an error occurred.
///    * `error`  - an NSError table describing any error that occurred during the JavaScript execution or nil if no error occurred.
///
/// Returns:
///  * the webview object
static int webview_evaluateJavaScript(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TFUNCTION | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;

    NSString *javascript = [skin toNSObjectAtIndex:2] ;
    int      callbackRef = LUA_NOREF ;

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3) ;
        callbackRef = [skin luaRef:refTable] ;
    }

    LSGCCanary lsCanary = [skin createGCCanary];
    [theView evaluateJavaScript:javascript
              completionHandler:^(id obj, NSError *error){

        if (callbackRef != LUA_NOREF) {
            dispatch_async(dispatch_get_main_queue(), ^{
                LuaSkin *blockSkin = [LuaSkin sharedWithState:L] ;
                if (![blockSkin checkGCCanary:lsCanary]) {
                    return;
                }
                [blockSkin pushLuaRef:refTable ref:callbackRef] ;
                [blockSkin pushNSObject:obj] ;
                NSError_toLua([blockSkin L], error) ;
                [blockSkin protectedCallAndError:@"hs.webview:evaluateJavaScript callback" nargs:2 nresults:0];
                [blockSkin luaUnref:refTable ref:callbackRef] ;

                [skin destroyGCCanary:&lsCanary];
            });
        }
    }] ;

    lua_settop(L, 1) ;
    return 1 ;
}

#pragma mark - Window Related Methods

/// hs.webview:topLeft([point]) -> webviewObject | currentValue
/// Method
/// Get or set the top-left coordinate of the webview window
///
/// Parameters:
///  * `point` - An optional point-table specifying the new coordinate the top-left of the webview window should be moved to
///
/// Returns:
///  * If an argument is provided, the webview object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the webview (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int webview_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    NSRect oldFrame = RectWithFlippedYCoordinate(theWindow.frame);

    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [theWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.webview:size([size]) -> webviewObject | currentValue
/// Method
/// Get or set the size of a webview window
///
/// Parameters:
///  * `size` - An optional size-table specifying the width and height the webview window should be resized to
///
/// Returns:
///  * If an argument is provided, the webview object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the webview should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int webview_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    NSRect oldFrame = theWindow.frame;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);
        [theWindow setFrame:newFrame display:YES animate:NO];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.webview.new(rect, [preferencesTable], [userContentController]) -> webviewObject
/// Constructor
/// Create a webviewObject and optionally modify its preferences.
///
/// Parameters:
///  * `rect` - a rectangle specifying where the webviewObject should be displayed.
///  * `preferencesTable` - an optional table which can include one of more of the following keys:
///   * `javaEnabled`                           - java is enabled (default false)
///   * `javaScriptEnabled`                     - JavaScript is enabled (default true)
///   * `javaScriptCanOpenWindowsAutomatically` - can JavaScript open windows without user intervention (default true)
///   * `minimumFontSize`                       - minimum font size (default 0.0)
///   * `plugInsEnabled`                        - plug-ins are enabled (default false)
///   * `developerExtrasEnabled`                - include "Inspect Element" in the context menu
///   * `suppressesIncrementalRendering`        - suppresses content rendering until fully loaded into memory (default false)
///   * The following additional preferences may also be set under OS X 10.11 or later (they will be ignored with a warning printed if used under OS X 10.10):
///     * `applicationName`                       - a string specifying an application name to be listed at the end of the browser's USER-AGENT header.  Note that this is only appended to the default user agent string; if you set a custom one with [hs.webview:userAgent](#userAgent), this value is ignored.
///     * `allowsAirPlay`                         - a boolean specifying whether media playback within the webview can play through AirPlay devices.
///     * `datastore`                             - an `hs.webview.datastore` object specifying where website data such as cookies, cacheable content, etc. is to be stored.
///     * `privateBrowsing`                       - a boolean (default false) specifying that the datastore should be set to a new, empty and non-persistent datastore.  Note that this will override the `datastore` key if both are specified and this is set to true.
///  * `userContentController` - an optional `hs.webview.usercontent` object to provide script injection and JavaScript messaging with Hammerspoon from the webview.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * To set the initial URL, use the `hs.webview:url` method before showing the webview object.
///  * Preferences can only be set when the webview object is created.  To change the preferences of an open webview, you will need to close it and recreate it with this method.
///
///  * developerExtrasEnabled is not listed in Apple's documentation, but is included in the WebKit2 documentation.
static int webview_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    NSRect windowRect = [skin tableToRectAtIndex:1] ;

    HSWebViewWindow *theWindow = [[HSWebViewWindow alloc] initWithContentRect:windowRect
                                                                    styleMask:NSWindowStyleMaskBorderless
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:YES];

    if (theWindow) {
        theWindow.lsCanary = [skin createGCCanary];

        // Don't create until actually used...
        if (!HSWebViewProcessPool) HSWebViewProcessPool = [[WKProcessPool alloc] init] ;

        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init] ;
        config.processPool = HSWebViewProcessPool ;

        if (lua_type(L, 2) == LUA_TTABLE) {
            WKPreferences *myPreferences = [[WKPreferences alloc] init] ;

            if (lua_getfield(L, 2, "javaEnabled") == LUA_TBOOLEAN)
                myPreferences.javaEnabled = (BOOL)lua_toboolean(L, -1) ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, 2, "javaScriptEnabled") == LUA_TBOOLEAN)
                myPreferences.javaScriptEnabled = (BOOL)lua_toboolean(L, -1) ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, 2, "javaScriptCanOpenWindowsAutomatically") == LUA_TBOOLEAN)
                myPreferences.javaScriptCanOpenWindowsAutomatically = (BOOL)lua_toboolean(L, -1) ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, 2, "plugInsEnabled") == LUA_TBOOLEAN)
                myPreferences.plugInsEnabled = (BOOL)lua_toboolean(L, -1) ;
            lua_pop(L, 1) ;

            if (lua_getfield(L, 2, "minimumFontSize") == LUA_TNUMBER)
                myPreferences.minimumFontSize = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;

            if ((lua_getfield(L, 2, "datastore") == LUA_TUSERDATA) && luaL_testudata(L, -1, "hs.webview.datastore")) {
                // this type of userdata is impossible to create if you're not on 10.11, so this is highly unlikely, but...
                if ([config respondsToSelector:NSSelectorFromString(@"setWebsiteDataStore:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                    config.websiteDataStore = [skin toNSObjectAtIndex:-1] ;
#pragma clang diagnostic push
                } else {
                    [skin logError:[NSString stringWithFormat:@"%s:setting a datastore requires OS X 10.11 or newer", USERDATA_TAG]] ;
                }
            }
            lua_pop(L, 1) ;

            // the privateBrowsing flag should override setting a datastore; you actually shouldn't specify both
            if ((lua_getfield(L, 2, "privateBrowsing") == LUA_TBOOLEAN) && lua_toboolean(L, -1)) {
                if ([config respondsToSelector:NSSelectorFromString(@"setWebsiteDataStore:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore] ;
#pragma clang diagnostic push
                } else {
                    [skin logError:[NSString stringWithFormat:@"%s:private mode browsing requires OS X 10.11 or newer", USERDATA_TAG]] ;
                }
            }
            lua_pop(L, 1) ;

            if (lua_getfield(L, 2, "applicationName") == LUA_TSTRING) {
                if ([config respondsToSelector:NSSelectorFromString(@"applicationNameForUserAgent")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                    config.applicationNameForUserAgent = [skin toNSObjectAtIndex:-1] ;
#pragma clang diagnostic push
                } else {
                    [skin logError:[NSString stringWithFormat:@"%s:setting the user agent application name requires OS X 10.11 or newer", USERDATA_TAG]] ;
                }
            }
            lua_pop(L, 1) ;

// Seems to be being ignored, will dig deeper if interest peaks or I have time
            if (lua_getfield(L, 2, "allowsAirPlay") == LUA_TBOOLEAN) {
                if ([config respondsToSelector:NSSelectorFromString(@"setAllowsAirPlayForMediaPlayback:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                    config.allowsAirPlayForMediaPlayback = (BOOL)lua_toboolean(L, -1) ;
#pragma clang diagnostic push
                } else {
                    [skin logError:[NSString stringWithFormat:@"%s:setting allowsAirPlay requires OS X 10.11 or newer", USERDATA_TAG]] ;
                }
            }
            lua_pop(L, 1) ;

            // this is undocumented in Apples Documentation, but is in the WebKit2 stuff... and it works
            if (lua_getfield(L, 2, "developerExtrasEnabled") == LUA_TBOOLEAN)
                [myPreferences setValue:@((BOOL)lua_toboolean(L, -1)) forKey:@"developerExtrasEnabled"] ;
            lua_pop(L, 1) ;

            // Technically not in WKPreferences, but it makes sense to set it here
            if (lua_getfield(L, 2, "suppressesIncrementalRendering") == LUA_TBOOLEAN)
                config.suppressesIncrementalRendering = (BOOL)lua_toboolean(L, -1) ;
            lua_pop(L, 1) ;

            config.preferences = myPreferences ;
            if (lua_type(L, 3) != LUA_TNONE)
                config.userContentController = get_objectFromUserdata(__bridge HSUserContentController, L, 3, USERDATA_UCC_TAG) ;
        } else {
            if (lua_type(L, 2) != LUA_TNONE)
                config.userContentController = get_objectFromUserdata(__bridge HSUserContentController, L, 2, USERDATA_UCC_TAG) ;
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

/// hs.webview:show([fadeInTime]) -> webviewObject
/// Method
/// Displays the webview object
///
/// Parameters:
///  * `fadeInTime` - An optional number of seconds over which to fade in the webview. Defaults to zero
///
/// Returns:
///  * The webview object
static int webview_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    NSTimeInterval  fadeTime   = (lua_gettop(L) == 2) ? lua_tonumber(L, 2) : 0.0 ;

    if (fadeTime > 0) {
        [theWindow fadeIn:fadeTime];
    } else {
        [theWindow makeKeyAndOrderFront:nil];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:hide([fadeOutTime]) -> webviewObject
/// Method
/// Hides the webview object
///
/// Parameters:
///  * `fadeOutTime` - An optional number of seconds over which to fade out the webview. Defaults to zero
///
/// Returns:
///  * The webview object
static int webview_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    NSTimeInterval  fadeTime   = (lua_gettop(L) == 2) ? lua_tonumber(L, 2) : 0.0 ;

    if (fadeTime > 0) {
        [theWindow fadeOut:fadeTime andDelete:NO withState:L];
    } else {
        [theWindow orderOut:nil];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:allowTextEntry([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview can accept keyboard for web form entry. Defaults to false.
///
/// Parameters:
///  * `value` - an optional boolean value which sets whether or not the webview will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_allowTextEntry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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
///  * `value` - an optional boolean value which sets whether or not the webview will delete itself when its window is closed by any method.  Defaults to false for a window created with `hs.webview.new` and true for any webview windows created by the main webview (user selects "Open Link in New Window", etc.)
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * If set to true, a webview object will be deleted when the user clicks on the close button of a titled and closable webview (see `hs.webview.windowStyle`).
///  * Children of an explicitly created webview automatically have this attribute set to true.  To cause closed children to remain after the user closes the parent, you can set this to false with a policy callback function when it receives the "newWindow" action.
static int webview_deleteOnClose(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.deleteOnClose) ;
    } else {
        theWindow.deleteOnClose = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:darkMode([state]) -> bool
/// Method
/// Set or display whether or not the `hs.webview` window should display in dark mode.
///
/// Parameters:
///  * `state` - an optional boolean which will set whether or not the `hs.webview` window should display in dark mode.
///
/// Returns:
///  * A boolean, `true` if dark mode is enabled otherwise `false`.
static int webview_darkMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.darkMode) ;
    } else {
        theWindow.darkMode = (BOOL) lua_toboolean(L, 2) ;
        if (theWindow.darkMode) {
            theWindow.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantDark] ;
        }
        else
        {
            theWindow.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantLight] ;
        }
        lua_settop(L, 1) ;
    }
    return 1;
}

/// hs.webview:closeOnEscape([flag]) -> webviewObject | current value
/// Method
/// If the webview is closable, this will get or set whether or not the Escape key is allowed to close the webview window.
///
/// Parameters:
///  * `flag` - an optional boolean value which indicates whether a webview, when it's style includes Closable (see `hs.webview:windowStyle`), should allow the Escape key to be a shortcut for closing the webview window.  Defaults to false.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
///
/// Notes:
///  * If this is set to true, Escape will only close the window if no other element responds to the Escape key first (e.g. if you are editing a text input field, the Escape will be captured by the text field, not by the webview Window.)
static int webview_closeOnEscape(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.closeOnEscape) ;
    } else {
        theWindow.closeOnEscape = (BOOL) lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

// this one is safe -- an `hs.webview` object *IS* a window, so this is simply a shortcut to other ways of capturing the window as an `hs.window` object.

/// hs.webview:hswindow() -> hs.window object
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    CGWindowID windowID = (CGWindowID)[theWindow windowNumber];

    [skin requireModule:"hs.window"] ;
    lua_getfield(L, -1, "windowForID") ;
    lua_pushinteger(L, windowID) ;
    lua_call(L, 1, 1) ;
    return 1 ;
}

/// hs.webview:isVisible() -> boolean
/// Method
/// Checks to see if a webview window is visible or not.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if the webview window is visible, otherwise `false`
static int webview_isVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    if (theWindow.isVisible) {
        lua_pushboolean(L, true);
    } else {
        lua_pushboolean(L, false);
    }
    return 1;
}

/// hs.webview:windowTitle([title]) -> webviewObject
/// Method
/// Sets the title for the webview window.
///
/// Parameters:
///  * `title` - if specified and not nil, the title to set for the webview window.  If this parameter is not present or is nil, the title will follow the title of the webview's content.
///
/// Returns:
///  * The webview Object
///
/// Notes:
///  * The title will be hidden unless the window style includes the "titled" style (see `hs.webview.windowStyle` and `hs.webview.windowMasks`)
static int webview_windowTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    if (lua_isnoneornil(L, 2)) {
        theWindow.titleFollow = YES ;
        NSString *windowTitle = [theWindow.contentView title] ? [theWindow.contentView title] : @"<no title>" ;
        [theWindow setTitle:windowTitle] ;
    } else {
        luaL_checktype(L, 2, LUA_TSTRING) ;
        theWindow.titleFollow = NO ;

        [theWindow setTitle:[skin toNSObjectAtIndex:2]] ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.webview:titleVisibility([state]) -> webviewObject | string
/// Function
/// Get or set whether or not the title text appears in the webview window.
///
/// Parameters:
///  * `state` - an optional string containing the text "visible" or "hidden", specifying whether or not the webview's title text appears when webview's window style includes "titled".
///
/// Returns:
///  * if a value is provided, returns the webview object; otherwise returns the current value.
///
/// Notes:
///  * See also [hs.webview:windowStyle](#windowStyle) and [hs.webview.windowMasks](#windowMasks).
///
///  * When a toolbar is attached to the webview, this function can be used to specify whether the Toolbar appears underneath the webview window's title ("visible") or in the window's title bar itself, as seen in applications like Safari ("hidden"). When the title is hidden, the toolbar will only display the toolbar items as icons without labels, and ignores changes made with `hs.webview.toolbar:displayMode`.
///
///  * If a toolbar is attached to the webview, you can achieve the same effect as this method with `hs.webview:attachedToolbar():inTitleBar(boolean)`
static int webview_titleVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    NSDictionary *mapping = @{
        @"visible" : @(NSWindowTitleVisible),
        @"hidden"  : @(NSWindowTitleHidden),
    } ;

    if (lua_gettop(L) == 1) {
        NSNumber *titleVisibility = @(theWindow.titleVisibility) ;
        NSString *value = [[mapping allKeysForObject:titleVisibility] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"unrecognized titleVisibility %@ -- notify developers", titleVisibility]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            theWindow.titleVisibility = [value intValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int webview_windowStyle(lua_State *L) {
// NOTE:  This method is wrapped in init.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
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

/// hs.webview:level([theLevel]) -> drawingObject | currentValue
/// Method
/// Get or set the window level
///
/// Parameters:
///  * `theLevel` - an optional parameter specifying the desired level as an integer, which can be obtained from `hs.drawing.windowLevels`.
///
/// Returns:
///  * if a parameter is specified, returns the webview object, otherwise the current value
///
/// Notes:
///  * see the notes for `hs.drawing.windowLevels`
static int webview_level(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG);

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, theWindow.level) ;
    } else {
        lua_Integer targetLevel = lua_tointeger(L, 2) ;

        if (targetLevel >= CGWindowLevelForKey(kCGMinimumWindowLevelKey) && targetLevel <= CGWindowLevelForKey(kCGMaximumWindowLevelKey)) {
            [theWindow setLevel:targetLevel] ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"window level must be between %d and %d inclusive",
                                   CGWindowLevelForKey(kCGMinimumWindowLevelKey),
                                   CGWindowLevelForKey(kCGMaximumWindowLevelKey)] UTF8String]) ;
        }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs.webview:bringToFront([aboveEverything]) -> webviewObject
/// Method
/// Places the drawing object on top of normal windows
///
/// Parameters:
///  * `aboveEverything` - An optional boolean value that controls how far to the front the webview should be placed. True to place the webview on top of all windows (including the dock and menubar and fullscreen windows), false to place the webview above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
///
/// Returns:
///  * The webview object
static int webview_bringToFront(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    theWindow.level = lua_toboolean(L, 2) ? NSScreenSaverWindowLevel : NSFloatingWindowLevel ;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:sendToBack() -> webviewObject
/// Method
/// Places the webview object behind normal windows, between the desktop wallpaper and desktop icons
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int webview_sendToBack(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    theWindow.level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview:alpha([alpha]) -> webviewObject | currentValue
/// Method
/// Get or set the alpha level of the window containing the hs.webview object.
///
/// Parameters:
///  * `alpha` - an optional number between 0.0 and 1.0 specifying the new alpha level for the webview.
///
/// Returns:
///  * If a parameter is provided, returns the webview object; otherwise returns the current value.
static int webview_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, theWindow.alphaValue) ;
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        theWindow.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        lua_settop(L, 1);
    }
    return 1 ;
}

/// hs.webview:shadow([value]) -> webviewObject | current value
/// Method
/// Get or set whether or not the webview window has shadows. Default to false.
///
/// Parameters:
///  * `value` - an optional boolean value indicating whether or not the webview should have shadows.
///
/// Returns:
///  * If a value is provided, then this method returns the webview object; otherwise the current value
static int webview_shadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushboolean(L, theWindow.hasShadow);
    } else {
        theWindow.hasShadow = (BOOL)lua_toboolean(L, 2);
        lua_settop(L, 1);
    }
    return 1 ;
}

static int webview_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK | LS_TVARARG] ;

    HSWebViewWindow *theWindow = [skin luaObjectAtIndex:1 toClass:"HSWebViewWindow"] ;
    NSInteger       relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TUSERDATA, USERDATA_TAG,
                        LS_TBREAK] ;
        relativeTo = [[skin luaObjectAtIndex:2 toClass:"HSWebViewWindow"] windowNumber] ;
    }

    [theWindow orderWindow:mode relativeTo:relativeTo] ;

    lua_pushvalue(L, 1);
    return 1 ;
}

/// hs.webview:orderAbove([webview2]) -> webviewObject
/// Method
/// Moves webview object above webview2, or all webview objects in the same presentation level, if webview2 is not given.
///
/// Parameters:
///  * `webview2` -An optional webview object to place the webview object above.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * If the webview object and webview2 are not at the same presentation level, this method will will move the webview object as close to the desired relationship without changing the webview object's presentation level. See [hs.webview.level](#level).
static int webview_orderAbove(lua_State *L) {
    return webview_orderHelper(L, NSWindowAbove) ;
}

/// hs.webview:orderBelow([webview2]) -> webviewObject
/// Method
/// Moves webview object below webview2, or all webview objects in the same presentation level, if webview2 is not given.
///
/// Parameters:
///  * `webview2` -An optional webview object to place the webview object below.
///
/// Returns:
///  * The webview object
///
/// Notes:
///  * If the webview object and webview2 are not at the same presentation level, this method will will move the webview object as close to the desired relationship without changing the webview object's presentation level. See [hs.webview.level](#level).
static int webview_orderBelow(lua_State *L) {
    return webview_orderHelper(L, NSWindowBelow) ;
}

// NOTE: this function is wrapped in init.lua
static int webview_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = [skin luaObjectAtIndex:1 toClass:"HSWebViewWindow"] ;
    if ((lua_gettop(L) == 1) || (![theWindow isVisible])) {
        [theWindow close] ; // trigger callback, if set, then cleanup
        lua_pushcfunction(L, userdata_gc) ;
        lua_pushvalue(L, 1) ;
        // FIXME: Can we convert this lua_pcall() to a LuaSkin protectedCallAndError?
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    } else {
        [theWindow fadeOut:lua_tonumber(L, 2) andDelete:YES withState:L];
    }

    lua_pushnil(L);
    return 1;
}

/// hs.webview:behavior([behavior]) -> webviewObject | currentValue
/// Method
/// Get or set the window behavior settings for the webview object.
///
/// Parameters:
///  * `behavior` - an optional number representing the desired window behaviors for the webview object.
///
/// Returns:
///  * If an argument is provided, the webview object; otherwise the current value.
///
/// Notes:
///  * Window behaviors determine how the webview object is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
static int webview_behavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = [skin luaObjectAtIndex:1 toClass:"HSWebViewWindow"] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, [theWindow collectionBehavior]) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TNUMBER | LS_TINTEGER,
                        LS_TBREAK] ;

        NSInteger newLevel = lua_tointeger(L, 2);
        @try {
            [theWindow setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }

        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs.webview:windowCallback(fn) -> webviewObject
/// Method
/// Set or clear a callback for updates to the webview window
///
/// Parameters:
///  * `fn` - the function to be called when the webview window is moved or closed. Specify an explicit nil to clear the current callback.  The function should expect 2 or 3 arguments and return none.  The arguments will be one of the following:
///
///    * "closing", webview - specifies that the webview window is being closed, either by the user or with the [hs.webview:delete](#delete) method.
///      * `action`  - in this case "closing", specifying that the webview window is being closed
///      * `webview` - the webview that is being closed
///
///    * "focusChange", webview, state - indicates that the webview window has either become or stopped being the focused window
///      * `action`  - in this case "focusChange", specifying that the webview window is being closed
///      * `webview` - the webview that is being closed
///      * `state`   - a boolean, true if the webview has become the focused window, or false if it has lost focus
///
///    * "frameChange", webview, frame - indicates that the webview window has been moved or resized
///      * `action`  - in this case "focusChange", specifying that the webview window is being closed
///      * `webview` - the webview that is being closed
///      * `frame`   - a rect-table containing the new co-ordinates and size of the webview window
///
/// Returns:
///  * The webview object
static int webview_windowCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    theWindow.windowCallback = [skin luaUnref:refTable ref:theWindow.windowCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        theWindow.windowCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Module Constants

/// hs.webview.windowMasks[]
/// Constant
/// A table containing valid masks for the webview window.
///
/// Table Keys:
///  * `borderless`             - The window has no border decorations (default)
///  * `titled`                 - The window title bar is displayed
///  * `closable`               - The window has a close button
///  * `miniaturizable`         - The window has a minimize button
///  * `resizable`              - The window is resizable
///  * `texturedBackground`     - The window has a texturized background
///  * `fullSizeContentView`    - If titled, the titlebar is within the frame size specified at creation, not above it.  Shrinks actual content area by the size of the titlebar, if present.
///  * `utility`                - If titled, the window shows a utility panel titlebar (thinner than normal)
///  * `nonactivating`          - If the window is activated, it won't bring other Hammerspoon windows forward as well
///  * `HUD`                    - Requires utility; the window titlebar is shown dark and can only show the close button and title (if they are set)
///
/// Notes:
///  * The Maximize button in the window title is enabled when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.

//  * unifiedTitleAndToolbar - may be more useful if/when toolbar support is added.
//  * fullScreen             - I think because we're using NSPanel rather than NSWindow... may see about fixing later
//  * docModal               - We're not using this as a modal sheet or modal alert, so just sets some things we already override or don't use

static int webview_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSWindowStyleMaskBorderless) ;             lua_setfield(L, -2, "borderless") ;
    lua_pushinteger(L, NSWindowStyleMaskTitled) ;                 lua_setfield(L, -2, "titled") ;
    lua_pushinteger(L, NSWindowStyleMaskClosable) ;               lua_setfield(L, -2, "closable") ;
    lua_pushinteger(L, NSWindowStyleMaskMiniaturizable) ;         lua_setfield(L, -2, "miniaturizable") ;
    lua_pushinteger(L, NSWindowStyleMaskResizable) ;              lua_setfield(L, -2, "resizable") ;
    lua_pushinteger(L, NSWindowStyleMaskTexturedBackground) ;     lua_setfield(L, -2, "texturedBackground") ;
//       lua_pushinteger(L, NSUnifiedTitleAndToolbarWindowMask) ; lua_setfield(L, -2, "unifiedTitleAndToolbar") ;
//       lua_pushinteger(L, NSFullScreenWindowMask) ;             lua_setfield(L, -2, "fullScreen") ;
    lua_pushinteger(L, NSWindowStyleMaskFullSizeContentView) ;    lua_setfield(L, -2, "fullSizeContentView") ;
    lua_pushinteger(L, NSWindowStyleMaskUtilityWindow) ;                lua_setfield(L, -2, "utility") ;
//       lua_pushinteger(L, NSDocModalWindowMask) ;               lua_setfield(L, -2, "docModal") ;
    lua_pushinteger(L, NSWindowStyleMaskNonactivatingPanel) ;           lua_setfield(L, -2, "nonactivating") ;
    lua_pushinteger(L, NSWindowStyleMaskHUDWindow) ;                    lua_setfield(L, -2, "HUD") ;
    return 1 ;
}

/// hs.webview.certificateOIDs[]
/// Constant
/// A table of common OID values found in SSL certificates.  SSL certificates provided to the callback function for [hs.webview:sslCallback](#sslCallback) or in the results of [hs.webview:certificateChain](#certificateChain) use OID strings as the keys which describe the properties of the certificate and this table can be used to get a more common name for the keys you are most likely to see.
///
/// This list is based on the contents of OS X's /System/Library/Frameworks/Security.framework/Headers/SecCertificateOIDs.h.
static int webview_pushCertificateOIDs(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDADC_CERT_POLICY] ;                           lua_setfield(L, -2, "ADC_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_CERT_POLICY] ;                         lua_setfield(L, -2, "APPLE_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_CODE_SIGNING] ;                    lua_setfield(L, -2, "APPLE_EKU_CODE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_CODE_SIGNING_DEV] ;                lua_setfield(L, -2, "APPLE_EKU_CODE_SIGNING_DEV") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_ICHAT_ENCRYPTION] ;                lua_setfield(L, -2, "APPLE_EKU_ICHAT_ENCRYPTION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_ICHAT_SIGNING] ;                   lua_setfield(L, -2, "APPLE_EKU_ICHAT_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_RESOURCE_SIGNING] ;                lua_setfield(L, -2, "APPLE_EKU_RESOURCE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EKU_SYSTEM_IDENTITY] ;                 lua_setfield(L, -2, "APPLE_EKU_SYSTEM_IDENTITY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION] ;                           lua_setfield(L, -2, "APPLE_EXTENSION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ADC_APPLE_SIGNING] ;         lua_setfield(L, -2, "APPLE_EXTENSION_ADC_APPLE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ADC_DEV_SIGNING] ;           lua_setfield(L, -2, "APPLE_EXTENSION_ADC_DEV_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_APPLE_SIGNING] ;             lua_setfield(L, -2, "APPLE_EXTENSION_APPLE_SIGNING") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_CODE_SIGNING] ;              lua_setfield(L, -2, "APPLE_EXTENSION_CODE_SIGNING") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_INTERMEDIATE_MARKER] ;       lua_setfield(L, -2, "APPLE_EXTENSION_INTERMEDIATE_MARKER") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_WWDR_INTERMEDIATE] ;         lua_setfield(L, -2, "APPLE_EXTENSION_WWDR_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_ITMS_INTERMEDIATE] ;         lua_setfield(L, -2, "APPLE_EXTENSION_ITMS_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_AAI_INTERMEDIATE] ;          lua_setfield(L, -2, "APPLE_EXTENSION_AAI_INTERMEDIATE") ;
//     [skin pushNSObject:(__bridge NSString *)kSecOIDAPPLE_EXTENSION_APPLEID_INTERMEDIATE] ;      lua_setfield(L, -2, "APPLE_EXTENSION_APPLEID_INTERMEDIATE") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAuthorityInfoAccess] ;                       lua_setfield(L, -2, "authorityInfoAccess") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDAuthorityKeyIdentifier] ;                    lua_setfield(L, -2, "authorityKeyIdentifier") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDBasicConstraints] ;                          lua_setfield(L, -2, "basicConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDBiometricInfo] ;                             lua_setfield(L, -2, "biometricInfo") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCSSMKeyStruct] ;                             lua_setfield(L, -2, "CSSMKeyStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCertIssuer] ;                                lua_setfield(L, -2, "certIssuer") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCertificatePolicies] ;                       lua_setfield(L, -2, "certificatePolicies") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDClientAuth] ;                                lua_setfield(L, -2, "clientAuth") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCollectiveStateProvinceName] ;               lua_setfield(L, -2, "collectiveStateProvinceName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCollectiveStreetAddress] ;                   lua_setfield(L, -2, "collectiveStreetAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCommonName] ;                                lua_setfield(L, -2, "commonName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCountryName] ;                               lua_setfield(L, -2, "countryName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlDistributionPoints] ;                     lua_setfield(L, -2, "crlDistributionPoints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlNumber] ;                                 lua_setfield(L, -2, "crlNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDCrlReason] ;                                 lua_setfield(L, -2, "crlReason") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EMAIL_ENCRYPT] ;                 lua_setfield(L, -2, "DOTMAC_CERT_EMAIL_ENCRYPT") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EMAIL_SIGN] ;                    lua_setfield(L, -2, "DOTMAC_CERT_EMAIL_SIGN") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_EXTENSION] ;                     lua_setfield(L, -2, "DOTMAC_CERT_EXTENSION") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_IDENTITY] ;                      lua_setfield(L, -2, "DOTMAC_CERT_IDENTITY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDOTMAC_CERT_POLICY] ;                        lua_setfield(L, -2, "DOTMAC_CERT_POLICY") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDeltaCrlIndicator] ;                         lua_setfield(L, -2, "deltaCrlIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDDescription] ;                               lua_setfield(L, -2, "description") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEKU_IPSec] ;                                 lua_setfield(L, -2, "EKU_IPSec") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEmailAddress] ;                              lua_setfield(L, -2, "emailAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDEmailProtection] ;                           lua_setfield(L, -2, "emailProtection") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedKeyUsage] ;                          lua_setfield(L, -2, "extendedKeyUsage") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedKeyUsageAny] ;                       lua_setfield(L, -2, "extendedKeyUsageAny") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDExtendedUseCodeSigning] ;                    lua_setfield(L, -2, "extendedUseCodeSigning") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDGivenName] ;                                 lua_setfield(L, -2, "givenName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDHoldInstructionCode] ;                       lua_setfield(L, -2, "holdInstructionCode") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDInvalidityDate] ;                            lua_setfield(L, -2, "invalidityDate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuerAltName] ;                             lua_setfield(L, -2, "issuerAltName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuingDistributionPoint] ;                  lua_setfield(L, -2, "issuingDistributionPoint") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDIssuingDistributionPoints] ;                 lua_setfield(L, -2, "issuingDistributionPoints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKERBv5_PKINIT_KP_CLIENT_AUTH] ;              lua_setfield(L, -2, "KERBv5_PKINIT_KP_CLIENT_AUTH") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKERBv5_PKINIT_KP_KDC] ;                      lua_setfield(L, -2, "KERBv5_PKINIT_KP_KDC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDKeyUsage] ;                                  lua_setfield(L, -2, "keyUsage") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDLocalityName] ;                              lua_setfield(L, -2, "localityName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDMS_NTPrincipalName] ;                        lua_setfield(L, -2, "MS_NTPrincipalName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDMicrosoftSGC] ;                              lua_setfield(L, -2, "microsoftSGC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNameConstraints] ;                           lua_setfield(L, -2, "nameConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeCertSequence] ;                      lua_setfield(L, -2, "netscapeCertSequence") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeCertType] ;                          lua_setfield(L, -2, "netscapeCertType") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDNetscapeSGC] ;                               lua_setfield(L, -2, "netscapeSGC") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOCSPSigning] ;                               lua_setfield(L, -2, "OCSPSigning") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOrganizationName] ;                          lua_setfield(L, -2, "organizationName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDOrganizationalUnitName] ;                    lua_setfield(L, -2, "organizationalUnitName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPolicyConstraints] ;                         lua_setfield(L, -2, "policyConstraints") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPolicyMappings] ;                            lua_setfield(L, -2, "policyMappings") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDPrivateKeyUsagePeriod] ;                     lua_setfield(L, -2, "privateKeyUsagePeriod") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDQC_Statements] ;                             lua_setfield(L, -2, "QC_Statements") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSerialNumber] ;                              lua_setfield(L, -2, "serialNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDServerAuth] ;                                lua_setfield(L, -2, "serverAuth") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDStateProvinceName] ;                         lua_setfield(L, -2, "stateProvinceName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDStreetAddress] ;                             lua_setfield(L, -2, "streetAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectAltName] ;                            lua_setfield(L, -2, "subjectAltName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectDirectoryAttributes] ;                lua_setfield(L, -2, "subjectDirectoryAttributes") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectEmailAddress] ;                       lua_setfield(L, -2, "subjectEmailAddress") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectInfoAccess] ;                         lua_setfield(L, -2, "subjectInfoAccess") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectKeyIdentifier] ;                      lua_setfield(L, -2, "subjectKeyIdentifier") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectPicture] ;                            lua_setfield(L, -2, "subjectPicture") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSubjectSignatureBitmap] ;                    lua_setfield(L, -2, "subjectSignatureBitmap") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSurname] ;                                   lua_setfield(L, -2, "surname") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDTimeStamping] ;                              lua_setfield(L, -2, "timeStamping") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDTitle] ;                                     lua_setfield(L, -2, "title") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDUseExemptions] ;                             lua_setfield(L, -2, "useExemptions") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1CertificateIssuerUniqueId] ;           lua_setfield(L, -2, "X509V1CertificateIssuerUniqueId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1CertificateSubjectUniqueId] ;          lua_setfield(L, -2, "X509V1CertificateSubjectUniqueId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerName] ;                          lua_setfield(L, -2, "X509V1IssuerName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameCStruct] ;                   lua_setfield(L, -2, "X509V1IssuerNameCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameLDAP] ;                      lua_setfield(L, -2, "X509V1IssuerNameLDAP") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1IssuerNameStd] ;                       lua_setfield(L, -2, "X509V1IssuerNameStd") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SerialNumber] ;                        lua_setfield(L, -2, "X509V1SerialNumber") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1Signature] ;                           lua_setfield(L, -2, "X509V1Signature") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithm] ;                  lua_setfield(L, -2, "X509V1SignatureAlgorithm") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithmParameters] ;        lua_setfield(L, -2, "X509V1SignatureAlgorithmParameters") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureAlgorithmTBS] ;               lua_setfield(L, -2, "X509V1SignatureAlgorithmTBS") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureCStruct] ;                    lua_setfield(L, -2, "X509V1SignatureCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SignatureStruct] ;                     lua_setfield(L, -2, "X509V1SignatureStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectName] ;                         lua_setfield(L, -2, "X509V1SubjectName") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameCStruct] ;                  lua_setfield(L, -2, "X509V1SubjectNameCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameLDAP] ;                     lua_setfield(L, -2, "X509V1SubjectNameLDAP") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectNameStd] ;                      lua_setfield(L, -2, "X509V1SubjectNameStd") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKey] ;                    lua_setfield(L, -2, "X509V1SubjectPublicKey") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyAlgorithm] ;           lua_setfield(L, -2, "X509V1SubjectPublicKeyAlgorithm") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyAlgorithmParameters] ; lua_setfield(L, -2, "X509V1SubjectPublicKeyAlgorithmParameters") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1SubjectPublicKeyCStruct] ;             lua_setfield(L, -2, "X509V1SubjectPublicKeyCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1ValidityNotAfter] ;                    lua_setfield(L, -2, "X509V1ValidityNotAfter") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1ValidityNotBefore] ;                   lua_setfield(L, -2, "X509V1ValidityNotBefore") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V1Version] ;                             lua_setfield(L, -2, "X509V1Version") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3Certificate] ;                         lua_setfield(L, -2, "X509V3Certificate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateCStruct] ;                  lua_setfield(L, -2, "X509V3CertificateCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionCStruct] ;         lua_setfield(L, -2, "X509V3CertificateExtensionCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionCritical] ;        lua_setfield(L, -2, "X509V3CertificateExtensionCritical") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionId] ;              lua_setfield(L, -2, "X509V3CertificateExtensionId") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionStruct] ;          lua_setfield(L, -2, "X509V3CertificateExtensionStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionType] ;            lua_setfield(L, -2, "X509V3CertificateExtensionType") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionValue] ;           lua_setfield(L, -2, "X509V3CertificateExtensionValue") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionsCStruct] ;        lua_setfield(L, -2, "X509V3CertificateExtensionsCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateExtensionsStruct] ;         lua_setfield(L, -2, "X509V3CertificateExtensionsStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3CertificateNumberOfExtensions] ;       lua_setfield(L, -2, "X509V3CertificateNumberOfExtensions") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3SignedCertificate] ;                   lua_setfield(L, -2, "X509V3SignedCertificate") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDX509V3SignedCertificateCStruct] ;            lua_setfield(L, -2, "X509V3SignedCertificateCStruct") ;
    [skin pushNSObject:(__bridge NSString *)kSecOIDSRVName] ;                                   lua_setfield(L, -2, "SRVName") ;
    return 1;
}

#pragma mark - NS<->lua conversion tools

static id luaTo_HSWebViewWindow(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSWebViewWindow *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSWebViewWindow, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int HSWebViewWindow_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKNavigationAction *navAction = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[navAction request]] ;      lua_setfield(L, -2, "request") ;
      [skin pushNSObject:[navAction sourceFrame]] ;  lua_setfield(L, -2, "sourceFrame") ;
      [skin pushNSObject:[navAction targetFrame]] ;  lua_setfield(L, -2, "targetFrame") ;
      lua_pushinteger(L, [navAction buttonNumber]) ; lua_setfield(L, -2, "buttonNumber") ;
      unsigned long theFlags = [navAction modifierFlags] ;
      lua_newtable(L) ;
    if (theFlags & NSEventModifierFlagCapsLock) { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "capslock") ; }
    if (theFlags & NSEventModifierFlagShift)      { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "shift") ; }
    if (theFlags & NSEventModifierFlagControl)    { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "ctrl") ; }
    if (theFlags & NSEventModifierFlagOption)  { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "alt") ; }
    if (theFlags & NSEventModifierFlagCommand)    { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "cmd") ; }
    if (theFlags & NSEventModifierFlagFunction)   { lua_pushboolean(L, YES) ; lua_setfield(L, -2, "fn") ; }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKNavigationResponse *navResponse = obj ;

    lua_newtable(L) ;
      lua_pushboolean(L, [navResponse canShowMIMEType]) ; lua_setfield(L, -2, "canShowMIMEType") ;
      lua_pushboolean(L, [navResponse isForMainFrame]) ;  lua_setfield(L, -2, "forMainFrame") ;
      [skin pushNSObject:[navResponse response]] ;        lua_setfield(L, -2, "response") ;
    return 1 ;
}

static int WKFrameInfo_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKFrameInfo *frameInfo = obj ;

    lua_newtable(L) ;
    lua_pushboolean(L, frameInfo.mainFrame) ; lua_setfield(L, -2, "mainFrame") ;
    [skin pushNSObject:frameInfo.request] ;     lua_setfield(L, -2, "request") ;
    if (NSClassFromString(@"WKSecurityOrigin") && [frameInfo respondsToSelector:@selector(securityOrigin)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [skin pushNSObject:frameInfo.securityOrigin] ; lua_setfield(L, -2, "securityOrigin") ;
#pragma clang diagnostic pop
    }
    return 1 ;
}

static int WKBackForwardListItem_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKBackForwardListItem *item = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:[item URL]] ;        lua_setfield(L, -2, "URL") ;
      [skin pushNSObject:[item initialURL]] ; lua_setfield(L, -2, "initialURL") ;
      [skin pushNSObject:[item title]] ;      lua_setfield(L, -2, "title") ;
    return 1 ;
}

static int WKBackForwardList_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    lua_pushstring(L, [[NSString stringWithFormat:@"0x%p", (void *)navID] UTF8String]) ;
    return 1 ;
}

static int NSError_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSError *theError = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [theError code]) ;                        lua_setfield(L, -2, "code") ;
        [skin pushNSObject:[theError domain]] ;                      lua_setfield(L, -2, "domain") ;
        [skin pushNSObject:[theError helpAnchor]] ;                  lua_setfield(L, -2, "helpAnchor") ;
        [skin pushNSObject:[theError localizedDescription]] ;        lua_setfield(L, -2, "localizedDescription") ;
        [skin pushNSObject:[theError localizedRecoveryOptions]] ;    lua_setfield(L, -2, "localizedRecoveryOptions") ;
        [skin pushNSObject:[theError localizedRecoverySuggestion]] ; lua_setfield(L, -2, "localizedRecoverySuggestion") ;
        [skin pushNSObject:[theError localizedFailureReason]] ;      lua_setfield(L, -2, "localizedFailureReason") ;
#ifdef _WK_DEBUG
        [skin pushNSObject:[theError userInfo] withOptions:LS_NSDescribeUnknownTypes] ;                    lua_setfield(L, -2, "userInfo") ;
#endif
    return 1 ;
}

static int WKWindowFeatures_toLua(lua_State *L, id obj) {
    WKWindowFeatures *features = obj ;

    lua_newtable(L) ;
      if (features.menuBarVisibility) {
          lua_pushboolean(L, [features.menuBarVisibility boolValue]) ;
          lua_setfield(L, -2, "menuBarVisibility") ;
      }
      if (features.statusBarVisibility) {
          lua_pushboolean(L, [features.statusBarVisibility boolValue]) ;
          lua_setfield(L, -2, "statusBarVisibility") ;
      }
      if (features.toolbarsVisibility) {
          lua_pushboolean(L, [features.toolbarsVisibility boolValue]) ;
          lua_setfield(L, -2, "toolbarsVisibility") ;
      }
      if (features.allowsResizing) {
          lua_pushboolean(L, [features.allowsResizing boolValue]) ;
          lua_setfield(L, -2, "allowsResizing") ;
      }
      if (features.x) {
          lua_pushnumber(L, [features.x doubleValue]) ;
          lua_setfield(L, -2, "x") ;
      }
      if (features.y) {
          lua_pushnumber(L, [features.y doubleValue]) ;
          lua_setfield(L, -2, "y") ;
      }
      if (features.height) {
          lua_pushnumber(L, [features.height doubleValue]) ;
          lua_setfield(L, -2, "h") ;
      }
      if (features.width) {
          lua_pushnumber(L, [features.width doubleValue]) ;
          lua_setfield(L, -2, "w") ;
      }

    return 1 ;
}

static int NSURLAuthenticationChallenge_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURLAuthenticationChallenge *challenge = obj ;

    lua_newtable(L) ;
        lua_pushinteger(L, [challenge previousFailureCount]) ; lua_setfield(L, -2, "previousFailureCount") ;
        [skin pushNSObject:[challenge error]] ;                lua_setfield(L, -2, "error") ;
        [skin pushNSObject:[challenge failureResponse]] ;      lua_setfield(L, -2, "failureResponse") ;
        [skin pushNSObject:[challenge proposedCredential]] ;   lua_setfield(L, -2, "proposedCredential") ;
        [skin pushNSObject:[challenge protectionSpace]] ;      lua_setfield(L, -2, "protectionSpace") ;

    return 1 ;
}

static int SecCertificateRef_toLua(lua_State *L, SecCertificateRef certRef) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    CFStringRef commonName = NULL ;
    SecCertificateCopyCommonName(certRef, &commonName);
    if (commonName) {
        [skin pushNSObject:(__bridge NSString *)commonName] ; lua_setfield(L, -2, "commonName") ;
        CFRelease(commonName);
    }
    CFDictionaryRef values = SecCertificateCopyValues(certRef, NULL, NULL);
    if (values) {
        [skin pushNSObject:(__bridge NSDictionary *)values withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "values") ;
        CFRelease(values) ;
    }
    return 1 ;
}

static int NSURLProtectionSpace_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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

        SecTrustRef serverTrust = [theSpace serverTrust] ;
        if (serverTrust) {
            lua_newtable(L) ;
            SecTrustResultType secResult;
            SecTrustEvaluate(serverTrust, &secResult);
            CFIndex count = SecTrustGetCertificateCount(serverTrust);
            for (CFIndex idx = 0 ; idx < count ; idx++) {
                SecCertificateRef_toLua(L, SecTrustGetCertificateAtIndex(serverTrust, idx)) ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            lua_setfield(L, -2, "certificates") ;
        }

    return 1 ;
}

static int NSURLCredential_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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

// // if we ever support client certificates, this may become important. until then...
//         [skin pushNSObject:[credential certificates]] ; lua_setfield(L, -2, "certificates") ;
//         lua_pushstring([skin L], [[NSString stringWithFormat:@"0x%p", (void *)[credential identity]] UTF8String]) ;
//         lua_setfield(L, -2, "identity") ;

    return 1 ;
}

static int WKSecurityOrigin_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    WKSecurityOrigin *origin = obj ;
#pragma clang diagnostic pop

    lua_newtable(L) ;
    [skin pushNSObject:origin.host] ;     lua_setfield(L, -2, "host") ;
    lua_pushinteger(L, origin.port) ;     lua_setfield(L, -2, "port") ;
    [skin pushNSObject:origin.protocol] ; lua_setfield(L, -2, "protocol") ;
    return 1 ;
}

#pragma mark - Lua Framework Stuff

static int userdata_tostring(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView = theWindow.contentView ;
    NSString *title ;

    if (theWindow) { title = [theView title] ; } else { title = @"<deleted>" ; }
    if (!title) { title = @"" ; }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewWindow *otherWindow = get_objectFromUserdata(__bridge HSWebViewWindow, L, 2, USERDATA_TAG) ;

    lua_pushboolean(L, theWindow.udRef == otherWindow.udRef) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    if (!luaL_testudata(L, 1, USERDATA_TAG)) return 0 ;

    HSWebViewWindow *theWindow = get_objectFromUserdata(__bridge_transfer HSWebViewWindow, L, 1, USERDATA_TAG) ;
    HSWebViewView   *theView   = theWindow.contentView ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    if (theWindow) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        theWindow.udRef            = [skin luaUnref:refTable ref:theWindow.udRef] ;
        theWindow.windowCallback   = [skin luaUnref:refTable ref:theWindow.windowCallback] ;
        theView.navigationCallback = [skin luaUnref:refTable ref:theView.navigationCallback] ;
        theView.policyCallback     = [skin luaUnref:refTable ref:theView.policyCallback] ;

        if (theWindow.toolbar) {
            theWindow.toolbar.visible = NO ;
            theWindow.toolbar = nil ;
        }

        [theWindow close] ; // ensure a proper close when gc invoked during reload; nop if hs.webview:delete() is used

        // emancipate us from our parent
        if (theWindow.parent) {
            [theWindow.parent.children removeObject:theWindow] ;
            theWindow.parent = nil ;
        }

        // orphan our children
        for(HSWebViewWindow *child in theWindow.children) {
            child.parent = nil ;
        }

        NSTimer *reloadTimer = [delayTimers objectForKey:theView] ;
        if (reloadTimer) {
            [reloadTimer invalidate] ;
            [delayTimers removeObjectForKey:theView] ;
            reloadTimer = nil ;
        }

        theView.navigationDelegate = nil ;
        theView.UIDelegate         = nil ;
        theWindow.contentView      = nil ;
        theView                    = nil ;

        LSGCCanary tmpLSUUID           = theWindow.lsCanary;
        [skin destroyGCCanary:&tmpLSUUID];
        theWindow.lsCanary      = tmpLSUUID;

        theWindow.delegate         = nil ;
        theWindow                  = nil;
    }

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    if (HSWebViewProcessPool) {
        HSWebViewProcessPool = nil ;
    }

    if (delayTimers) {
        NSEnumerator *enumerator = [delayTimers objectEnumerator];
        NSTimer *timer ;
        while ((timer = [enumerator nextObject])) [timer invalidate] ;
        [delayTimers removeAllObjects] ;
    }
    delayTimers = nil ;

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
    {"transparent",                webview_transparent},
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
    {"sslCallback",                webview_sslCallback},
    {"children",                   webview_children},
    {"parent",                     webview_parent},
    {"evaluateJavaScript",         webview_evaluateJavaScript},
    {"privateBrowsing",            webview_privateBrowsing},
    {"userAgent",                  webview_userAgent},
    {"certificateChain",           webview_certificateChain},

    {"examineInvalidCertificates", webview_examineInvalidCertificates},
#ifdef _WK_DEBUG
    {"preferences",                webview_preferences},
#endif

    // Window related
    {"darkMode",                   webview_darkMode},

    {"titleVisibility",            webview_titleVisibility},
    {"show",                       webview_show},
    {"hide",                       webview_hide},
    {"closeOnEscape",              webview_closeOnEscape},
    {"allowTextEntry",             webview_allowTextEntry},
    {"hswindow",                   webview_hswindow} ,
    {"windowTitle",                webview_windowTitle},
    {"deleteOnClose",              webview_deleteOnClose},
    {"bringToFront",               webview_bringToFront},
    {"sendToBack",                 webview_sendToBack},
    {"shadow",                     webview_shadow},
    {"alpha",                      webview_alpha},
    {"orderAbove",                 webview_orderAbove},
    {"orderBelow",                 webview_orderBelow},
    {"behavior",                   webview_behavior},
    {"windowCallback",             webview_windowCallback},
    {"topLeft",                    webview_topLeft},
    {"size",                       webview_size},
    {"isVisible",                  webview_isVisible},

    {"_delete",                    webview_delete},
    {"_windowStyle",               webview_windowStyle},

    {"level",                      webview_level},

    {"__tostring",                 userdata_tostring},
    {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",              webview_new},

    {NULL,       NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_webview_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (!NSClassFromString(@"WKWebView")) {
        [skin logError:[NSString stringWithFormat:@"%s requires WKWebView support, found in OS X 10.10 or newer", USERDATA_TAG]] ;
        // nil gets interpreted as "nothing" and thus "true" by require...
        lua_pushboolean(L, NO) ;
    } else {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                                     functions:moduleLib
                                                 metaFunctions:module_metaLib
                                               objectFunctions:userdata_metaLib];

        // module userdata specific conversions
        [skin registerPushNSHelper:HSWebViewWindow_toLua              forClass:"HSWebViewWindow"] ;
        [skin registerLuaObjectHelper:luaTo_HSWebViewWindow           forClass:"HSWebViewWindow"
                                                           withUserdataMapping:USERDATA_TAG] ;


        // classes used primarily (solely?) by this module
        [skin registerPushNSHelper:WKBackForwardListItem_toLua        forClass:"WKBackForwardListItem"] ;
        [skin registerPushNSHelper:WKBackForwardList_toLua            forClass:"WKBackForwardList"] ;
        [skin registerPushNSHelper:WKNavigationAction_toLua           forClass:"WKNavigationAction"] ;
        [skin registerPushNSHelper:WKNavigationResponse_toLua         forClass:"WKNavigationResponse"] ;
        [skin registerPushNSHelper:WKFrameInfo_toLua                  forClass:"WKFrameInfo"] ;
        [skin registerPushNSHelper:WKNavigation_toLua                 forClass:"WKNavigation"] ;
        [skin registerPushNSHelper:WKWindowFeatures_toLua             forClass:"WKWindowFeatures"] ;

        if (NSClassFromString(@"WKSecurityOrigin")) {
            [skin registerPushNSHelper:WKSecurityOrigin_toLua             forClass:"WKSecurityOrigin"] ;
        }

        // classes that may find a better home elsewhere someday... (hs.http perhaps)
        [skin registerPushNSHelper:NSURLAuthenticationChallenge_toLua forClass:"NSURLAuthenticationChallenge"] ;
        [skin registerPushNSHelper:NSURLProtectionSpace_toLua         forClass:"NSURLProtectionSpace"] ;
        [skin registerPushNSHelper:NSURLCredential_toLua              forClass:"NSURLCredential"] ;

        webview_windowMasksTable(L) ;    lua_setfield(L, -2, "windowMasks") ;
        webview_pushCertificateOIDs(L) ; lua_setfield(L, -2, "certificateOIDs") ;

    }
    return 1;
}
