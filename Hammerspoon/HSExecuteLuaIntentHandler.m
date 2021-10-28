//
//  HSExecuteLuaIntentHandler.m
//  Hammerspoon
//
//  Created by Chris Jones on 28/10/2021.
//  Copyright © 2021 Hammerspoon. All rights reserved.
//

#import "HSExecuteLuaIntentHandler.h"

@implementation HSExecuteLuaIntentHandler
-(void)handleExecuteLua:(HSExecuteLuaIntent *)intent completion:(void (^)(HSExecuteLuaIntentResponse * _Nonnull))completion {
    LuaSkin *skin = [LuaSkin sharedWithState:nil];
    int result = luaL_dostring(skin.L, intent.source.UTF8String);

    // FIXME: These should be returning more useful strings.
    if (result != LUA_OK) {
        completion([HSExecuteLuaIntentResponse failureIntentResponseWithError:[NSString stringWithUTF8String:lua_tostring(skin.L, -1)]]);
    } else {
        NSString *output = @"";
        if (lua_gettop(skin.L) > 0) {
            output = [NSString stringWithUTF8String:lua_tostring(skin.L, -1)];
        }
        completion([HSExecuteLuaIntentResponse successIntentResponseWithResult:output]);
    }
}

-(void)resolveSourceForExecuteLua:(HSExecuteLuaIntent *)intent withCompletion:(void (^)(HSExecuteLuaSourceResolutionResult * _Nonnull))completion {
    if (intent.source && (intent.source.length == 0)) {
        completion([HSExecuteLuaSourceResolutionResult unsupportedForReason:HSExecuteLuaSourceUnsupportedReasonNoLua]);
    } else {
        completion([HSExecuteLuaSourceResolutionResult successWithResolvedString:intent.source]);
    }
}
@end
