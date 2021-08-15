@import Cocoa;
@import LuaSkin;

#include <stdio.h>

#include "razerdevice.h"
#include "razerkbd_driver.h"

#import <Foundation/Foundation.h>

#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDUsageTables.h>

#import <IOKit/hidsystem/IOHIDParameter.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

#define USERDATA_TAG  "hs.razer"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Read data from devices JSON files

NSMutableDictionary* devicesCache;

static id getDevicesDictionaryFromJSON() {
    if (!devicesCache) {
        NSString *jsonFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/extensions/hs/razer/devices"];
        
        NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:jsonFilePath
                                                                            error:NULL];
        NSMutableArray *jsonFiles = [[NSMutableArray alloc] init];
        [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *filename = (NSString *)obj;
            NSString *extension = [[filename pathExtension] lowercaseString];
            if ([extension isEqualToString:@"json"]) {
                [jsonFiles addObject:[jsonFilePath stringByAppendingPathComponent:filename]];
            }
        }];
        
        NSMutableDictionary *devices = [NSMutableDictionary dictionary];
        
        for (NSString *filePath in jsonFiles) {
            NSData *JSONData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:NULL];
            
            NSDictionary *JSONObject = [NSJSONSerialization
                             JSONObjectWithData:JSONData
                             options:NSJSONReadingAllowFragments
                             error:NULL];
            
            NSString *productId = [JSONObject objectForKey:@"productId"];
                        
            [devices setObject:JSONObject forKey:productId];
        }
        devicesCache = devices;
    }
    return devicesCache;
}

#pragma mark - Support Functions and Classes

@interface HSRazer : NSObject

@property (nonatomic, strong) id    ioHIDManager;

@property CFMachPortRef             eventTap;

@property NSNumber*                 internalDeviceId;
@property NSNumber*                 productId;

@property NSString*                 name;
@property NSString*                 mainType;
@property NSString*                 image;
@property NSMutableArray*           features;
@property NSMutableArray*           featuresConfig;
@property NSMutableArray*           featuresMissing;
@property NSMutableArray*           buttonNames;
@property NSNumber*                 scrollWheelID;

@property BOOL                      scrollWheelPressed;
@property BOOL                      scrollWheelInProgress;

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
        _scrollWheelPressed         = NO;
        _scrollWheelInProgress      = NO;
    }
    return self;
}

#pragma mark - Event Tap for Scroll Wheel

// We need to use an eventtap to stop the scroll wheel on the Razer Tartarus V2 from actually scrolling.

static CGEventRef eventTapCallback(CGEventTapProxy proxy,
                           CGEventType type,
                           CGEventRef event,
                           void* refcon) {
    
    // Prevent a crash when doing garbage collection:
    if (type == kCGEventTapDisabledByUserInput) {
        return event;
    }
    
    HSRazer *manager = (__bridge HSRazer *)refcon;
    
    // Make sure the manager still exists:
    if (manager == nil) {
        return event;
    }
    
    // Restart event tap if it times out:
    if (type == kCGEventTapDisabledByTimeout) {
        CGEventTapEnable(manager.eventTap, true);
        return event;
    }
    
    // Guard against this callback being delivered at a point where LuaSkin has been reset and our references wouldn't make sense anymore:
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    if (![skin checkGCCanary:manager->_lsCanary]) {
        return event; // Allow the event to pass through unmodified
    }
        
    if (manager.scrollWheelInProgress) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            manager.scrollWheelInProgress = NO;
        });
        return NULL;
    } else {
        return event;
    }
}

- (void)setupEventTap
{
    // Don't setup event tap if it's not supported by the device:
    if (!self.buttonNames || [self.buttonNames count] == 0) {
        NSLog(@"Razer device not supported.");
        return;
    }
    
    CGEventTapLocation location = kCGHIDEventTap;
    
    CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
    
    self.eventTap = CGEventTapCreate(location,
                                     kCGTailAppendEventTap,
                                     kCGEventTapOptionDefault,
                                     mask,
                                     eventTapCallback,
                                     (__bridge void*)(self));
    
    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);

    CGEventTapEnable(self.eventTap, true);
}

- (void)destroyEventTap
{
    if (self.eventTap){
        if (CGEventTapIsEnabled(self.eventTap)) {
            CGEventTapEnable(self.eventTap, false);
        }
        CFRelease(self.eventTap);
    }
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
}

- (void)doGC {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        // Something is wrong and the manager doesn't exist, so just bail
        return;
    }

    // Remove our callbacks
    IOHIDManagerRegisterDeviceMatchingCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback((__bridge IOHIDManagerRef)self.ioHIDManager, NULL, (__bridge void*)self);

    // Remove our HID manager from the runloop
    IOHIDManagerUnscheduleFromRunLoop((__bridge IOHIDManagerRef)self.ioHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // Deallocate the HID manager
    self.ioHIDManager = nil;
}

- (BOOL)startHIDManager {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        return NO;
    }
    
    IOReturn tIOReturn = IOHIDManagerOpen((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

- (BOOL)stopHIDManager {
    if (!(__bridge IOHIDManagerRef)self.ioHIDManager) {
        return YES;
    }

    IOReturn tIOReturn = IOHIDManagerClose((__bridge IOHIDManagerRef)self.ioHIDManager, kIOHIDOptionsTypeNone);
    return tIOReturn == kIOReturnSuccess;
}

static void HIDconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    HSRazer *manager = (__bridge HSRazer *)context;
    // Trigger the Lua callback:
    if (manager.callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:manager.lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"connected"];
        [skin protectedCallAndError:@"hs.razer:callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

static void HIDdisconnect(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    HSRazer *manager = (__bridge HSRazer *)context;
    // Trigger the Lua callback:
    if (manager.callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        
        if (![skin checkGCCanary:manager.lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:manager.callbackRef];
        [skin pushNSObject:manager];
        [skin pushNSObject:@"disconnected"];
        [skin protectedCallAndError:@"hs.razer:callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

static void HIDcallback(void* context, IOReturn result, void* sender, IOHIDValueRef value)
{
    HSRazer *manager = (__bridge HSRazer *)context;
    
    // Don't trigger callback if it's not supported by the device:
    if (!manager.buttonNames || [manager.buttonNames count] == 0) {
        NSLog(@"Razer device not supported.");
        return;
    }
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t scancode = IOHIDElementGetUsage(elem);
    long pressed = IOHIDValueGetIntegerValue(value);
    
    if (scancode < 4 || scancode > 231) {
        return;
    }
    
    // Process the button name:
    NSString *scancodeString = [NSString stringWithFormat:@"%d",scancode];
    NSString *buttonName = [manager.buttonNames valueForKey:scancodeString];
    
    // Abort if there's no button name:
    if (!buttonName) {
        NSLog(@"No button name!");
        return;
    }
    
    // Process the button action:
    NSString *buttonAction = @"";
    if (scancode == [manager.scrollWheelID intValue]) {
        // Scroll Wheel:
        if (pressed == 1){
            manager.scrollWheelInProgress = YES;
            buttonAction = @"up";
        }
        else if (pressed == -1) {
            manager.scrollWheelInProgress = YES;
            buttonAction = @"down";
        }
        else if (pressed == 0) {
            if (manager.scrollWheelPressed) {
                buttonAction = @"released";
                manager.scrollWheelPressed = NO;
            } else {
                buttonAction = @"pressed";
                manager.scrollWheelPressed = YES;
            }
        }
    }
    else
    {
        // Buttons:
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

- (NSMutableDictionary*)getDeviceDetails:(NSNumber *)productId
{
    // Read JSON files:
    NSMutableDictionary *devices = getDevicesDictionaryFromJSON();

    // Convert the NSNumber productId to a hex string (if it doesn't work the first time, try making it uppercase):
    NSString *productIdHexString = @"0x";
    productIdHexString = [productIdHexString stringByAppendingString:[NSString stringWithFormat:@"%04llx", productId.unsignedLongLongValue]];
    id device = [devices valueForKey:productIdHexString];
    if (!device) {
        productIdHexString = @"0x";
        productIdHexString = [productIdHexString stringByAppendingString:[[NSString stringWithFormat:@"%04llx", productId.unsignedLongLongValue] uppercaseString]];
        device = [devices valueForKey:productIdHexString];
    }
    
    return device;
}

- (bool)isDeviceIDValid:(NSNumber *)deviceID
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        NSNumber *productId = [NSNumber numberWithLongLong:device.productId];
        
        if ([internalDeviceId isEqualToNumber:internalDeviceId]) {
            // Save internalDeviceId and productId to the Razer object:
            self.internalDeviceId = internalDeviceId;
            self.productId = productId;
            
            // Read data from the JSON files:
            NSString *name = @"Unknown";
            NSString *mainType = @"Unknown";
            NSString *image= @"Unknown";
            NSMutableArray *features = [NSMutableArray new];
            NSMutableArray *featuresConfig = [NSMutableArray new];
            NSMutableArray *featuresMissing = [NSMutableArray new];
            NSMutableArray *buttonNames = [NSMutableArray new];
            NSNumber *scrollWheelID;
            
            NSMutableDictionary* device = [self getDeviceDetails:productId];
            if (device) {
                name = [device valueForKey:@"name"];
                mainType = [device valueForKey:@"mainType"];
                image = [device valueForKey:@"image"];
                features = [device valueForKey:@"features"];
                featuresConfig = [device valueForKey:@"featuresConfig"];
                featuresMissing = [device valueForKey:@"featuresMissing"];
                buttonNames = [device valueForKey:@"buttonNames"];
                scrollWheelID = [device valueForKey:@"scrollWheelID"];
            }
            
            // Save data from JSON file to the Razer object:
            self.name = name;
            self.mainType = mainType;
            self.image = image;
            self.features = features;
            self.featuresConfig = featuresConfig;
            self.featuresMissing = featuresMissing;
            self.buttonNames = buttonNames;
            self.scrollWheelID = scrollWheelID;
            
            // Setup our HID callbacks based on productId:
            [self setupHID];
            
            // Start the HID Manager:
            [self startHIDManager];
            
            // Setup Event Tap:
            [self setupEventTap];
            
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

- (bool)setKeyboardBacklights:(NSString *)mode speed:(NSNumber *)speed direction:(NSString *)direction color:(NSColor *)color secondaryColor:(NSColor *)secondaryColor customColors:(NSMutableDictionary *)customColors
{
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    for (int i = 0; i < allDevices.size; i++) {
        RazerDevice device = razerDevices[i];
        NSNumber *internalDeviceId = [NSNumber numberWithInt:device.internalDeviceId];
        if ([internalDeviceId isEqualToNumber:self.internalDeviceId]) {
            if ([mode isEqualToString:@"none"]){
                razer_attr_write_mode_none(device.usbDevice, "1", 1);
            }
            else if ([mode isEqualToString:@"spectrum"]){
                razer_attr_write_mode_spectrum(device.usbDevice, "1", 1);
            }
            else if ([mode isEqualToString:@"reactive"]){
                CGFloat redComponent = floor([color redComponent]);
                NSInteger red = (NSInteger) redComponent * 255;
                
                CGFloat greenComponent = floor([color greenComponent]);
                NSInteger green = (NSInteger) greenComponent * 255;
                
                CGFloat blueComponent = floor([color blueComponent]);
                NSInteger blue = (NSInteger) blueComponent * 255;
                
                if (speed == nil){
                    speed = @1;
                }
                
                uint8_t buf[] = {[speed intValue], red, green, blue};
                
                razer_attr_write_mode_reactive(device.usbDevice, (char*)buf, 4);
            }
            else if ([mode isEqualToString:@"static"]){
                CGFloat redComponent = floor([color redComponent]);
                NSInteger red = (NSInteger) redComponent * 255;
                
                CGFloat greenComponent = floor([color greenComponent]);
                NSInteger green = (NSInteger) greenComponent * 255;
                
                CGFloat blueComponent = floor([color blueComponent]);
                NSInteger blue = (NSInteger) blueComponent * 255;
                
                uint8_t buf[] = {red, green, blue};
                razer_attr_write_mode_static(device.usbDevice, (char*)buf, 3);
            }
            else if ([mode isEqualToString:@"static_no_store"]){
                CGFloat redComponent = floor([color redComponent]);
                NSInteger red = (NSInteger) redComponent * 255;
                
                CGFloat greenComponent = floor([color greenComponent]);
                NSInteger green = (NSInteger) greenComponent * 255;
                
                CGFloat blueComponent = floor([color blueComponent]);
                NSInteger blue = (NSInteger) blueComponent * 255;
                
                uint8_t buf[] = {red, green, blue};
                razer_attr_write_mode_static_no_store(device.usbDevice, (char*)buf, 3);
            }
            else if ([mode isEqualToString:@"starlight"]){
                if (speed == nil){
                    speed = @1;
                }
                
                if (color && secondaryColor) {
                    // Two colours:
                    CGFloat redComponent = floor([color redComponent]);
                    NSInteger red = (NSInteger) redComponent * 255;
                    
                    CGFloat greenComponent = floor([color greenComponent]);
                    NSInteger green = (NSInteger) greenComponent * 255;
                    
                    CGFloat blueComponent = floor([color blueComponent]);
                    NSInteger blue = (NSInteger) blueComponent * 255;
                    
                    CGFloat secondaryRedComponent = floor([secondaryColor redComponent]);
                    NSInteger secondaryRed = (NSInteger) secondaryRedComponent * 255;
                    
                    CGFloat secondaryGreenComponent = floor([secondaryColor greenComponent]);
                    NSInteger secondaryGreen = (NSInteger) secondaryGreenComponent * 255;
                    
                    CGFloat secondaryBlueComponent = floor([secondaryColor blueComponent]);
                    NSInteger secondaryBlue = (NSInteger) secondaryBlueComponent * 255;
                    
                    uint8_t buf[] = {[speed intValue], red, green, blue, secondaryRed, secondaryGreen, secondaryBlue};
                    
                    razer_attr_write_mode_starlight(device.usbDevice, (char*)buf, 7);
                }
                else if (color) {
                    // One colour:
                    CGFloat redComponent = floor([color redComponent]);
                    NSInteger red = (NSInteger) redComponent * 255;
                    
                    CGFloat greenComponent = floor([color greenComponent]);
                    NSInteger green = (NSInteger) greenComponent * 255;
                    
                    CGFloat blueComponent = floor([color blueComponent]);
                    NSInteger blue = (NSInteger) blueComponent * 255;
                    
                    uint8_t buf[] = {[speed intValue], red, green, blue};
                    
                    razer_attr_write_mode_starlight(device.usbDevice, (char*)buf, 4);
                }
                else {
                    // Random:
                    uint8_t buf[] = {[speed intValue]};
                    razer_attr_write_mode_starlight(device.usbDevice, (char*)buf, 1);
                }
            }
            else if ([mode isEqualToString:@"breath"]){
                razer_attr_write_mode_breath(device.usbDevice, "1", 1);
            }
            else if ([mode isEqualToString:@"wave"]){
                if (speed == nil){
                    speed = @1;
                }
                if ([direction isEqualToString:@"right"]) {
                    razer_attr_write_mode_wave(device.usbDevice, "2", 0, [speed intValue]);
                }
                else {
                    razer_attr_write_mode_wave(device.usbDevice, "1", 0, [speed intValue]);
                }
            }
            else if ([mode isEqualToString:@"macro"]){
                // TODO: I'm not really sure what "macro" mode does?
                razer_attr_write_mode_macro(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"macro_effect"]){
                // TODO: I'm not really sure what "macro effect" mode does?
                razer_attr_write_mode_macro_effect(device.usbDevice, "", 0);
            }
            else if ([mode isEqualToString:@"pulsate"]){
                razer_attr_write_mode_pulsate(device.usbDevice, "1", 1);
            }
            else if ([mode isEqualToString:@"custom"]){
                NSMutableArray *ripple = [self.featuresConfig valueForKey:@"ripple"];
                if (!ripple) {
                    NSLog(@"This device does not support custom backlights.");
                    return NO;
                }
                                                
                id numberOfRowsArray = [ripple valueForKey:@"rows"];
                id numberOfColumsArray = [ripple valueForKey:@"cols"];
                
                NSInteger numberOfRows = [[numberOfRowsArray objectAtIndex:0] integerValue];
                NSInteger numberOfColums = [[numberOfColumsArray objectAtIndex:0] integerValue];
            
                int customColorsCount = 1;
                
                for (int row = 0; row < numberOfRows; row++)
                {
                    NSInteger bufferSize = 4 + numberOfColums * 3;
                    
                    uint8_t buf[bufferSize];
                    
                    buf[0] = row;
                    buf[1] = 0;
                    buf[2] = numberOfColums - 1;
                                                        
                    int count = 3;
                    for (int column = 0; column < numberOfColums; column++)
                    {
                        NSInteger red = 0;
                        NSInteger green = 0;
                        NSInteger blue = 0;
                                                                                                
                        NSColor *currentColor = customColors[@(customColorsCount)];
                        customColorsCount++;
                        
                        if (currentColor) {
                            CGFloat redComponent = floor([currentColor redComponent]);
                            red = (NSInteger) redComponent * 255;
                            
                            CGFloat greenComponent = floor([currentColor greenComponent]);
                            green = (NSInteger) greenComponent * 255;
                            
                            CGFloat blueComponent = floor([currentColor blueComponent]);
                            blue = (NSInteger) blueComponent * 255;
                        }
    
                        buf[count] = red;
                        count++;
                        buf[count] = green;
                        count++;
                        buf[count] = blue;
                        count++;
                    }
                    
                    razer_attr_write_matrix_custom_frame(device.usbDevice, (char*)buf, count);
                }
                
                razer_attr_write_mode_custom(device.usbDevice, "1", 1);
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

@end

#pragma mark - hs.razer: Functions

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

/// hs.razer.supportedDevices() -> table
/// Function
/// Returns a table of supported Razer devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of supported Razer devices.
///  * This information comes directly from the JSON files that are part of the [Razer macOS project](https://github.com/1kc/razer-macos).
static int razer_supportedDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TBREAK];
    
    // Read JSON files:
    NSMutableDictionary *devices = getDevicesDictionaryFromJSON();
    
    [skin pushNSObject:devices];
    return 1;
}

#pragma mark - hs.razer: Common Methods

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
///  * The callback feature currently only returns "recieved" messages from the Razer Tartarus V2.
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

/// hs.razer:name() -> string
/// Method
/// Returns the human readible device name of the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The device name as a string.
static int razer_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.name];
    return 1;
}

/// hs.razer:mainType() -> string
/// Method
/// Returns a string that defines the hardware type.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string such as "keyboard", "mouse", "headphone", "mousemat", "accessory" or "egpu".
static int razer_mainType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.mainType];
    return 1;
}

/// hs.razer:image() -> string
/// Method
/// Returns the URL as a string that points to an image of the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * URL as a string
static int razer_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.image];
    return 1;
}

/// hs.razer:features() -> table | nil
/// Method
/// Returns a table of features available for the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table or `nil` if no features available for the Razer device.
static int razer_features(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.features];
    return 1;
}

/// hs.razer:featuresConfig() -> table | nil
/// Method
/// Returns a table of feature configurations available for the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table or `nil` if no feature configurations available for the Razer device.
///
/// Notes:
///  * This table might come back empty for some Razer devices.
static int razer_featuresConfig(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.featuresConfig];
    return 1;
}

/// hs.razer:featuresMissing() -> table | nil
/// Method
/// Returns a table of features missing for the Razer device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table or `nil` if no feature missing data available for the Razer device.
static int razer_featuresMissing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:razer.featuresMissing];
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

#pragma mark - hs.razer: Keyboard Methods

/// hs.razer:keyboardStatusLights() -> string
/// Method
/// Gets the Lights status of a Razer keyboard device.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns a string - "red", "blue", "green" or "off".
static int razer_keyboardStatusLights(lua_State *L) {
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

/// hs.razer:keyboardBrightness(value) -> number | nil
/// Method
/// Gets or sets the brightness of a Razer keyboard.
///
/// Parameters:
///  * value - The brightness value - a number between 0 (dark) and 100 (brightest)
///
/// Returns:
///  * The brightness as a number as `nil` if something goes wrong.
static int razer_keyboardBrightness(lua_State *L) {
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
        NSNumber *brightness = [skin toNSObjectAtIndex:2];
        BOOL result = [razer setBrightness:brightness];
        if (result){
            [skin pushNSObject:brightness];
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

#pragma mark - hs.razer: Keyboard Backlights Methods

/// hs.razer:keyboardBacklightsOff() -> boolean
/// Method
/// Turns all the keyboard backlights off.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsOff(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    BOOL result = [razer setKeyboardBacklights:@"none" speed:nil direction:nil color:nil secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsWave(speed, direction) -> boolean
/// Method
/// Changes the keyboard backlights to the wave mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 255 (slow)
///  * direction - "left" or "right" as a string
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsWave(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TSTRING, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSNumber *speed = [skin toNSObjectAtIndex:2];
    NSString *direction = [skin toNSObjectAtIndex:3];
        
    BOOL result = [razer setKeyboardBacklights:@"wave" speed:speed direction:direction color:nil secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsSpectrum() -> boolean
/// Method
/// Changes the keyboard backlights to the spectrum mode.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsSpectrum(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    BOOL result = [razer setKeyboardBacklights:@"spectrum" speed:nil direction:nil color:nil secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsReactive(speed, color) -> boolean
/// Method
/// Changes the keyboard backlights to the reactive mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 255 (slow)
///  * color - A `hs.drawing.color` object
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsReactive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSNumber *speed = [skin toNSObjectAtIndex:2];
    NSColor *color = [skin luaObjectAtIndex:3 toClass:"NSColor"];
                
    BOOL result = [razer setKeyboardBacklights:@"reactive" speed:speed direction:nil color:color secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsStatic(color) -> boolean
/// Method
/// Changes the keyboard backlights to the static mode.
///
/// Parameters:
///  * color - A `hs.drawing.color` object
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsStatic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSColor *color = [skin luaObjectAtIndex:2 toClass:"NSColor"];
                
    BOOL result = [razer setKeyboardBacklights:@"static" speed:nil direction:nil color:color secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsStaticNoStore(color) -> boolean
/// Method
/// Changes the keyboard backlights to the static_no_store mode.
///
/// Parameters:
///  * color - A `hs.drawing.color` object
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsStaticNoStore(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSColor *color = [skin luaObjectAtIndex:2 toClass:"NSColor"];
                
    BOOL result = [razer setKeyboardBacklights:@"static_no_store" speed:nil direction:nil color:color secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsStarlight(speed, [color], [secondaryColor]) -> boolean
/// Method
/// Changes the keyboard backlights to the Starlight mode.
///
/// Parameters:
///  * speed - A number between 1 (fast) and 255 (slow)
///  * [color] - An optional `hs.drawing.color` value
///  * [secondaryColor] - An optional secondary `hs.drawing.color`
///
/// Returns:
///  * The `hs.razer` object.
///  * `true` if successful otherwise `false`
///
/// Notes:
///  * If neither `color` nor `secondaryColor` is provided, then random colors will be used.
static int razer_keyboardBacklightsStarlight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TTABLE | LS_TOPTIONAL | LS_TNIL, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    NSNumber *speed = [skin toNSObjectAtIndex:2];

    NSColor *color;
    NSColor *secondaryColor;
    
    if (lua_type(L, 3) == LUA_TTABLE) {
        color = [skin luaObjectAtIndex:3 toClass:"NSColor"];
    }
    
    if (lua_type(L, 4) == LUA_TTABLE) {
        secondaryColor = [skin luaObjectAtIndex:4 toClass:"NSColor"];
    }
        
    BOOL result = [razer setKeyboardBacklights:@"starlight" speed:speed direction:nil color:color secondaryColor:secondaryColor customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsBreath() -> boolean
/// Method
/// Changes the keyboard backlights to the breath mode.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsBreath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    BOOL result = [razer setKeyboardBacklights:@"breath" speed:nil direction:nil color:nil secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsPulsate() -> boolean
/// Method
/// Changes the keyboard backlights to the Pulsate mode.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if successful otherwise `false`
static int razer_keyboardBacklightsPulsate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    BOOL result = [razer setKeyboardBacklights:@"pulsate" speed:nil direction:nil color:nil secondaryColor:nil customColors:nil];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
}

/// hs.razer:keyboardBacklightsCustom(colors) -> boolean
/// Method
/// Changes the keyboard backlights to custom colours.
///
/// Parameters:
///  * colors - A table of `hs.drawing.color` objects for each individual button on your device (i.e. if there's 20 buttons, you should have twenty colors in the table).
///
/// Returns:
///  * `true` if successful otherwise `false`
///
/// Notes:
///  * Example usage: ```lua
///   hs.razer.new(0):keyboardBacklightsCustom({hs.drawing.color.red})
///   ```
static int razer_keyboardBacklightsCustom(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    
    HSRazer *razer = [skin toNSObjectAtIndex:1];
    
    NSMutableDictionary *customColors = [NSMutableDictionary dictionary];

    lua_pushnil(L); // first key
    while (lua_next(L, 2) != 0) {
        customColors[@(lua_tonumber(L, -2))] = [skin luaObjectAtIndex:-1 toClass:"NSColor"];
        lua_pop(L, 1); // pop value but leave key on stack for `lua_next`
    }
        
    BOOL result = [razer setKeyboardBacklights:@"custom" speed:nil direction:nil color:nil secondaryColor:nil customColors:customColors];
    
    lua_pushvalue(L, 1);
    lua_pushboolean(L, result);
    return 2;
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
    NSString *name = razer.name;
    BOOL isConnected = [razer isConnected];
    NSString *connected = @"Connected";
    if (!isConnected) {
        connected = @"Disconnected";
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ - %@ (%p)", USERDATA_TAG, name, connected, lua_topointer(L, 1)]];
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
            // Stop the Event Tap:
            [obj destroyEventTap];
            
            // Stop HID Manager and perform garbage collection:
            [obj stopHIDManager];
            [obj doGC];
            
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];

            // Disconnect Callback:
            if (obj.callbackToken != nil) {
                //[obj.razer close];
                obj.callbackToken = nil;
            }
            
            // Kill the Canary:
            LSGCCanary tmplsCanary = obj.lsCanary;
            [skin destroyGCCanary:&tmplsCanary];
            obj.lsCanary = tmplsCanary;
            
            obj = nil;
        }
    }
    
    // Remove the Metatable so future use of the variable in Lua won't think its valid:
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
    // Common:
    {"internalDeviceId",                    razer_internalDeviceId},
    {"productId",                           razer_productId},
    
    {"callback",                            razer_callback},
    {"connected",                           razer_connected},
    {"firmwareVersion",                     razer_firmwareVersion},
        
    {"name",                                razer_name},
    {"mainType",                            razer_mainType},
    {"image",                               razer_image},
    {"features",                            razer_features},
    {"featuresConfig",                      razer_featuresConfig},
    {"featuresMissing",                     razer_featuresMissing},
    
    // Keyboard:
    {"keyboardStatusLights",                razer_keyboardStatusLights},
    {"keyboardBrightness",                  razer_keyboardBrightness},
    
    // Keyboard Backlights:
    {"keyboardBacklightsOff",               razer_keyboardBacklightsOff},
    {"keyboardBacklightsCustom",            razer_keyboardBacklightsCustom},
    {"keyboardBacklightsWave",              razer_keyboardBacklightsWave},
    {"keyboardBacklightsSpectrum",          razer_keyboardBacklightsSpectrum},
    {"keyboardBacklightsReactive",          razer_keyboardBacklightsReactive},
    {"keyboardBacklightsStatic",            razer_keyboardBacklightsStatic},
    {"keyboardBacklightsStaticNoStore",     razer_keyboardBacklightsStaticNoStore},
    {"keyboardBacklightsStarlight",         razer_keyboardBacklightsStarlight},
    {"keyboardBacklightsBreath",            razer_keyboardBacklightsBreath},
    {"keyboardBacklightsPulsate",           razer_keyboardBacklightsPulsate},
        
    // Support:
    {"__tostring",                          userdata_tostring},
    {"__eq",                                userdata_eq},
    {"__gc",                                userdata_gc},
    {NULL,                                  NULL}
};

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"supportedDevices",            razer_supportedDevices},
    {"new",                         razer_new},
    {"devices",                     razer_devices},
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
