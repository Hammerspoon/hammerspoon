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

int timer_start(lua_State* L) {
    NSTimeInterval sec = lua_tonumber(L, 1);
    int closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    PHTimerDelegator* delegator = [[PHTimerDelegator alloc] init];
    delegator.closureRef = closureref;
    delegator.fired = ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, closureref);
        lua_pcall(L, 0, 0, 0);
    };
    
    delegator.timer = [NSTimer scheduledTimerWithTimeInterval:sec target:delegator selector:@selector(fired:) userInfo:nil repeats:YES];
    
    lua_pushlightuserdata(L, (__bridge_retained void*)delegator);
    return 1;
}

int timer_stop(lua_State* L) {
    PHTimerDelegator* delegator = (__bridge_transfer PHTimerDelegator*)lua_touserdata(L, 1);
    
    [delegator.timer invalidate];
    delegator.timer = nil;
    luaL_unref(L, LUA_REGISTRYINDEX, delegator.closureRef);
    
    return 0;
}
