#import "helpers.h"
void push_luavalue_for_nsobject(lua_State* L, id obj);

/// applistener
///
/// Listen to notifications sent by other apps, and maybe send some yourself.

@interface HydraGlobalNotifyListener : NSObject
@property lua_State* L;
@property int fn;
@property int ref;
@end
@implementation HydraGlobalNotifyListener
- (void) heard:(NSNotification*)note {
    lua_State* L = self.L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    
    lua_pushstring(L, [[note name] UTF8String]);
    push_luavalue_for_nsobject(L, [note object]);
    push_luavalue_for_nsobject(L, [note userInfo]);
    
    if (lua_pcall(L, 3, 0, 0))
        hydra_handle_error(L);
}
@end

/// applistener.new(fn(notification)) -> applistener
/// Registers a listener function for inter-app notifications.
static int applistener_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    
    HydraGlobalNotifyListener* listener = [[HydraGlobalNotifyListener alloc] init];
    listener.L = L;
    
    lua_pushvalue(L, 1);
    listener.fn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    void** ud = lua_newuserdata(L, sizeof(id*));
    *ud = (__bridge_retained void*)listener;
    
    luaL_getmetatable(L, "applistener");
    lua_setmetatable(L, -2);
    
    return 1;
}

/// applistener:start()
/// Starts listening for notifications.
static int applistener_start(lua_State* L) {
    HydraGlobalNotifyListener* applistener = (__bridge HydraGlobalNotifyListener*)(*(void**)luaL_checkudata(L, 1, "applistener"));
    [[NSDistributedNotificationCenter defaultCenter] addObserver:applistener selector:@selector(heard:) name:nil object:nil];
    
    // store in registry
    lua_getglobal(L, "applistener");
    lua_getfield(L, -1, "_registry");
    lua_pushvalue(L, 1);
    applistener.ref = luaL_ref(L, -2);
    lua_pop(L, 2);
    
    return 0;
}

/// applistener:stop()
/// Stops listening for notifications.
static int applistener_stop(lua_State* L) {
    HydraGlobalNotifyListener* applistener = (__bridge HydraGlobalNotifyListener*)(*(void**)luaL_checkudata(L, 1, "applistener"));
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:applistener];
    
    // remove from registry
    lua_getglobal(L, "applistener");
    lua_getfield(L, -1, "_registry");
    luaL_unref(L, -1, applistener.ref);
    lua_pop(L, 2);
    
    return 0;
}

static int applistener_gc(lua_State* L) {
    HydraGlobalNotifyListener* applistener = (__bridge_transfer HydraGlobalNotifyListener*)(*(void**)luaL_checkudata(L, 1, "applistener"));
    applistener = nil;
    return 0;
}

static const luaL_Reg applistenerlib[] = {
    {"new", applistener_new},
    {"start", applistener_start},
    {"stop", applistener_stop},
    {"__gc", applistener_gc},
    {NULL, NULL}
};

int luaopen_applistener(lua_State* L) {
    luaL_newlib(L, applistenerlib);
    
    lua_newtable(L);
    lua_setfield(L, -2, "_registry");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "applistener");
    
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    return 1;
}
