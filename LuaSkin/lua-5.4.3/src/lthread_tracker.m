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
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    [skin trackThread:L];
}

void skin_untrack_thread(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    [skin untrackThread:L];
}

BOOL skin_is_thread_tracker(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    return [skin isThreadTracked:L];
}
