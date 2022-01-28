//
//  HSLogger.m
//  Hammerspoon
//
//  Created by Chris Jones on 22/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HSLogger.h"

@implementation HSLogger

@synthesize L = _L ;

- (instancetype)initWithLua:(lua_State *)L {
    self = [super init] ;
    if (self) {
        _L = L ;
    }
    return self ;
}

- (void)setLuaState:(lua_State *)L {
    _L = L;
}

// VERY IMPORTANT NOTE: DO NOT CALL HSNSLOG() IN THIS METHOD.
- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage {
    // If we haven't been given a lua_State object yet, log locally
    if (!_L) {
        [self logBreadcrumb:@"%@", theMessage];
        return;
    }

    // Send logs to the appropriate location, depending on their level
    // Note that hs.handleLogMessage also does this kind of filtering. We are special casing here for LS_LOG_BREADCRUMB to entirely bypass calling into Lua
    // (because such logs don't need to be shown to the user, just stored in our crashlog in case we crash)
    switch (level) {
        case LS_LOG_BREADCRUMB:
            [self logBreadcrumb:@"%@", theMessage];
            break;

        // Capture anything that isn't verbose/debug logging, in Sentry
        // These intentionally fall through to default.
        case LS_LOG_ERROR:
        case LS_LOG_WARN:
        case LS_LOG_INFO:
            [self logBreadcrumb:@"%@", theMessage];
        default:
            lua_getglobal(_L, "hs") ; lua_getfield(_L, -1, "handleLogMessage") ; lua_remove(_L, -2) ;
            lua_pushinteger(_L, level) ;
            lua_pushstring(_L, [theMessage UTF8String]) ;
            int errState = lua_pcall(_L, 2, 0, 0) ;
            if (errState != LUA_OK) {
                NSArray *stateLabels = @[ @"OK", @"YIELD", @"ERRRUN", @"ERRSYNTAX", @"ERRMEM", @"ERRGCMM", @"ERRERR" ] ;
                [self logBreadcrumb:@"logForLuaSkin: error, state %@: %s", [stateLabels objectAtIndex:(NSUInteger)errState],
                        luaL_tolstring(_L, -1, NULL)] ;
                lua_pop(_L, 2) ; // lua_pcall error + converted string from luaL_tolstring
            }
            break;
    }
}

- (void)handleCatastrophe:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    alert.informativeText = @"Hammerspoon critical error.";
    [alert addButtonWithTitle:@"Quit"];
    [alert setAlertStyle:NSAlertStyleCritical];
    [alert runModal];
    exit(1);
}

- (void)logBreadcrumb:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    NSLog(@"BREADCRUMB: %@", message);
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] init];
    crumb.message = message;
    [SentrySDK addBreadcrumb:crumb];
}

- (void)logKnownBug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    NSLog(@"KNOWN BUG: %@", message);

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    event.message = [[SentryMessage alloc] initWithFormatted:message];

    [SentrySDK captureEvent:event];
}
@end
