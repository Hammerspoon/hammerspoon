@import Cocoa;
@import LuaSkin;

#include <stdio.h>
#import <Foundation/Foundation.h>

#include "razerdevice.h"
#include "razerkbd_driver.h"

#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDUsageTables.h>

#import <IOKit/hidsystem/IOHIDParameter.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

#define USERDATA_TAG  "hs.razer"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSRazer : NSObject

@property (nonatomic, strong) id    ioHIDManager;

@property NSNumber*                 internalDeviceId;
@property NSNumber*                 productId;

@property int                       selfRefCount;
@property int                       callbackRef;
@property id                        callbackToken;
@property int                       deviceCallbackRef;

@property LSGCCanary                lsCanary;

@end

@implementation HSRazer

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _callbackRef                = LUA_NOREF;
        _deviceCallbackRef          = LUA_NOREF;
        _callbackToken              = nil;
        _selfRefCount               = 0;
    }
    return self;
}

#pragma mark - IOKit C callbacks

- (void)setupHID
{
    // Create a HID device manager
    self.ioHIDManager = CFBridgingRelease(IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone));
            
    NSDictionary *matchTartarusV2   = @{ @(kIOHIDVendorIDKey): @USB_VENDOR_ID_RAZER, @(kIOHIDProductIDKey): self.productId };
    
    IOHIDManagerSetDeviceMatchingMultiple((__bridge IOHIDManagerRef)self.ioHIDManager,
                                          (__bridge CFArrayRef)@[matchTartarusV2]);

    // Add our callbacks for relevant events
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                               HIDconnect,
                                               (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                              HIDdisconnect,
                                              (__bridge void*)self);
    
    IOHIDManagerRegisterInputValueCallback((__bridge IOHIDManagerRef)self.ioHIDManager,
                                           HIDcallback,
                                           (__bridge void*)self);

    // Start our HID manager
    IOHIDManagerScheduleWithRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopDefaultMode);
    
    IOHIDManagerOpen((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    
    CFRunLoopRun();
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"connect: %p:%p", context, (void *)device);
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    NSLog(@"disconnect: %p", (void *)device);
}

static void HIDcallback(void* context, IOReturn result, void* sender, IOHIDValueRef value)
{
    HSRazer *manager = (__bridge HSRazer *)context;
    
    if (!([manager.productId intValue] == USB_DEVICE_ID_RAZER_TARTARUS_V2)) {
        NSLog(@"Only the Razer Tartarus V2 is currently supported.");
        return;
    }
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t scancode = IOHIDElementGetUsage(elem);
    long pressed = IOHIDValueGetIntegerValue(value);
    
    if (scancode < 4 || scancode > 231) {
        return;
    }
    
    // Process the button name:
    NSString *buttonName = @"";
    switch(scancode) {
        case 30:
            buttonName = @"01";
            break;
        case 31:
            buttonName = @"02";
            break;
        case 32:
            buttonName = @"03";
            break;
        case 33:
            buttonName = @"04";
            break;
        case 34:
            buttonName = @"05";
            break;
        case 43:
            buttonName = @"06";
            break;
        case 20:
            buttonName = @"07";
            break;
        case 26:
            buttonName = @"08";
            break;
        case 8:
            buttonName = @"09";
            break;
        case 21:
            buttonName = @"10";
            break;
        case 57:
            buttonName = @"11";
            break;
        case 4:
            buttonName = @"12";
            break;
        case 22:
            buttonName = @"13";
            break;
        case 7:
            buttonName = @"14";
            break;
        case 9:
            buttonName = @"15";
            break;
        case 225:
            buttonName = @"16";
            break;
        case 29:
            buttonName = @"17";
            break;
        case 27:
            buttonName = @"18";
            break;
        case 6:
            buttonName = @"19";
            break;
        case 44:
            buttonName = @"20";
            break;
        case 56:
            buttonName = @"Scroll Wheel";
            break;
        case 226:
            buttonName = @"Mode";
            break;
        case 82:
            buttonName = @"Up";
            break;
        case 81:
            buttonName = @"Down";
            break;
        case 80:
            buttonName = @"Left";
            break;
        case 79:
            buttonName = @"Right";
            break;
        default:
            NSLog(@"Unknown button pressed");
            return;
    }
    
    // Process the button action:
    NSString *buttonAction = @"";
    switch(scancode) {
        case 56:
            if (pressed == 1){
                buttonAction = @"up";
                break;
            }
            else if (pressed == -1) {
                buttonAction = @"down";
                break;
            }
            else if (pressed == 0) {
                buttonAction = @"pressed";
                break;
            }
        default:
            if (pressed == 1){
                buttonAction = @"pressed";
            }
            else {
                buttonAction = @"released";
            }
    }
    
    // Trigger the Lua callback:
    if (manager.callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:manager.lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"received"];
        [skin pushNSObject:buttonName];
        [skin pushNSObject:buttonAction];
        [skin protectedCallAndError:@"hs.razer:callback" nargs:4 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

#pragma mark - Properties

- (bool)isDeviceIDValid:(NSNumber *)deviceID
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        NSNumber *productId = [NSNumber numberWithLongLong:device.productId];
        
        if ([internalDeviceId isEqualToNumber:internalDeviceId]) {
            self.internalDeviceId = internalDeviceId;
            self.productId = productId;
            
            // Setup our HID callbacks based on productId:
            [self setupHID];
            
            closeAllRazerDevices(allDevices);
            return YES;
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (BOOL)isConnected
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            closeAllRazerDevices(allDevices);
            return YES;
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (bool)writeMode:(NSString *)mode speed:(NSNumber *)speed
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            if ([mode isEqualToString:@"none"]){
                razer_attr_write_mode_none(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"spectrum"]){
                razer_attr_write_mode_spectrum(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"reactive"]){
                razer_attr_write_mode_reactive(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"static"]){
                razer_attr_write_mode_static(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"static_no_store"]){
                razer_attr_write_mode_static_no_store(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"static_no_store"]){
                razer_attr_write_mode_static_no_store(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"starlight"]){
                razer_attr_write_mode_starlight(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"breath"]){
                razer_attr_write_mode_breath(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"wave"]){
                razer_attr_write_mode_wave(device.usbDevice, "", 0, [speed intValue]);
            }
            else if ([mode isEqualToString:@"macro"]){
                razer_attr_write_mode_macro(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"macro_effect"]){
                razer_attr_write_mode_macro_effect(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"pulsate"]){
                razer_attr_write_mode_pulsate(device.usbDevice, "", 0);
            }
            else {
                closeAllRazerDevices(allDevices);
                return NO;
            }
            closeAllRazerDevices(allDevices);
            return YES;
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (NSNumber *)brightness
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            ushort brightness = razer_attr_read_set_brightness(device.usbDevice);
            closeAllRazerDevices(allDevices);
            return [NSNumber numberWithUnsignedShort:brightness];
        }
    }
    closeAllRazerDevices(allDevices);
    return @-1;
}

- (BOOL)setBrightness:(NSNumber *)brightness
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            razer_attr_write_set_brightness(device.usbDevice, [brightness unsignedShortValue], 1);
            closeAllRazerDevices(allDevices);
            return YES;
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (NSString *)firmwareVersion
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            ssize_t firmwareVersionMajor = razer_attr_read_get_firmware_version_major(device.usbDevice, "");
            ssize_t firmwareVersionMinor = razer_attr_read_get_firmware_version_minor(device.usbDevice, "");
            closeAllRazerDevices(allDevices);
            return [NSString stringWithFormat:@"v%ld.%ld", firmwareVersionMajor, firmwareVersionMinor];
        }
    }
    closeAllRazerDevices(allDevices);
    return @"Unknown";
}

- (BOOL)redLed
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            ssize_t greenLed = razer_attr_read_tartarus_profile_led_red(device.usbDevice, "");
            if (greenLed == 1) {
                closeAllRazerDevices(allDevices);
                return YES;
            }
            else {
                closeAllRazerDevices(allDevices);
                return NO;
            }
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (BOOL)greenLed
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            ssize_t greenLed = razer_attr_read_tartarus_profile_led_green(device.usbDevice, "");
            if (greenLed == 1) {
                closeAllRazerDevices(allDevices);
                return YES;
            }
            else {
                closeAllRazerDevices(allDevices);
                return NO;
            }
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

- (BOOL)blueLed
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            ssize_t blueLed = razer_attr_read_tartarus_profile_led_blue(device.usbDevice, "");
            if (blueLed == 1) {
                closeAllRazerDevices(allDevices);
                return YES;
            }
            else {
                closeAllRazerDevices(allDevices);
                return NO;
            }
        }
    }
    closeAllRazerDevices(allDevices);
    return NO;
}

/*
 TODO - THINGS TO EXPOSE:
 
 ssize_t razer_attr_write_set_logo(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
 ssize_t razer_attr_write_mode_custom(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
 ssize_t razer_attr_write_set_fn_toggle(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
 ssize_t razer_attr_write_matrix_custom_frame(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
 
 ssize_t razer_attr_read_mode_game(IOUSBDeviceInterface **usb_dev, char *buf);
 ssize_t razer_attr_read_mode_macro_effect(IOUSBDeviceInterface **usb_dev, char *buf);
 ssize_t razer_attr_read_mode_pulsate(IOUSBDeviceInterface **usb_dev, char *buf);
 ssize_t razer_attr_read_set_logo(IOUSBDeviceInterface **usb_dev, char *buf, int count);
 */

@end

/// hs.razer.new(internalDeviceId) -> razerObject
/// Constructor
/// Creates a new `hs.razer` object using the `internalDeviceId`.
///
/// Parameters:
///  * internalDeviceId - A number containing the `internalDeviceId`.
///
/// Returns:
///  * An `hs.razer` object or `nil` if an error occured.
///
/// Notes:
///  * The `internalDeviceId` can  found by checking `hs.razer.devices()`.
static int razer_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TBREAK];
    
    NSNumber *internalDeviceId = [skin toNSObjectAtIndex:1];
    
    HSRazer *razer = [[HSRazer alloc] init];
    
    razer.lsCanary = [skin createGCCanary];
    
    bool result = [razer isDeviceIDValid:internalDeviceId];
        
    if (razer && result) {
        [skin pushNSObject:razer];
    } else {
        razer = nil;
        lua_pushnil(L);
    }
    return 1;
}

/// hs.razer:callback(callbackFn) -> razerObject
/// Method
/// Sets or removes a callback function for the `hs.razer` object.
///
/// Parameters:
///  * `callbackFn` - a function to set as the callback for this `hs.razer` object.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.razer` object
///
/// Notes:
///  * The callback function should expect 4 arguments and should not return anything:
///    * `razerObject` - The serial port object that triggered the callback.
///    * `callbackType` - A string containing "opened", "closed", "received", "removed" or "error".
///    * `buttonName` - The name of the button as a string.
///    * `buttonAction` - A string containing "pressed", "released", "up" or "down".
static int razer_callback(lua_State *L) {
    // Check Arguments:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    // Get Razer Object:
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    // Remove the existing callback:
    razer.callbackRef = [skin luaUnref:refTable ref:razer.callbackRef];
    if (razer.callbackToken != nil) {
        razer.callbackToken = nil;
    }

    // Setup the new callback:
    if (lua_type(L, 2) != LUA_TNIL) { // may be table with __call metamethod
        lua_pushvalue(L, 2);
        razer.callbackRef = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.razer.devices() -> table
/// Function
/// Returns a table of currently connected Razer devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the `productId` and `internalDeviceId` of all connected Razer devices.
static int razer_devices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TBREAK];
    
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        
        NSNumber *productId = [NSNumber numberWithLongLong:device.productId];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:productId forKey:@"productId"];
        [attributes setObject:internalDeviceId forKey:@"internalDeviceId"];
        [result addObject:attributes];
    }
    
    closeAllRazerDevices(allDevices);
    
    [skin pushNSObject:result];
    return 1;
}

/// hs.razer:internalDeviceId() -> number
/// Method
/// Returns the `internalDeviceId` of a `hs.razer` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `internalDeviceId` as a number.
static int razer_internalDeviceId(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSNumber *internalDeviceId = razer.internalDeviceId;
    [skin pushNSObject:internalDeviceId];
    return 1;
}

/// hs.razer:firmwareVersion() -> string
/// Method
/// Returns the firmware version of a `hs.razer` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `firmwareVersion` as a string (for example. "v1.0").
static int razer_firmwareVersion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSString *firmwareVersion = razer.firmwareVersion;
    [skin pushNSObject:firmwareVersion];
    return 1;
}

/// hs.razer:ledStatus() -> string
/// Method
/// Gets the LED status of a Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns a string - "red", "blue", "green" or "off".
static int razer_ledStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSString *result = @"off";
    if ([razer redLed]){
        result = @"red";
    }
    else if ([razer greenLed]){
        result = @"green";
    }
    else if ([razer blueLed]){
        result= @"blue";
    }
    [skin pushNSObject:result];
    return 1;
}

/// hs.razer:productId() -> number
/// Method
/// Returns the `productId` of a `hs.razer` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `productId` as a number.
static int razer_productId(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSNumber *productId = razer.productId;
    [skin pushNSObject:productId];
    return 1;
}

/// hs.razer:brightness() -> number
/// Method
/// Gets or sets the `brightness` of a `hs.razer` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `brightness` as a number.
static int razer_brightness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    if (lua_gettop(L) == 1) {
        // Get:
        NSNumber *brightness = razer.brightness;
        [skin pushNSObject:brightness];
    }
    else {
        // Set:
        NSNumber *brightness = razer.brightness;
        BOOL result = [razer setBrightness:brightness];
        if (result){
            [skin pushNSObject:brightness];
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

/// hs.razer:connected() -> boolean
/// Method
/// Is the Razer device still connected?
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean
static int razer_connected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    BOOL isConnected = [razer isConnected];
    lua_pushboolean(L, isConnected);
    return 1;
}

/// hs.razer:ledMode(mode, speed) -> boolean
/// Method
/// Changes the LED mode.
///
/// Parameters:
///  * mode - A string containing the mode you want to activate
///  * [speed] - An optional speed if using "wave" mode
///
/// Returns:
///  * `true` if successful otherwise `false`
///
/// Notes:
///  * Supported modes include:
///    * none
///    * wave
///    * spectrum
///    * reactive
///    * static
///    * static_no_store
///    * starlight
///    * breath
///    * macro
///    * macro_effect
///    * pulsate
static int razer_ledMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSString *mode = [skin toNSObjectAtIndex:2];
    NSNumber *speed = [skin toNSObjectAtIndex:3];
    
    if (speed == nil){
        speed = @1;
    }
    
    BOOL result = [razer writeMode:mode speed:speed];
    lua_pushboolean(L, result);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions

// NOTE: These must not throw a Lua error to ensure LuaSkin can safely be used from Objective-C delegates and blocks:

static int pushHSRazer(lua_State *L, id obj) {
    HSRazer *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSRazer *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSRazerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSRazer *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSRazer, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSRazer *razer = [skin luaObjectAtIndex:1 toClass:"HSRazer"];
    NSString *title = @"Razer Device";
    BOOL isConnected = [razer isConnected];
    NSString *connected = @"Connected";
    if (!isConnected) {
        connected = @"Disconnected";
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ - %@ (%p)", USERDATA_TAG, title, connected, lua_topointer(L, 1)]];
    return 1;
}

static int userdata_eq(lua_State* L) {
    // Can't get here if at least one of us isn't a userdata type, and we only care if both types are ours, so use luaL_testudata before the macro causes a Lua error:
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSRazer *obj1 = [skin luaObjectAtIndex:1 toClass:"HSRazer"];
        HSRazer *obj2 = [skin luaObjectAtIndex:2 toClass:"HSRazer"];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

// User Data Garbage Collection:
static int userdata_gc(lua_State* L) {
    HSRazer *obj = get_objectFromUserdata(__bridge_transfer HSRazer, L, 1, USERDATA_TAG);
    if (obj) {
        obj.selfRefCount--;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L];
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];

            // Disconnect Callback:
            if (obj.callbackToken != nil) {
                //[obj.razer close];
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
    {"ledStatus",                   razer_ledStatus},
    {"firmwareVersion",             razer_firmwareVersion},
    {"brightness",                  razer_brightness},
    {"ledMode",                     razer_ledMode},
    {"connected",                   razer_connected},
    {"callback",                    razer_callback},
    {"internalDeviceId",            razer_internalDeviceId},
    {"productId",                   razer_productId},
    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"new",                 razer_new},
    {"devices",             razer_devices},
    {NULL,  NULL}
};

// Metatable for module:
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

// Initalise Module:
int luaopen_hs_razer_internal(lua_State* L) {
    // Register Module:
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // Register Serial Port:
    [skin registerPushNSHelper:pushHSRazer         forClass:"HSRazer"];
    [skin registerLuaObjectHelper:toHSRazerFromLua forClass:"HSRazer"
              withUserdataMapping:USERDATA_TAG];
    
    return 1;
}
