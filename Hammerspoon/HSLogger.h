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

#ifdef SENTRY_API_URL
#   pragma message "BUILD NOTE: Sentry API URL available"
#   define HSNSLOG(__FORMAT__, ...) [LuaSkin logBreadcrumb:[NSString stringWithFormat:__FORMAT__, ##__VA_ARGS__]];
#else
#   pragma message "BUILD NOTE: Sentry API URL unavailable"
#   define HSNSLOG(__FORMAT__, ...) NSLog(__FORMAT__, ##__VA_ARGS__)
#endif

@interface HSLogger : NSObject <LuaSkinDelegate> {
    lua_State *_L;
}

@property (atomic, readonly) lua_State *L;

- (instancetype)initWithLua:(lua_State *)L;
- (void)setLuaState:(lua_State *)L;
- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage;
- (void)logBreadcrumb:(NSString *)format, ...;
- (void)logKnownBug:(NSString *)format, ...;
@end
