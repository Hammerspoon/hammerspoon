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

- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage {
    // If we haven't been given a lua_State object yet, log locally
    if (!_L) {
        HSNSLOG(@"%@", theMessage);
        return;
    }

    // Send logs to the appropriate location, depending on their level
    // Note that hs.handleLogMessage also does this kind of filtering. We are special casing here for LS_LOG_BREADCRUMB to entirely bypass calling into Lua
    // (because such logs don't need to be shown to the user, just stored in our crashlog in case we crash)
    switch (level) {
        case LS_LOG_BREADCRUMB:
            HSNSLOG(@"%@", theMessage);
            break;

        default:
            lua_getglobal(_L, "hs") ; lua_getfield(_L, -1, "handleLogMessage") ; lua_remove(_L, -2) ;
            lua_pushinteger(_L, level) ;
            lua_pushstring(_L, [theMessage UTF8String]) ;
            int errState = lua_pcall(_L, 2, 0, 0) ;
            if (errState != LUA_OK) {
                NSArray *stateLabels = @[ @"OK", @"YIELD", @"ERRRUN", @"ERRSYNTAX", @"ERRMEM", @"ERRGCMM", @"ERRERR" ] ;
                HSNSLOG(@"logForLuaSkin: error, state %@: %s", [stateLabels objectAtIndex:(NSUInteger)errState],
                        luaL_tolstring(_L, -1, NULL)) ;
                lua_pop(_L, 2) ; // lua_pcall result + converted version from luaL_tolstring
            }
            break;
    }
}

@end
