//
//  HSExecuteLuaIntentHandler.h
//  Hammerspoon
//
//  Created by Chris Jones on 28/10/2021.
//  Copyright © 2021 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Intents;
@import LuaSkin;
#import "MJLua.h"
#import "HSExecuteLuaIntent.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSExecuteLuaIntentHandler<HSExecuteLuaIntentHandling> : NSObject
- (void)handleExecuteLua:(HSExecuteLuaIntent *)intent completion:(void (^)(HSExecuteLuaIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:)) API_AVAILABLE(macos(11.0));
- (void)resolveSourceForExecuteLua:(HSExecuteLuaIntent *)intent withCompletion:(void (^)(HSExecuteLuaSourceResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveSource(for:with:)) API_AVAILABLE(ios(13.0), macos(10.16), watchos(6.0));
@end

NS_ASSUME_NONNULL_END
