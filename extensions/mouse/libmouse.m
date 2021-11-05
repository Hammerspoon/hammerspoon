#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#include <IOKit/hidsystem/event_status_driver.h>
#import <IOKit/hidsystem/IOHIDParameter.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hid/IOHIDLib.h>

// We need a dictionary and a callback outside HSmouse so they can be used at the IOKit level
NSMutableArray<NSString *> *mice = nil;
static void enum_callback(void *ctx, IOReturn res, void *sender, IOHIDDeviceRef device) {
    if (res != kIOReturnSuccess) {
        return;
    }

    NSString *vendor = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    NSString *product = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));

    if (vendor == nil) {
        vendor = @"Unknown vendor";
    }

    if (product == nil) {
        product = @"Unknown mouse";
    }

    [mice addObject:[NSString stringWithFormat:@"%@::%@", vendor, product]];
}

// MARK:- Declare HSmouse interface
@interface HSmouse : NSObject
@property (readonly, getter=hasInternalMouse) BOOL hasInternalMouse;
@property (readonly, getter=getCount) int count;
@property (readonly, getter=getNames) NSArray<NSString *> *names;
@property (getter=getAbsolutePosition, setter=setAbsolutePosition:) NSPoint absolutePosition;
@property (readonly, getter=getTrackingSpeed) double trackingSpeed;
@property (readonly, getter=getScrollDirectionNatural) BOOL isScrollDirectionNatural;

-(BOOL)hasInternalMouse;
-(int)getCount;
-(NSArray<NSString *>*)getNames;
-(NSPoint)getAbsolutePosition;
-(void)setAbsolutePosition:(NSPoint)absolutePosition;
-(double)getTrackingSpeed;
-(BOOL)isScrollDirectionNatural;
-(io_service_t)createIOHIDSystem;
-(NSDictionary *)getIOHIDParamtersFromService:(io_service_t)service;
-(NSDictionary *)getIOHIDParameters;
-(kern_return_t)setTrackingSpeed:(double)trackingSpeed;
@end

@implementation HSmouse
// MARK:- Mouse enumeration
#define RUNLOOPMODE (CFSTR("hs.mouse"))
#define MOUSE_TRACKING_FACTOR 65536
-(NSArray<NSString *>*)getNames {
    // This is a highly condensed version of what ManyMouse does to enumerate mice
    IOHIDManagerRef hidman = NULL;

    NSDictionary *matchingDict = @{
        @(kIOHIDDeviceUsagePageKey):@(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey):@(kHIDUsage_GD_Mouse)
    };

    hidman = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    IOHIDManagerRegisterDeviceMatchingCallback(hidman, enum_callback, NULL);
    IOHIDManagerScheduleWithRunLoop(hidman, CFRunLoopGetCurrent(), RUNLOOPMODE);
    IOHIDManagerSetDeviceMatching(hidman, (__bridge CFDictionaryRef)matchingDict);
    IOHIDManagerOpen(hidman, kIOHIDOptionsTypeNone);

    mice = [[NSMutableArray alloc] init];

    // Run a sub-runloop until the initial enumeration of mice is completed
    while (CFRunLoopRunInMode(RUNLOOPMODE, 0, TRUE) == kCFRunLoopRunHandledSource)
        // Do nothing

    // Remove our callback and unschedule from the runloop
    IOHIDManagerRegisterDeviceMatchingCallback(hidman, NULL, NULL);
    IOHIDManagerUnscheduleFromRunLoop(hidman, CFRunLoopGetCurrent(), RUNLOOPMODE);
    IOHIDManagerClose(hidman, kIOHIDOptionsTypeNone);
    CFRelease(hidman);

    return [mice copy];
}

-(BOOL)hasInternalMouse {
    return [self.names containsObject:@"Apple Internal Keyboard / Trackpad"];
}

-(int)getCount {
    return (int)self.names.count;
}

// MARK:- Mouse position
-(NSPoint)getAbsolutePosition {
    CGEventRef ourEvent = CGEventCreate(NULL);
    NSPoint point = CGEventGetLocation(ourEvent);
    CFRelease(ourEvent);
    return point;
}

-(void)setAbsolutePosition:(NSPoint)absolutePosition {
    CGWarpMouseCursorPosition(absolutePosition);
    CGAssociateMouseAndMouseCursorPosition(YES);
}

// MARK:- HID parameters
-(BOOL)getScrollDirectionNatural {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.apple.swipescrolldirection"] boolValue];
}

-(io_service_t)createIOHIDSystem {
    return IORegistryEntryFromPath(kIOMasterPortDefault, kIOServicePlane ":/IOResources/IOHIDSystem");
}

-(NSDictionary *)getIOHIDParamtersFromService:(io_service_t)service {
    return CFBridgingRelease(IORegistryEntryCreateCFProperty(service, CFSTR(kIOHIDParametersKey), kCFAllocatorDefault, kNilOptions));
}

-(NSDictionary *)getIOHIDParameters {
    io_service_t service = [self createIOHIDSystem];
    NSDictionary *parameters = [self getIOHIDParamtersFromService:service];
    IOObjectRelease(service);
    return parameters;
}

-(double)getTrackingSpeed {
    NSDictionary *parameters = [self getIOHIDParameters];
    NSNumber *accel = parameters[@"HIDMouseAcceleration"];
    return accel.doubleValue / MOUSE_TRACKING_FACTOR;
}

-(kern_return_t)setTrackingSpeed:(double)trackingSpeed {
    io_service_t service = [self createIOHIDSystem];

    NSDictionary *parameters = [self getIOHIDParamtersFromService:service];

    NSMutableDictionary *newParameters = [parameters mutableCopy];
    newParameters[@"HIDMouseAcceleration"] = @(trackingSpeed * MOUSE_TRACKING_FACTOR);

    kern_return_t result = IORegistryEntrySetCFProperty(service, CFSTR(kIOHIDParametersKey), (__bridge CFDictionaryRef)newParameters);

    IOObjectRelease(service);

    return result;
}
@end

/// hs.mouse.count([includeInternal]) -> number
/// Function
/// Gets the total number of mice connected to your system.
///
/// Parameters:
///  * includeInternal - A boolean which sets whether or not you want to include internal Trackpad's in the count. Defaults to false.
///
/// Returns:
///  * The number of mice connected to your system
///
/// Notes:
///  * This function leverages code from [ManyMouse](http://icculus.org/manymouse/).
///  * This function considers any mouse labelled as "Apple Internal Keyboard / Trackpad" to be an internal mouse.
static int mouse_count(lua_State* L) {
    LuaSkin *skin = LS_API(LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK);
    BOOL includeInternal = lua_toboolean(L, 1);

    HSmouse *mouseManager = [[HSmouse alloc] init];
    int mouseCount = mouseManager.count;

    if (!includeInternal && mouseManager.hasInternalMouse) {
        mouseCount--;
    }

    lua_pushinteger(skin.L, mouseCount);
    return 1;
}

/// hs.mouse.names() -> table
/// Function
/// Gets the names of any mice connected to the system.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing strings of all the mice connected to the system.
///
/// Notes:
///  * This function leverages code from [ManyMouse](http://icculus.org/manymouse/).
static int mouse_names(lua_State* L) {
    LuaSkin *skin = LS_API(LS_TBREAK);
    HSmouse *mouseManager = [[HSmouse alloc] init];

    [skin pushNSObject:mouseManager.names];
    return 1;
}

/// hs.mouse.absolutePosition([point]) -> point
/// Function
/// Get or set the absolute co-ordinates of the mouse pointer
///
/// Parameters:
///  * An optional point table containing the absolute x and y co-ordinates to move the mouse pointer to
///
/// Returns:
///  * A point table containing the absolute x and y co-ordinates of the mouse pointer
///
/// Notes:
///  * If no parameters are supplied, the current position will be returned. If a point table parameter is supplied, the mouse pointer poisition will be set and the new co-ordinates returned
static int mouse_absolutePosition(lua_State *L) {
    LuaSkin *skin = LS_API(LS_TTABLE|LS_TOPTIONAL, LS_TBREAK);
    HSmouse *mouseManager = [[HSmouse alloc] init];

    if (lua_type(skin.L, 1) == LUA_TTABLE) {
        NSPoint point = [skin tableToPointAtIndex:1];
        mouseManager.absolutePosition = point;
    }

    [skin pushNSPoint:mouseManager.absolutePosition];
    return 1;
}

/// hs.mouse.trackingSpeed([speed]) -> number
/// Function
/// Gets/Sets the current system mouse tracking speed setting
///
/// Parameters:
///  * speed - An optional number containing the new tracking speed to set. If this is ommitted, the current setting is returned
///
/// Returns:
///  * A number indicating the current tracking speed setting for mice
///
/// Notes:
///  * This is represented in the System Preferences as the "Tracking speed" setting for mice
///  * Note that not all values will work, they should map to the steps defined in the System Preferences app, which are:
///    * 0.0, 0.125, 0.5, 0.6875, 0.875, 1.0, 1.5, 2.0, 2.5, 3.0
///  * Note that changes to this value will not be noticed immedaitely by macOS
static int mouse_mouseAcceleration(lua_State *L) {
    LuaSkin *skin = LS_API(LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK);
    HSmouse *mouseManager = [[HSmouse alloc] init];

    if (lua_type(skin.L, 1) == LUA_TNUMBER) {
        kern_return_t result = [mouseManager setTrackingSpeed:lua_tonumber(skin.L, 1)];
        if (result != KERN_SUCCESS) {
            [skin logError:[NSString stringWithFormat:@"Unable to set mouse tracking speed: %d", result]];
        }
    }

    lua_pushnumber(skin.L, mouseManager.trackingSpeed);
    return 1;
}

/// hs.mouse.scrollDirection() -> string
/// Function
/// Gets the system-wide direction of scolling
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string, either "natural" or "normal"
static int mouse_scrollDirection(lua_State *L) {
    LuaSkin *skin = LS_API(LS_TBREAK);
    HSmouse *mouseManager = [[HSmouse alloc] init];

    [skin pushNSObject:mouseManager.isScrollDirectionNatural ? @"natural" : @"normal"];
    return 1;
}

//Note to future authors, there is no function to use kIOHIDTrackpadAccelerationType because it doesn't appear to do anything on modern systems.

static const luaL_Reg mouseLib[] = {
    {"absolutePosition", mouse_absolutePosition},
    {"trackingSpeed", mouse_mouseAcceleration},
    {"scrollDirection", mouse_scrollDirection},
    {"count", mouse_count},
    {"names", mouse_names},
    {NULL, NULL}
};

int luaopen_hs_libmouse(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.mouse" functions:mouseLib metaFunctions:nil];

    return 1;
}
