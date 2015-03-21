#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

// ----------------------- Definitions ---------------------

#define lua_to_nsstring(L, idx) [NSString stringWithUTF8String:luaL_checkstring(L, idx)]

// ----------------------- Objective C ---------------------

@interface HSURLEventHandler : NSObject {
    lua_State *L;
}
@property (nonatomic, strong) NSAppleEventManager *appleEventManager;
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor *)replyEvent;
- (void)gc;
@end

static HSURLEventHandler *eventHandler;
static int fnCallback;

@implementation HSURLEventHandler
- (id)initWithLuaState:(lua_State *)luaState {
    self = [super init];
    if (self) {
        L = luaState;
        self.appleEventManager = [NSAppleEventManager sharedAppleEventManager];
        [self.appleEventManager setEventHandler:self
                               andSelector:@selector(handleAppleEvent:withReplyEvent:)
                             forEventClass:kInternetEventClass
                                andEventID:kAEGetURL];
    }
    return self;
}

- (void)gc {
    [self.appleEventManager removeEventHandlerForEventClass:kInternetEventClass
                                                 andEventID:kAEGetURL];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor * __unused)replyEvent {
    if (fnCallback == LUA_NOREF) {
        // Lua hasn't registered a callback. This possibly means we have been require()'d as hs.urlevent.internal and not set up properly. Weird. Refuse to do anything
        return;
    }

    // Split the URL into its components
    NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString *query = [url query];
    NSArray *queryPairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *pairs = [NSMutableDictionary dictionary];
    for (NSString *queryPair in queryPairs) {
        NSArray *bits = [queryPair componentsSeparatedByString:@"="];
        if ([bits count] != 2) { continue; }

        NSString *key = [[bits objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *value = [[bits objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        [pairs setObject:value forKey:key];
    }

    NSArray *keys = [pairs allKeys];
    NSArray *values = [pairs allValues];

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_remove(L, -2);

    lua_rawgeti(L, LUA_REGISTRYINDEX, fnCallback);
    lua_pushstring(L, [[url host] UTF8String]);
    lua_newtable(L);
    for (int i = 0; i < (int)[keys count]; i++) {
        // Push each URL parameter into the params table
        lua_pushstring(L, [[keys objectAtIndex:i] UTF8String]);
        lua_pushstring(L, [[values objectAtIndex:i] UTF8String]);
        lua_settable(L, -3);
    }

    if (lua_pcall(L, 2, 0, -4) != LUA_OK) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs");
        lua_getfield(L, -1, "showError");
        lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}
@end

// ----------------------- C ---------------------

// Rather than manage complex callback state from C, we just have one path into Lua for all events, and events are directed to their callbacks from there
static int urleventSetCallback(lua_State *L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    fnCallback = luaL_ref(L, LUA_REGISTRYINDEX);

    return 0;
}

static int urlevent_setup(lua_State* L) {
    eventHandler = [[HSURLEventHandler alloc] initWithLuaState:L];
    fnCallback = LUA_NOREF;

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int urlevent_gc(lua_State* __unused L) {
    [eventHandler gc];
    eventHandler = nil;
    luaL_unref(L, LUA_REGISTRYINDEX, fnCallback);
    fnCallback = LUA_NOREF;

    return 0;
}

static const luaL_Reg urleventlib[] = {
    {"setCallback", urleventSetCallback},

    {}
};

static const luaL_Reg urlevent_gclib[] = {
    {"__gc", urlevent_gc},

    {}
};

/* NOTE: The substring "hs_urlevent_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.urlevent.internal". */

int luaopen_hs_urlevent_internal(lua_State *L) {
    urlevent_setup(L);

    // Table for luaopen
    luaL_newlib(L, urleventlib);
    luaL_newlib(L, urlevent_gclib);
    lua_setmetatable(L, -2);

    return 1;
}
