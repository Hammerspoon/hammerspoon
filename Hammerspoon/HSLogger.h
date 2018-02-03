//
//  HSLogger.h
//  Hammerspoon
//
//  Created by Chris Jones on 22/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import <LuaSkin/LuaSkin.h>
#import <Crashlytics/Crashlytics.h>

#ifdef CRASHLYTICS_API_KEY
#   ifdef CLS_LOG
#       define HSNSLOG(__FORMAT__, ...) CLSNSLog(__FORMAT__, ##__VA_ARGS__)
#   endif
#endif

#ifndef HSNSLOG
#   define HSNSLOG(__FORMAT__, ...) NSLog(__FORMAT__, ##__VA_ARGS__)
#endif

#define HSLOG HSNSLOG

@interface HSLogger : NSObject <LuaSkinDelegate> {
    lua_State *_L;
}

@property (atomic, readonly) lua_State *L;

- (instancetype)initWithLua:(lua_State *)L;
- (void)setLuaState:(lua_State *)L;
- (void) logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage;
@end
