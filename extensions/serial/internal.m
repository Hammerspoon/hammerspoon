@import Cocoa;
@import LuaSkin;

#import "ORSSerialPort/ORSSerialPort.h"
#import "ORSSerialPort/ORSSerialPortManager.h"

#define USERDATA_TAG  "hs.serial"
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - String Conversion

@implementation NSData (NSData_Conversion)
// Returns hexadecimal string of NSData. Empty string if data is empty.
- (NSString *)hexadecimalString
{
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer)
    {
        return [NSString string];
    }

    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i)
    {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
    }

    return [NSString stringWithString:hexString];
}
@end

#pragma mark - Support Functions and Classes

@interface HSSerialPort : NSObject <ORSSerialPortDelegate>

@property (nonatomic, strong)       ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong)       ORSSerialPort *serialPort;

@property int                       selfRefCount;
@property int                       callbackRef;
@property id                        callbackToken;
@property int                       deviceCallbackRef;

@end

@implementation HSSerialPort

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
                
        _callbackRef             = LUA_NOREF;
        _deviceCallbackRef       = LUA_NOREF;
        _callbackToken           = nil;
        _selfRefCount            = 0;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - hs.serial.deviceCallback Functions

- (void)watchDevices
{
    @try {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(serialPortsWereConnected:) name:ORSSerialPortsWereConnectedNotification object:nil];
        [nc addObserver:self selector:@selector(serialPortsWereDisconnected:) name:ORSSerialPortsWereDisconnectedNotification object:nil];
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]];
    }
}

- (void)unwatchDevices
{
    @try {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:ORSSerialPortsWereConnectedNotification object:nil];
        [nc removeObserver:self name:ORSSerialPortsWereDisconnectedNotification object:nil];
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]];
    }
}

#pragma mark - ORSSerialPortDelegate Methods

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:@"opened"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:1 nresults:0];
    }
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:@"closed"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:1 nresults:0];
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:@"recieved"];
        [skin pushNSObject:data];
        NSString *hex = [data hexadecimalString];
        [skin pushNSObject:hex];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:3 nresults:0];
    }
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:@"removed"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:1 nresults:0];
    }
    
    // After a serial port is removed from the system, it is invalid and we must discard any references to it
    self.serialPort = nil;
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    if (_callbackRef != LUA_NOREF) {
        NSString *errorString = [NSString stringWithFormat:@"%@", error];
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:@"error"];
        [skin pushNSObject:errorString];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:1 nresults:0];
    }
}

#pragma mark - ORSSerialPortManager Notifications

- (void)serialPortsWereConnected:(NSNotification *)notification
{
    if (_deviceCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_deviceCallbackRef];
        [skin pushNSObject:@"connected"];
        
        // Get a table of connected port names:
        NSArray *connectedPorts = [notification userInfo][ORSConnectedSerialPortsKey];
        NSMutableArray *result = [[NSMutableArray alloc] init];
        for (ORSSerialPort *port in connectedPorts)
        {
            NSString *portName = [port name];
            [result addObject:portName];
        }
        [skin pushNSObject:result];
        
        
        [skin protectedCallAndError:@"hs.serial:deviceCallback" nargs:2 nresults:0];
    }
}

- (void)serialPortsWereDisconnected:(NSNotification *)notification
{
    if (_deviceCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin pushLuaRef:refTable ref:_deviceCallbackRef];
        [skin pushNSObject:@"disconnected"];
        
        // Get a table of disconnected port names:
        NSArray *disconnectedPorts = [notification userInfo][ORSDisconnectedSerialPortsKey];
        NSMutableArray *result = [[NSMutableArray alloc] init];
        for (ORSSerialPort *port in disconnectedPorts)
        {
            NSString *portName = [port name];
            [result addObject:portName];
        }
        [skin pushNSObject:result];

        [skin protectedCallAndError:@"hs.serial:deviceCallback" nargs:2 nresults:0];
    }
}

#pragma mark - Properties

- (void)open
{
    [self.serialPort open];
}

- (void)close
{
    [self.serialPort close];
}

- (void)send:(NSString*)message
{
    NSData *dataToSend = [message dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:dataToSend];
}

- (bool)createPort:(NSString *)portName
{
    NSArray *availablePorts = _serialPortManager.availablePorts;
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *currentName = [port name];
        if ([portName isEqualToString:currentName]) {
            NSString *currentPath = [port path];
            
            [_serialPort close];
            _serialPort.delegate = nil;
            
            _serialPort = [ORSSerialPort serialPortWithPath:currentPath];
            _serialPort.delegate = self;
            return YES;
        }
    }
    return NO;
}

@end

/// hs.serial.new(portName) -> `hs.midi` object
/// Constructor
/// Creates a new `hs.midi` object.
///
/// Parameters:
///  * portName - A string containing the port name.
///
/// Returns:
///  * An `hs.serial` object or `nil` if an error occured.
///
/// Notes:
///  * A valid port name can be found by checking `hs.serial.availablePorts()`.
static int serial_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    
    NSString *portName = [skin toNSObjectAtIndex:1];
    
    HSSerialPort *controller = [[HSSerialPort alloc] init];
    
    bool result = [controller createPort:portName];
        
    if (controller && result) {
        [skin pushNSObject:controller];
    } else {
        controller = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.serial:callback(callbackFn | nil)
/// Method
/// Sets or removes a callback function for the `hs.serial` object.
///
/// Parameters:
///  * `callbackFn` - a function to set as the callback for this `hs.serial` object.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.serial` object
///
/// Notes:
///  * The callback function should expect 3 arguments and should not return anything:
///    * `callbackType` - A string containing "opened", "closed", "recieved", "removed" or "error"
///    * `message` - If the `callbackType` is "recieved", then this will be the data received as a string. If the `callbackType` is "error", this will be the error message as a string.
///    * `hexadecimalString` - If the `callbackType` is "recieved", then this will be the data received as a hexadecimal string.
static int serial_callback(lua_State *L) {
    // Check Arguments:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    // Get Serial Port:
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    
    // Remove the existing callback:
    controller.callbackRef = [skin luaUnref:refTable ref:controller.callbackRef];
    if (controller.callbackToken != nil) {
        controller.callbackToken = nil;
    }

    // Setup the new callback:
    if (lua_type(L, 2) != LUA_TNIL) { // may be table with __call metamethod
        lua_pushvalue(L, 2);
        controller.callbackRef = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.serial.availablePorts() -> table
/// Function
/// Returns a table of currently connected serial ports.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any physically connected serial ports as strings.
static int serial_availablePorts(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TBREAK];
    ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];
    NSArray *availablePorts = portManager.availablePorts;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *portName = [port name];
        [result addObject:portName];
    }
    [skin pushNSObject:result];
    return 1;
}

/// hs.serial:name() -> string
/// Method
/// Returns the name of a `hs.serial` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The name as a string.
static int serial_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    NSString *deviceName = [controller.serialPort name];
    [skin pushNSObject:deviceName];
    return 1;
}

/// hs.serial:path() -> string
/// Method
/// Returns the path of a `hs.serial` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The path as a string.
static int serial_path(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    NSString *portPath = [controller.serialPort path];
    [skin pushNSObject:portPath];
    return 1;
}

/// hs.serial:open() -> boolean
/// Method
/// Opens the serial port.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns `true` if successful, otherwise `false`.
static int serial_open(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    [controller.serialPort open];
    BOOL isOpen = controller.serialPort.isOpen == true;
    lua_pushboolean(L, isOpen);
    return 1;
}

/// hs.serial:close() -> boolean
/// Method
/// Closes the serial port.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns `true` if successful, otherwise `false`.
static int serial_close(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    [controller.serialPort close];
    BOOL isClosed = (!controller.serialPort.isOpen) == true;
    lua_pushboolean(L, isClosed);
    return 1;
}

/// hs.serial:baudRate([value]) -> number
/// Method
/// Gets or sets the baud rate for the serial port.
///
/// Parameters:
///  * value - An optional number to set the baud rate.
///
/// Returns:
///  * The baud rate as a number.
///
/// Notes:
///  * This function supports the following baud rates as numbers: 300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 230400.
static int serial_baudRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    NSNumber *baudRate;
    
    if (lua_gettop(L) == 1) {
        // Get:
        baudRate = [controller.serialPort baudRate];
    }
    else {
        // Set:
        NSNumber *proposedBaudRate = [skin toNSObjectAtIndex:2];
        NSArray *availableBaudRates = @[@300, @1200, @2400, @4800, @9600, @14400, @19200, @28800, @38400, @57600, @115200, @230400];
        if ([availableBaudRates containsObject:proposedBaudRate]) {
            // Valid Baud Rate:
            controller.serialPort.baudRate = proposedBaudRate;
            baudRate = proposedBaudRate;
        }
        else {
            [skin logError:[NSString stringWithFormat:@"%s: Invalid Baud Rate supplied. Please see help.serial.baudRate.", USERDATA_TAG]] ;
            lua_pushnil(L) ;
        }
    }
    
    [skin pushNSObject:baudRate];
    return 1;
}

/// hs.serial:parity([value]) -> string
/// Method
/// Gets or sets the parity for the serial port.
///
/// Parameters:
///  * value - An optional string to set the parity. It can be "none", "odd" or "even".
///
/// Returns:
///  * A string value of "none", "odd" or "even".
static int serial_parity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
    
    NSString *result;
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    
    if (lua_gettop(L) == 1) {
        // Get:
        ORSSerialPortParity parity = [controller.serialPort parity];
        if (parity == ORSSerialPortParityNone) {
            result = @"none";
        }
        else if (parity == ORSSerialPortParityOdd) {
            result = @"odd";
        }
        else if (parity == ORSSerialPortParityEven) {
            result = @"even";
        }
    } else {
        // Set:
        NSArray *availableParity = @[@"none", @"odd", @"even"];
        NSString *proposedParity = [skin toNSObjectAtIndex:2];
        if ([availableParity containsObject:proposedParity]) {
            // Valid Parity Rate:
            if ([proposedParity isEqualToString:@"none"]) {
                controller.serialPort.parity = ORSSerialPortParityNone;
            }
            else if ([proposedParity isEqualToString:@"odd"]) {
                controller.serialPort.parity = ORSSerialPortParityOdd;
            }
            else if ([proposedParity isEqualToString:@"even"]) {
                controller.serialPort.parity = ORSSerialPortParityEven;
            }
            result = proposedParity;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s: Invalid Parity string supplied. Should be 'none', 'odd' or 'even'.", USERDATA_TAG]] ;
            lua_pushnil(L) ;
        }
    }
    [skin pushNSObject:result];
    return 1;
}

/// hs.serial:isOpen() -> boolean
/// Method
/// Gets whether or not a serial port is open.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if open, otherwise `false`.
static int serial_isOpen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    BOOL isOpen = [controller.serialPort isOpen];
    lua_pushboolean(L, isOpen);
    return 1;
}

/// hs.serial:sendData(value) -> none
/// Method
/// Sends data via a serial port.
///
/// Parameters:
///  * value - A string of data to send.
///
/// Returns:
///  * None
static int serial_sendData(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSSerialPort *controller = [skin toNSObjectAtIndex:1];
    NSString *dataString = [skin toNSObjectAtIndex:2];
    NSData *dataToSend = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    [controller.serialPort sendData:dataToSend];
    return 0;
}

// hs.serial.deviceCallback Manager:
HSSerialPort *watcherDeviceManager;

/// hs.serial.deviceCallback(callbackFn) -> none
/// Function
/// A callback that's triggered when a serial port is added or removed from the system.
///
/// Parameters:
///  * callbackFn - the callback function to trigger.
///
/// Returns:
///  * None
///
/// Notes:
///  * The callback function should expect 1 argument and should not return anything:
///    * `devices` - A table containing the names of any serial ports connected as strings.
static int serial_deviceCallback(lua_State *L) {
    // Check Arguments:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    // Setup or Remove Callback Function:
    if (!watcherDeviceManager) {
        watcherDeviceManager = [[HSSerialPort alloc] init];
    } else {
        if (watcherDeviceManager.deviceCallbackRef != LUA_NOREF) [watcherDeviceManager unwatchDevices];
    }
    watcherDeviceManager.deviceCallbackRef = [skin luaUnref:refTable ref:watcherDeviceManager.deviceCallbackRef];
    if (lua_type(skin.L, 1) != LUA_TNIL) { // may be table with __call metamethod
        watcherDeviceManager.deviceCallbackRef = [skin luaRef:refTable atIndex:1];
        [watcherDeviceManager watchDevices];
    }
    else {
        [watcherDeviceManager unwatchDevices];
        watcherDeviceManager = nil;
    }
    return 0;
}

#pragma mark - Lua<->NSObject Conversion Functions

// NOTE: These must not throw a Lua error to ensure LuaSkin can safely be used from Objective-C delegates and blocks:

static int pushHSSerialPort(lua_State *L, id obj) {
    HSSerialPort *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSSerialPort *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSSerialPortFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSSerialPort *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSSerialPort, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSSerialPort *obj = [skin luaObjectAtIndex:1 toClass:"HSSerialPort"];
    NSString *title = obj.serialPort.name;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]];
    return 1;
}

static int userdata_eq(lua_State* L) {
    // Can't get here if at least one of us isn't a userdata type, and we only care if both types are ours, so use luaL_testudata before the macro causes a Lua error:
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSSerialPort *obj1 = [skin luaObjectAtIndex:1 toClass:"HSSerialPort"];
        HSSerialPort *obj2 = [skin luaObjectAtIndex:2 toClass:"HSSerialPort"];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

// User Data Garbage Collection:
static int userdata_gc(lua_State* L) {
    HSSerialPort *obj = get_objectFromUserdata(__bridge_transfer HSSerialPort, L, 1, USERDATA_TAG);
    if (obj) {
        obj.selfRefCount--;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L];
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];

            // Disconnect Callback:
            if (obj.callbackToken != nil) {
                [obj.serialPort close];
                obj.callbackToken = nil;
            }
            obj = nil;
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
    {"name",        serial_name},
    {"path",        serial_path},
    {"open",        serial_open},
    {"close",       serial_close},
    {"baudRate",    serial_baudRate},
    {"sendData",    serial_sendData},
    {"parity",      serial_parity},
    {"isOpen",      serial_isOpen},
    {"callback",    serial_callback},
    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"new",                 serial_new},
    {"availablePorts",      serial_availablePorts},
    {"deviceCallback",      serial_deviceCallback},
    {NULL,  NULL}
};

// Metatable for module:
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// Initalise Module:
int luaopen_hs_serial_internal(lua_State* L) {
    // Register Module:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // Register Serial Port:
    [skin registerPushNSHelper:pushHSSerialPort         forClass:"HSSerialPort"];
    [skin registerLuaObjectHelper:toHSSerialPortFromLua forClass:"HSSerialPort"
              withUserdataMapping:USERDATA_TAG];
    
    return 1;
}
