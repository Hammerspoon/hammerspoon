//
//  HSLogger.h
//  Hammerspoon
//
//  Created by Chris Jones on 22/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import <LuaSkin/LuaSkin.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvariadic-macros"
#import "Sentry.h"
#pragma clang diagnostic pop

#import "secrets.h"

#ifndef DEBUG
#    ifdef SENTRY_API_URL
#       pragma message "BUILD NOTE: Sentry API URL available"
#       ifdef CLS_LOG
#           pragma message "BUILD NOTE: CLS_LOG defined"
#           define HSNSLOG(__FORMAT__, ...) CLSNSLog(__FORMAT__, ##__VA_ARGS__)
#           pragma message "BUILD NOTE: HSNSLOG DEFINED AS CLSNSLog()"
#       else
#           pragma message "BUILD NOTE: CLS_LOG undefined"
#       endif
#    else
#       pragma message "BUILD NOTE: Crashlytics API key unavailable"
#    endif
#endif

#ifndef HSNSLOG
#   define HSNSLOG(__FORMAT__, ...) NSLog(__FORMAT__, ##__VA_ARGS__)
#   pragma message "BUILD NOTE: HSNSLOG DEFINED AS NSLog()"
#endif

@interface HSLogger : NSObject <LuaSkinDelegate> {
    lua_State *_L;
}

@property (atomic, readonly) lua_State *L;

- (instancetype)initWithLua:(lua_State *)L;
- (void)setLuaState:(lua_State *)L;
- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage;
@end
