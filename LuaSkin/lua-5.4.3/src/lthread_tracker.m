//
//  lthread_tracker.m
//  lua
//
//  Created by Chris Jones on 18/03/2022.
//  Copyright © 2022 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lthread_tracker.h"

void skin_track_thread(lua_State *L) {
    NSLog(@"Tracking new Lua thread: %p", L);
    
    if (NSClassFromString(@"LuaSkin")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"LuaSkin.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            Class SkinClass = NSClassFromString(@"LuaSkin");
            id skin = [SkinClass performSelector:@selector(sharedWithState:)];
            
            NSMethodSignature *trackLuaThreadSig = [SkinClass instanceMethodSignatureForSelector:@selector(trackLuaThread:)];
            NSInvocation *trackLuaThreadInv = [NSInvocation invocationWithMethodSignature:trackLuaThreadSig];
            [trackLuaThreadInv setTarget:skin];
            [trackLuaThreadInv setSelector:@selector(trackLuaThread:)];
            [trackLuaThreadInv setArgument:L atIndex:2];
            [trackLuaThreadInv invoke];
#pragma clang diagnostic pop
        }
    }
}

void skin_untrack_thread(lua_State *L) {
    NSLog(@"Untracking old Lua thread: %p", L);
}

int skin_is_thread_tracker(lua_State *L) {
    NSLog(@"Currently unable to tell if the thread is tracked");
    return YES;
}
