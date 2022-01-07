@import Cocoa;
@import LuaSkin;

#import "F53OSC/F53OSC.h"

#define USERDATA_TAG  "hs.osc"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSOSC : NSObject <F53OSCPacketDestination>

- (void) start;
- (void) stop;
- (bool) isActive;
- (bool) isServer;

@property (strong)                              F53OSCServer *server;
@property (assign)                              UInt16 listeningPort;
@property (assign)                              bool isActive;

@property (assign)                              bool isServer;

@property (strong)                              F53OSCClient *client;

@property (nonatomic, copy, nullable)           NSString *clientHost;
@property (nonatomic, assign)                   UInt16 clientPort;

@property int                                   selfRefCount;
@property int                                   callbackRef;
@property id                                    callbackToken;

@property LSGCCanary                            lsCanary;

@end

@implementation HSOSC

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // Server:
        self.server                     = [F53OSCServer new];
        self.server.delegate            = self;
        
        self.listeningPort              = 0;
            
        // Client:
        self.client                     = [F53OSCClient new];
        self.client.delegate            = self;
        
        self.clientHost                 = @"localhost";
        self.clientPort                 = 0;
        
        // Shared:
        self.callbackRef                = LUA_NOREF;
        self.callbackToken              = nil;
        self.selfRefCount               = 0;
        
        self.isActive                   = NO;
        
        self.isServer                   = NO;
    }
    return self;
}

#pragma mark - Properties

- (void)start
{
    self.isActive = NO;
    if (self.isServer) {
        // Server Mode:
        self.server.port = self.listeningPort;
        if ( [self.server startListening] )
        {
            self.isActive = YES;
        }
    } else {
        // Client Mode:
        self.client.port = self.clientPort;
        self.client.host = self.clientHost;
        if ([self.client connect]) {
            self.isActive = YES;
        }
    }
}

- (void)stop
{
    if (self.isServer) {
        // Server Mode:
        [self.server stopListening];
    } else {
        // Client Mode:
        [self.client disconnect];
    }
    
    self.isActive = NO;
}

#pragma mark - Server Message Handling

//  Note: F53OSC reserves the right to send messages off the main thread.
- (void)takeMessage:(F53OSCMessage *)message
{
    // handle all messages synchronously
    [self performSelectorOnMainThread:@selector( _processMessage: ) withObject:message waitUntilDone:NO];
}

- (void)_processMessage:(F53OSCMessage *)message
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:message.addressParts];
        [skin pushNSObject:message.arguments];
        [skin protectedCallAndError:@"hs.osc:callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

@end

/// hs.osc.newServer(listeningPort) -> oscObject
/// Constructor
/// Creates a new OSC Server.
///
/// Parameters:
///  * listeningPort - A number for the listening port.
///
/// Returns:
///  * An `hs.osc` object or `nil` if an error occured.
static int osc_newServer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];
    
    HSOSC *oscObject = [[HSOSC alloc] init];
    oscObject.isServer = YES;
    
    oscObject.lsCanary = [skin createGCCanary];
    
    NSNumber *listeningPort = [skin toNSObjectAtIndex:1];
    
    if (listeningPort) {
        oscObject.listeningPort = [listeningPort unsignedShortValue];
        [skin pushNSObject:oscObject];
    }
    else {
        oscObject = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.osc.newClient(host, port) -> oscObject
/// Constructor
/// Creates a new OSC Client.
///
/// Parameters:
///  * host - A string of the host path.
///  * port - A number of the port.
///
/// Returns:
///  * An `hs.osc` object or `nil` if an error occured.
static int osc_newClient(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TBREAK];
    
    HSOSC *oscObject = [[HSOSC alloc] init];
    oscObject.isServer = NO;
    
    oscObject.lsCanary = [skin createGCCanary];
    
    NSString *host = [skin toNSObjectAtIndex:1];
    NSNumber *port = [skin toNSObjectAtIndex:2];
    
    oscObject.clientHost = host;
    oscObject.clientPort = [port unsignedShortValue];
    
    if (host && port) {
        [skin pushNSObject:oscObject];
    }
    else {
        oscObject = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.osc:callback(callbackFn) -> oscObject
/// Method
/// Sets or removes a callback function for a OSC Server.
///
/// Parameters:
///  * `callbackFn` - a function to set as the callback for this OSC Server.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.osc` object
///
/// Notes:
///  * The callback function should expect 3 arguments and should not return anything:
///    * `oscObject` - The OSC object that triggered the callback.
///    * `addressParts` - A table of address parts.
///    * `arguments` - A table of arguments.
static int osc_callback(lua_State *L) {
    // Check Arguments:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    // Get OSC Server:
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    
    // We only want callbacks for server objects:
    if (oscObject.isServer) {
        // Remove the existing callback:
        oscObject.callbackRef = [skin luaUnref:refTable ref:oscObject.callbackRef];
        if (oscObject.callbackToken != nil) {
            oscObject.callbackToken = nil;
        }

        // Setup the new callback:
        if (lua_type(L, 2) != LUA_TNIL) { // may be table with __call metamethod
            lua_pushvalue(L, 2);
            oscObject.callbackRef = [skin luaRef:refTable];
        }
        }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.osc:listeningPort() -> number
/// Method
/// Returns the listening port of a OSC Server.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The port as a number.
static int osc_listeningPort(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[NSNumber numberWithInt:oscObject.listeningPort]];
    return 1;
}

/// hs.osc:port() -> number
/// Method
/// Returns the port of a OSC Client.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The port as a number.
static int osc_port(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[NSNumber numberWithInt:oscObject.clientPort]];
    return 1;
}

/// hs.osc:host() -> string
/// Method
/// Returns the host path of a OSC Client.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The host as a string.
static int osc_host(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:oscObject.clientHost];
    return 1;
}

/// hs.osc:start() -> oscObject
/// Method
/// Starts an OSC Server or Client.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.osc` object.
static int osc_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    [oscObject start];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.osc:stop() -> oscObject
/// Method
/// Stops an OSC Server or Client.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.osc` object.
static int osc_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    [oscObject stop];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.osc:send(address, arguments) -> oscObject
/// Method
/// Sends a message from an OSC Client.
///
/// Parameters:
///  * address - A string of the OSC address.
///  * arguments - A table of arguments.
///
/// Returns:
///  * The `hs.osc` object.
static int osc_send(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TTABLE, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    
    // Only send messages if we're a client:
    if (!oscObject.isServer) {
        NSString *message = [skin toNSObjectAtIndex:2];
        NSArray *arguments = [skin toNSObjectAtIndex:3];
        
        F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:message
                                                            arguments:arguments];
        
        [oscObject.client sendPacket:msg];
    }
    
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.osc:isActive() -> boolean
/// Method
/// Gets whether or not a OSC Server or Client is active.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if open, otherwise `false`.
static int osc_isActive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSOSC *oscObject = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, oscObject.isActive);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions

// NOTE: These must not throw a Lua error to ensure LuaSkin can safely be used from Objective-C delegates and blocks:

static int pushHSOSC(lua_State *L, id obj) {
    HSOSC *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSOSC *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSOSCFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSOSC *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSOSC, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSOSC *obj = [skin luaObjectAtIndex:1 toClass:"HSOSC"];
    NSNumber *listeningPort = [NSNumber numberWithInt:obj.listeningPort];
    BOOL isActive = obj.isActive;
    NSString *connected = @"Active";
    if (!isActive) {
        connected = @"Inactive";
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ - %@ (%p)", USERDATA_TAG, listeningPort, connected, lua_topointer(L, 1)]];
    return 1;
}

static int userdata_eq(lua_State* L) {
    // Can't get here if at least one of us isn't a userdata type, and we only care if both types are ours, so use luaL_testudata before the macro causes a Lua error:
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSOSC *obj1 = [skin luaObjectAtIndex:1 toClass:"HSOSC"];
        HSOSC *obj2 = [skin luaObjectAtIndex:2 toClass:"HSOSC"];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

// User Data Garbage Collection:
static int userdata_gc(lua_State* L) {
    HSOSC *obj = get_objectFromUserdata(__bridge_transfer HSOSC, L, 1, USERDATA_TAG);
    if (obj) {
        obj.selfRefCount--;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L];
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];

            // Disconnect Callback:
            if (obj.callbackToken != nil) {
                [obj stop];
                obj.callbackToken = nil;
            }
            obj = nil;

            LSGCCanary tmplsCanary = obj.lsCanary;
            [skin destroyGCCanary:&tmplsCanary];
            obj.lsCanary = tmplsCanary;
        }
    }
    
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

// Metatable Garbage Collection:
static int meta_gc(lua_State* L) {
    return 0;
}

// Metatable for userdata objects:
static const luaL_Reg userdata_metaLib[] = {
    // Server:
    {"listeningPort",               osc_listeningPort},
    {"callback",                    osc_callback},
    
    // Client:
    {"port",                        osc_port},
    {"host",                        osc_host},
    {"send",                        osc_send},
    
    // Shared:
    {"start",                       osc_start},
    {"stop",                        osc_stop},
    
    {"isActive",                    osc_isActive},
    
    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"newServer",                   osc_newServer},
    {"newClient",                   osc_newClient},
    {NULL,  NULL}
};

// Metatable for module:
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// Initalise Module:
int luaopen_hs_libosc(lua_State* L) {
    // Register Module:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // Register OSC Helpers:
    [skin registerPushNSHelper:pushHSOSC         forClass:"HSOSC"];
    [skin registerLuaObjectHelper:toHSOSCFromLua forClass:"HSOSC"
              withUserdataMapping:USERDATA_TAG];
    
    return 1;
}
