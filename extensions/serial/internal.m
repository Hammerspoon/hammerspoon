@import Cocoa;
@import LuaSkin;

#import "ORSSerialPort/ORSSerialPort.h"
#import "ORSSerialPort/ORSSerialPortManager.h"

#import <IOKit/usb/USBSpec.h>

#define USERDATA_TAG  "hs.serial"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - ORSSerial Additions

@interface ORSSerialPort (Attributes)
@property (nonatomic, readonly) NSDictionary *ioDeviceAttributes;
@end

@implementation ORSSerialPort (Attributes)

- (NSDictionary *)ioDeviceAttributes
{
  NSDictionary *result = nil;
    
    io_iterator_t iterator = 0;
    if (IORegistryEntryCreateIterator(self.IOKitDevice,
                                      kIOServicePlane,
                                      kIORegistryIterateRecursively + kIORegistryIterateParents,
                                      &iterator) != KERN_SUCCESS) return nil;
    
    io_object_t device = 0;
    while ((device = IOIteratorNext(iterator)) && result == nil)
    {
        CFMutableDictionaryRef usbProperties = 0;
        if (IORegistryEntryCreateCFProperties(device, &usbProperties, kCFAllocatorDefault, kNilOptions) != KERN_SUCCESS)
        {
            IOObjectRelease(device);
            continue;
        }
        NSDictionary *properties = CFBridgingRelease(usbProperties);
        
        NSNumber *vendorID = properties[(__bridge NSString *)CFSTR(kUSBVendorID)];
        NSNumber *productID = properties[(__bridge NSString *)CFSTR(kUSBProductID)];
        if (!vendorID || !productID) { IOObjectRelease(device); continue; } // not a USB device
        
        result = properties;
        
        IOObjectRelease(device);
    }
    
    IOObjectRelease(iterator);
    return result;
}

@end

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

@property NSString*                 portName;
@property NSString*                 portPath;

@property LSGCCanary                    lsCanary;

@property ORSSerialPortParity       parity;
@property NSNumber*                 baudRate;
@property NSUInteger                numberOfStopBits;
@property NSUInteger                numberOfDataBits;
@property BOOL                      shouldEchoReceivedData;
@property BOOL                      usesRTSCTSFlowControl;
@property BOOL                      usesDTRDSRFlowControl;
@property BOOL                      usesDCDOutputFlowControl;
@property BOOL                      allowsNonStandardBaudRates;

@end

@implementation HSSerialPort

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
                
        _callbackRef                = LUA_NOREF;
        _deviceCallbackRef          = LUA_NOREF;
        _callbackToken              = nil;
        _selfRefCount               = 0;
        
        _portName                   = nil;
        _portPath                   = nil;
        _parity                     = ORSSerialPortParityNone;
        _baudRate                   = [NSNumber numberWithInt:115200];
        _numberOfStopBits           = 1;
        _numberOfDataBits           = 8;
        _shouldEchoReceivedData     = NO;
        _usesRTSCTSFlowControl      = NO;
        _usesDTRDSRFlowControl      = NO;
        _usesDCDOutputFlowControl   = NO;
        _allowsNonStandardBaudRates = NO;
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
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"opened"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"closed"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"received"];
        [skin pushNSObject:data];
        NSString *hex = [data hexadecimalString];
        [skin pushNSObject:hex];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:4 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceivePacket:(NSData *)packetData matchingDescriptor:(ORSSerialPacketDescriptor *)descriptor
{
    // TODO: Impliment `ORSSerialPacketDescriptor` functionality
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];

        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"removed"];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
    
    // After a serial port is removed from the system, it is invalid and we must discard any references to it:
    self.serialPort = nil;
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    if (_callbackRef != LUA_NOREF) {
        NSString *errorString = [NSString stringWithFormat:@"%@", error];
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:@"error"];
        [skin pushNSObject:errorString];
        [skin protectedCallAndError:@"hs.serial:callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

#pragma mark - ORSSerialPortManager Notifications

- (void)serialPortsWereConnected:(NSNotification *)notification
{
    if (_deviceCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
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
        _lua_stackguard_exit(skin.L);
    }
}

- (void)serialPortsWereDisconnected:(NSNotification *)notification
{
    if (_deviceCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }
        
        _lua_stackguard_entry(skin.L);
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
        _lua_stackguard_exit(skin.L);
    }
}

#pragma mark - Properties

- (bool)isPortNameValid:(NSString *)portName
{
    NSArray *availablePorts = _serialPortManager.availablePorts;
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *currentName = [port name];
        if ([portName isEqualToString:currentName]) {
            self.portName = portName;
            return YES;
        }
    }
    return NO;
}

- (bool)isPathValid:(NSString *)path
{
    NSArray *availablePorts = _serialPortManager.availablePorts;
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *currentPath = [port path];
        if ([path isEqualToString:currentPath]) {
            self.portPath = [port path];
            self.portName = [port name];
            return YES;
        }
    }
    return NO;
}

- (bool)createPortFromPortName:(NSString *)portName
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

- (bool)createPortFromPath:(NSString *)portPath
{
    [_serialPort close];
    _serialPort.delegate = nil;

    _serialPort = [ORSSerialPort serialPortWithPath:portPath];
    _serialPort.delegate = self;
    return YES;
}

- (BOOL)open
{
    if (!self.serialPort && self.portPath) {
        [self createPortFromPath:self.portPath];
    }
    if (!self.serialPort && self.portName) {
        [self createPortFromPortName:self.portName];
    }
    if (self.serialPort) {
        self.serialPort.allowsNonStandardBaudRates  = self.allowsNonStandardBaudRates;
        self.serialPort.parity                      = self.parity;
        self.serialPort.baudRate                    = self.baudRate;
        self.serialPort.numberOfStopBits            = self.numberOfStopBits;
        self.serialPort.numberOfDataBits            = self.numberOfDataBits;
        self.serialPort.shouldEchoReceivedData      = self.shouldEchoReceivedData;
        self.serialPort.usesRTSCTSFlowControl       = self.usesRTSCTSFlowControl;
        self.serialPort.usesDTRDSRFlowControl       = self.usesDTRDSRFlowControl;
        self.serialPort.usesDCDOutputFlowControl    = self.usesDCDOutputFlowControl;
        [self.serialPort open];
    }
    return self.serialPort && self.serialPort.isOpen;
}

- (void)changeParity:(ORSSerialPortParity)parity
{
    self.parity = parity;
    if ([self isOpen]) {
        self.serialPort.parity = parity;
    }
}

- (void)changeBaudRate:(NSNumber*)baudRate
{
    self.baudRate = baudRate;
    if ([self isOpen]) {
        self.serialPort.allowsNonStandardBaudRates = self.allowsNonStandardBaudRates;
        self.serialPort.baudRate = baudRate;
    }
}

- (void)changeNumberOfStopBits:(NSUInteger)numberOfStopBits
{
    self.numberOfStopBits = numberOfStopBits;
    if ([self isOpen]) {
        self.serialPort.numberOfStopBits = numberOfStopBits;
    }
}

- (void)changeNumberOfDataBits:(NSUInteger)numberOfDataBits
{
    self.numberOfDataBits = numberOfDataBits;
    if ([self isOpen]) {
        self.serialPort.numberOfDataBits = numberOfDataBits;
    }
}

- (void)changeUsesRTSCTSFlowControl:(BOOL)usesRTSCTSFlowControl
{
    self.usesRTSCTSFlowControl = usesRTSCTSFlowControl;
    if ([self isOpen]) {
        self.serialPort.usesRTSCTSFlowControl = usesRTSCTSFlowControl;
    }
}

- (void)changeUsesDTRDSRFlowControl:(BOOL)usesDTRDSRFlowControl
{
    self.usesDTRDSRFlowControl = usesDTRDSRFlowControl;
    if ([self isOpen]) {
        self.serialPort.usesDTRDSRFlowControl = usesDTRDSRFlowControl;
    }
}

- (void)changeUsesDCDOutputFlowControl:(BOOL)usesDCDOutputFlowControl
{
    self.usesDCDOutputFlowControl = usesDCDOutputFlowControl;
    if ([self isOpen]) {
        self.serialPort.usesDCDOutputFlowControl = usesDCDOutputFlowControl;
    }
}

- (void)changeShouldEchoReceivedData:(BOOL)shouldEchoReceivedData
{
    self.shouldEchoReceivedData = shouldEchoReceivedData;
    if ([self isOpen]) {
        self.serialPort.shouldEchoReceivedData = shouldEchoReceivedData;
    }
}

- (void)close
{
    if (self.serialPort) {
        [self.serialPort close];
    }
}

- (BOOL)isOpen
{
    return self.serialPort && self.serialPort.isOpen;
}

- (void)sendData:(NSData*)dataToSend
{
    if (self.serialPort) {
        [self.serialPort sendData:dataToSend];
    }
}

@end

/// hs.serial.newFromName(portName) -> serialPortObject
/// Constructor
/// Creates a new `hs.serial` object using the port name.
///
/// Parameters:
///  * portName - A string containing the port name.
///
/// Returns:
///  * An `hs.serial` object or `nil` if an error occured.
///
/// Notes:
///  * A valid port name can be found by checking `hs.serial.availablePortNames()`.
static int serial_newFromName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    
    NSString *portName = [skin toNSObjectAtIndex:1];
    
    HSSerialPort *serialPort = [[HSSerialPort alloc] init];
    
    serialPort.lsCanary = [skin createGCCanary];
    
    bool result = [serialPort isPortNameValid:portName];
        
    if (serialPort && result) {
        [skin pushNSObject:serialPort];
    } else {
        serialPort = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.serial.newFromPath(path) -> serialPortObject
/// Constructor
/// Creates a new `hs.serial` object using a path.
///
/// Parameters:
///  * path - A string containing the path (i.e. "/dev/cu.usbserial").
///
/// Returns:
///  * An `hs.serial` object or `nil` if an error occured.
///
/// Notes:
///  * A valid port name can be found by checking `hs.serial.availablePortPaths()`.
static int serial_newFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    
    NSString *path = [skin toNSObjectAtIndex:1];
    
    HSSerialPort *serialPort = [[HSSerialPort alloc] init];

    serialPort.lsCanary = [skin createGCCanary];
    
    bool result = [serialPort isPathValid:path];
        
    if (serialPort && result) {
        [skin pushNSObject:serialPort];
    } else {
        serialPort = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.serial:callback(callbackFn) -> serialPortObject
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
///  * The callback function should expect 4 arguments and should not return anything:
///    * `serialPortObject` - The serial port object that triggered the callback.
///    * `callbackType` - A string containing "opened", "closed", "received", "removed" or "error".
///    * `message` - If the `callbackType` is "received", then this will be the data received as a string. If the `callbackType` is "error", this will be the error message as a string.
///    * `hexadecimalString` - If the `callbackType` is "received", then this will be the data received as a hexadecimal string.
static int serial_callback(lua_State *L) {
    // Check Arguments:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    // Get Serial Port:
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    
    // Remove the existing callback:
    serialPort.callbackRef = [skin luaUnref:refTable ref:serialPort.callbackRef];
    if (serialPort.callbackToken != nil) {
        serialPort.callbackToken = nil;
    }

    // Setup the new callback:
    if (lua_type(L, 2) != LUA_TNIL) { // may be table with __call metamethod
        lua_pushvalue(L, 2);
        serialPort.callbackRef = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.serial.availablePortNames() -> table
/// Function
/// Returns a table of currently connected serial ports names.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any connected serial port names as strings.
static int serial_availablePortNames(lua_State *L) {
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

/// hs.serial.availablePortDetails() -> table
/// Function
/// Returns a table of currently connected serial ports details, organised by port name.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the IOKit details of any connected serial ports, organised by port name.
static int serial_availablePortDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TBREAK];
    ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];
    NSArray *availablePorts = portManager.availablePorts;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *portName = [port name];
        NSDictionary *attributes = [port ioDeviceAttributes];
        if (attributes == nil) {
            attributes = @{};
        }
        [result setObject:attributes forKey:portName];
    }
    [skin pushNSObject:result];
    return 1;
}

/// hs.serial.availablePortPaths() -> table
/// Function
/// Returns a table of currently connected serial ports paths.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any connected serial port paths as strings.
static int serial_availablePortPaths(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TBREAK];
    ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];
    NSArray *availablePorts = portManager.availablePorts;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (ORSSerialPort *port in availablePorts)
    {
        NSString *portPath = [port path];
        [result addObject:portPath];
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
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    NSString *deviceName = [serialPort.serialPort name];
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
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    NSString *portPath = [serialPort.serialPort path];
    [skin pushNSObject:portPath];
    return 1;
}

/// hs.serial:open() -> serialPortObject | nil
/// Method
/// Opens the serial port.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.serial` object or `nil` if the port could not be opened.
static int serial_open(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    BOOL result = [serialPort open];
    if (result) {
        lua_pushvalue(L, 1);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.serial:close() -> serialPortObject
/// Method
/// Closes the serial port.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.serial` object.
static int serial_close(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    [serialPort close];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.serial:baudRate([value], [allowNonStandardBaudRates]) -> number | serialPortObject
/// Method
/// Gets or sets the baud rate for the serial port.
///
/// Parameters:
///  * value - An optional number to set the baud rate.
///  * [allowNonStandardBaudRates] - An optional boolean to enable non-standard baud rates. Defaults to `false`.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns the baud rate as a number
///
/// Notes:
///  * This function supports the following standard baud rates as numbers: 300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 230400.
///  * If no baud rate is supplied, it defaults to 115200.
static int serial_baudRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    NSNumber *baudRate;
    
    if (lua_gettop(L) == 1) {
        // Get:
        baudRate = serialPort.baudRate;
        [skin pushNSObject:baudRate];
    }
    else {
        // Set:
        NSNumber *proposedBaudRate = [skin toNSObjectAtIndex:2];
        
        BOOL allowNonStandardBaudRates = (lua_isboolean(L, 3) && lua_toboolean(L, 3));
        if (allowNonStandardBaudRates) {
            serialPort.allowsNonStandardBaudRates = YES;
            [serialPort changeBaudRate:proposedBaudRate];
            lua_pushvalue(L, 1);
        } else {
            NSArray *availableBaudRates = @[@300, @1200, @2400, @4800, @9600, @14400, @19200, @28800, @38400, @57600, @115200, @230400];
            if ([availableBaudRates containsObject:proposedBaudRate]) {
                // Valid Baud Rate:
                [serialPort changeBaudRate:proposedBaudRate];
            }
            else {
                [skin logError:[NSString stringWithFormat:@"%s: Invalid Baud Rate supplied. Possible baud rates are: 300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200 and 230400.", USERDATA_TAG]];
            }
            lua_pushvalue(L, 1);
        }
    }
    
    return 1;
}

/// hs.serial:parity([value]) -> string | serialPortObject
/// Method
/// Gets or sets the parity for the serial port.
///
/// Parameters:
///  * value - An optional string to set the parity. It can be "none", "odd" or "even".
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns a string value of "none", "odd" or "even".
static int serial_parity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
    
    NSString *result;
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    
    if (lua_gettop(L) == 1) {
        // Get:
        ORSSerialPortParity parity = [serialPort.serialPort parity];
        if (parity == ORSSerialPortParityNone) {
            result = @"none";
        }
        else if (parity == ORSSerialPortParityOdd) {
            result = @"odd";
        }
        else if (parity == ORSSerialPortParityEven) {
            result = @"even";
        }
        [skin pushNSObject:result];
    } else {
        // Set:
        NSArray *availableParity = @[@"none", @"odd", @"even"];
        NSString *proposedParity = [skin toNSObjectAtIndex:2];
        if ([availableParity containsObject:proposedParity]) {
            // Valid Parity Rate:
            ORSSerialPortParity newParity;
            if ([proposedParity isEqualToString:@"odd"]) {
                newParity = ORSSerialPortParityOdd;
            }
            else if ([proposedParity isEqualToString:@"even"]) {
                newParity = ORSSerialPortParityEven;
            } else {
                newParity = ORSSerialPortParityNone;
            }
            [serialPort changeParity:newParity];
        } else {
            [skin logError:[NSString stringWithFormat:@"%s: Invalid Parity string supplied. Should be 'none', 'odd' or 'even'.", USERDATA_TAG]];
        }
        lua_pushvalue(L, 1);
    }
    
    return 1;
}

/// hs.serial:usesDTRDSRFlowControl([value]) -> boolean | serialPortObject
/// Method
/// Gets or sets whether the port should use DCD Flow Control.
///
/// Parameters:
///  * value - An optional boolean.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns a boolean.
///  * The default value is `false`.
static int serial_usesDCDOutputFlowControl(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        BOOL usesDCDOutputFlowControl = serialPort.usesDCDOutputFlowControl;
        lua_pushboolean(L, usesDCDOutputFlowControl);
    } else {
        bool usesDCDOutputFlowControl = lua_toboolean(L, 2);
        [serialPort changeUsesDCDOutputFlowControl:usesDCDOutputFlowControl];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.serial:usesDTRDSRFlowControl([value]) -> boolean | serialPortObject
/// Method
/// Gets or sets whether the port should use DTR/DSR Flow Control.
///
/// Parameters:
///  * value - An optional boolean.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns a boolean.
///  * The default value is `false`.
static int serial_usesDTRDSRFlowControl(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        BOOL usesDTRDSRFlowControl = serialPort.usesDTRDSRFlowControl;
        lua_pushboolean(L, usesDTRDSRFlowControl);
    } else {
        BOOL usesDTRDSRFlowControl = lua_toboolean(L, 2);
        [serialPort changeUsesDTRDSRFlowControl:usesDTRDSRFlowControl];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.serial:usesRTSCTSFlowControl([value]) -> boolean | serialPortObject
/// Method
/// Gets or sets whether the port should use RTS/CTS Flow Control.
///
/// Parameters:
///  * value - An optional boolean.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns a boolean.
///  * The default value is `false`.
static int serial_usesRTSCTSFlowControl(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        BOOL usesRTSCTSFlowControl = serialPort.usesRTSCTSFlowControl;
        lua_pushboolean(L, usesRTSCTSFlowControl);
    } else {
        BOOL usesRTSCTSFlowControl = lua_toboolean(L, 2);
        [serialPort changeUsesRTSCTSFlowControl:usesRTSCTSFlowControl];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.serial:shouldEchoReceivedData([value]) -> boolean | serialPortObject
/// Method
/// Gets or sets whether the port should echo received data.
///
/// Parameters:
///  * value - An optional boolean.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns a boolean.
///  * The default value is `false`.
static int serial_shouldEchoReceivedData(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        BOOL shouldEchoReceivedData = serialPort.shouldEchoReceivedData;
        lua_pushboolean(L, shouldEchoReceivedData);
    } else {
        BOOL shouldEchoReceivedData = lua_toboolean(L, 2);
        [serialPort changeShouldEchoReceivedData:shouldEchoReceivedData];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.serial:stopBits([value]) -> number | serialPortObject
/// Method
/// Gets or sets the number of stop bits for the serial port.
///
/// Parameters:
///  * value - An optional number to set the number of stop bits. It can be 1 or 2.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns the number of stop bits as a number.
///  * The default value is 1.
static int serial_numberOfStopBits(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        NSUInteger numberOfStopBits = serialPort.numberOfStopBits;
        [skin pushNSObject:@(numberOfStopBits)];
    } else {
        // Set:
        int proposedNumberOfStopBits = (int)lua_tointeger(L, 2);
        if (proposedNumberOfStopBits >= 1 && proposedNumberOfStopBits <= 2) {
            [serialPort changeNumberOfStopBits:proposedNumberOfStopBits];
        } else {
            [skin logError:[NSString stringWithFormat:@"%s: Invalid number of stop bits Should be 1 or 2.", USERDATA_TAG]];
        }
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs.serial:dataBits([value]) -> number | serialPortObject
/// Method
/// Gets or sets the number of data bits for the serial port.
///
/// Parameters:
///  * value - An optional number to set the number of data bits. It can be 5 to 8.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object. Otherwise this method returns the data bits as a number.
///  * The default value is 8.
static int serial_numberOfDataBits(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    if (lua_gettop(L) == 1) {
        // Get:
        NSUInteger numberOfStopBits = serialPort.numberOfDataBits;
        [skin pushNSObject:@(numberOfStopBits)];
    } else {
        // Set:
        int proposedNumberOfDataBits = (int)lua_tointeger(L, 2);
        if (proposedNumberOfDataBits >= 5 && proposedNumberOfDataBits <= 8) {
            [serialPort changeNumberOfDataBits:proposedNumberOfDataBits];
        } else {
            [skin logError:[NSString stringWithFormat:@"%s: Invalid number of data bits Should be 1 or 2.", USERDATA_TAG]];
        }
        lua_pushvalue(L, 1);
    }
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
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    BOOL isOpen = [serialPort isOpen];
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
    HSSerialPort *serialPort = [skin toNSObjectAtIndex:1];
    NSData *dataToSend = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly];
    [serialPort sendData:dataToSend];
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
        watcherDeviceManager.lsCanary = [skin createGCCanary];
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

static id toHSSerialPortFromLua(lua_State *L, int idx) {
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
    NSString *title = obj.portName;
    BOOL isOpen = [obj isOpen];
    NSString *connected = @"Connected";
    if (!isOpen) {
        connected = @"Disconnected";
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ - %@ (%p)", USERDATA_TAG, title, connected, lua_topointer(L, 1)]];
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
    {"name",                        serial_name},
    {"path",                        serial_path},
    {"open",                        serial_open},
    {"close",                       serial_close},
    {"baudRate",                    serial_baudRate},
    {"sendData",                    serial_sendData},
    {"parity",                      serial_parity},
    {"isOpen",                      serial_isOpen},
    {"callback",                    serial_callback},
    {"stopBits",                    serial_numberOfStopBits},
    {"dataBits",                    serial_numberOfDataBits},
    {"shouldEchoReceivedData",      serial_shouldEchoReceivedData},
    {"usesRTSCTSFlowControl",       serial_usesRTSCTSFlowControl},
    {"usesDTRDSRFlowControl",       serial_usesDTRDSRFlowControl},
    {"usesDCDOutputFlowControl",    serial_usesDCDOutputFlowControl},
    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"newFromName",             serial_newFromName},
    {"newFromPath",             serial_newFromPath},
    {"availablePortNames",      serial_availablePortNames},
    {"availablePortPaths",      serial_availablePortPaths},
    {"availablePortDetails",    serial_availablePortDetails},
    {"deviceCallback",          serial_deviceCallback},
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
