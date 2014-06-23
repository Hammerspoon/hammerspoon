#import "hydra.h"

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

static hydradoc doc_timer_runonce = {
    "timer", "runonce", "api.timer.runonce(fn())",
    "Runs the function exactly once in the entire lifespan of Hydra; reset only when you quit/restart."
};

int timer_runonce(lua_State* L) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    });
    
    return 0;
}

static hydradoc doc_timer_doafter = {
    "timer", "doafter", "api.timer.doafter(sec, fn())",
    "Runs the function after sec seconds."
};

int timer_doafter(lua_State* L) {
    double delayInSeconds = lua_tonumber(L, 1);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
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
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
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

static const luaL_Reg timerlib[] = {
    {"runonce", timer_runonce},
    {"doafter", timer_doafter},
    {"_start", timer_start},
    {"_stop", timer_stop},
    {NULL, NULL}
};

int luaopen_timer(lua_State* L) {
    hydra_add_doc_group(L, "timer", "Execute functions with various timing rules.");
    hydra_add_doc_item(L, &doc_timer_runonce);
    hydra_add_doc_item(L, &doc_timer_doafter);
    
    luaL_newlib(L, timerlib);
    return 1;
}
