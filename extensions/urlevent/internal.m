#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// ----------------------- Objective C ---------------------

@interface HSURLEventHandler : NSObject
@property (nonatomic, strong) NSAppleEventManager *appleEventManager;
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor *)replyEvent;
- (void)gc;
@end

static HSURLEventHandler *eventHandler;
static int fnCallback;

@implementation HSURLEventHandler
- (id)init {
    self = [super init];
    if (self) {
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
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    if (fnCallback == LUA_NOREF) {
        // Lua hasn't registered a callback. This possibly means we have been require()'d as hs.urlevent.internal and not set up properly. Weird. Refuse to do anything
        printToConsole(skin.L, "hs.urlevent handleAppleEvent:: No fnCallback has been set by Lua");
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

    lua_rawgeti(L, LUA_REGISTRYINDEX, fnCallback);
    lua_pushstring(L, [[url host] UTF8String]);
    lua_newtable(L);
    for (int i = 0; i < (int)[keys count]; i++) {
        // Push each URL parameter into the params table
        lua_pushstring(L, [[keys objectAtIndex:i] UTF8String]);
        lua_pushstring(L, [[values objectAtIndex:i] UTF8String]);
        lua_settable(L, -3);
    }

    if (![skin protectedCallAndTraceback:2 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
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

static int urlevent_setup() {
    eventHandler = [[HSURLEventHandler alloc] init];
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

    {NULL, NULL}
};

static const luaL_Reg urlevent_gclib[] = {
    {"__gc", urlevent_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_urlevent_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.urlevent.internal". */

int luaopen_hs_urlevent_internal(lua_State *L __unused) {
    urlevent_setup();

    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:urleventlib metaFunctions:urlevent_gclib];

    return 1;
}
