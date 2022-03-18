//
//  lthread_tracker.h
//  lua
//
//  Created by Chris Jones on 18/03/2022.
//  Copyright © 2022 Hammerspoon. All rights reserved.
//

#ifndef lthread_tracker_h
#define lthread_tracker_h

#import "lstate.h"

void skin_track_thread(lua_State *L);
void skin_untrack_thread(lua_State *L);

#endif /* lthread_tracker_h */
