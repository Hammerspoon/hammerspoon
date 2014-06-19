#import "lua/lauxlib.h"

@interface PHTimerDelegator : NSObject
@property (copy) dispatch_block_t fired;
@property NSTimer* timer;
@property int closureRef;
@end

@implementation PHTimerDelegator
- (void) fired:(NSTimer*)timer {
    self.fired();
}
@end

// args: [sec, fn]
// returns: []
int timer_doafter(lua_State* L) {
    double delayInSeconds = lua_tonumber(L, 1);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        lua_call(L, 0, 0);
        luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    });
    
    return 0;
}

// args: [timer]
// returns: [timer]
int timer_start(lua_State* L) {
    NSTimeInterval sec = (lua_getfield(L, 1, "seconds"), lua_tonumber(L, -1));
    int closureref = (lua_getfield(L, 1, "fn"), luaL_ref(L, LUA_REGISTRYINDEX));
    
    PHTimerDelegator* delegator = [[PHTimerDelegator alloc] init];
    delegator.closureRef = closureref;
    delegator.fired = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        lua_pcall(L, 0, 0, 0);
    };
    
    delegator.timer = [NSTimer scheduledTimerWithTimeInterval:sec target:delegator selector:@selector(fired:) userInfo:nil repeats:YES];
    
    // set the timer as a field
    lua_pushlightuserdata(L, (__bridge_retained void*)delegator);
    lua_setfield(L, 1, "__timer");
    
    // return the original arg, as a convenience to the user
    lua_pushvalue(L, 1);
    return 1;
}

// args: [timer]
// returns: [timer]
int timer_stop(lua_State* L) {
    lua_getfield(L, 1, "__timer");
    PHTimerDelegator* delegator = (__bridge_transfer PHTimerDelegator*)lua_touserdata(L, -1);
    
    [delegator.timer invalidate];
    delegator.timer = nil;
    luaL_unref(L, LUA_REGISTRYINDEX, delegator.closureRef);
    
    lua_pushvalue(L, 1);
    return 1;
}

// args: [(self), seconds, fn]
// returns: [timer]
int timer_new(lua_State* L) {
    lua_newtable(L);
    
    lua_pushvalue(L, 2);
    lua_setfield(L, -2, "seconds");
    
    lua_pushvalue(L, 3);
    lua_setfield(L, -2, "fn");
    
    if (luaL_newmetatable(L, "timer")) {
        lua_getglobal(L, "hydra");
        lua_getfield(L, -1, "timer");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1); // hydra-global
    }
    lua_setmetatable(L, -2);
    
    return 1;
}

static const luaL_Reg timerlib[] = {
    {"doafter", timer_doafter},
    {"start", timer_start},
    {"stop", timer_stop},
    {NULL, NULL}
};

static const luaL_Reg timerlib_meta[] = {
    {"__call", timer_new},
    {NULL, NULL}
};

int luaopen_timer(lua_State* L) {
    luaL_newlib(L, timerlib);
    
    luaL_newlib(L, timerlib_meta);
    lua_setmetatable(L, -2);
    
    return 1;
}
