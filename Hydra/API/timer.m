#import "helpers.h"

/// === timer ===
///
/// Execute functions with various timing rules.

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


/// timer.doafter(sec, fn())
/// Runs the function after sec seconds.
static int timer_doafter(lua_State* L) {
    double delayInSeconds = luaL_checknumber(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        luaL_unref(L, LUA_REGISTRYINDEX, closureref);
    });
    
    return 0;
}

// args: [fn, sec]
// returns: [rawtimer]
static int timer_start(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    NSTimeInterval sec = luaL_checknumber(L, 2);
    lua_settop(L, 2); // just to be safe
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    PHTimerDelegator* delegator = [[PHTimerDelegator alloc] init];
    delegator.closureRef = closureref;
    delegator.fired = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    };
    
    delegator.timer = [NSTimer scheduledTimerWithTimeInterval:sec target:delegator selector:@selector(fired:) userInfo:nil repeats:YES];
    
    lua_pushlightuserdata(L, (__bridge_retained void*)delegator);
    return 1;
}

// args: [rawtimer]
// returns: []
static int timer_stop(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    PHTimerDelegator* delegator = (__bridge_transfer PHTimerDelegator*)lua_touserdata(L, 1);
    
    [delegator.timer invalidate];
    delegator.timer = nil;
    luaL_unref(L, LUA_REGISTRYINDEX, delegator.closureRef);
    delegator = nil;
    
    return 0;
}

static const luaL_Reg timerlib[] = {
    {"doafter", timer_doafter},
    {"_start", timer_start},
    {"_stop", timer_stop},
    {NULL, NULL}
};

int luaopen_timer(lua_State* L) {
    luaL_newlib(L, timerlib);
    return 1;
}
