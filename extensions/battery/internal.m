#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
// #import <Carbon/Carbon.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

@import IOBluetooth;

// Define the private API items of IOBluetooth we wil be using
// Taken from https://github.com/w0lfschild/macOS_headers/blob/master/macOS/Frameworks/IOBluetooth/6.0.2f2/IOBluetoothDevice.h
@interface IOBluetoothDevice (Private)
+ (id)connectedDevices;
- (unsigned short)productID;
- (unsigned short)vendorID;
- (BOOL)isAppleDevice;
@property(readonly) NSString *addressString;
@property(readonly) BOOL isEnhancedDoubleTapSupported;
@property(readonly) BOOL isANCSupported;
@property(readonly) BOOL isInEarDetectionSupported;
@property(nonatomic) unsigned char batteryPercentCombined;
@property(nonatomic) unsigned char batteryPercentCase;
@property(nonatomic) unsigned char batteryPercentRight;
@property(nonatomic) unsigned char batteryPercentLeft;
@property(nonatomic) unsigned char batteryPercentSingle;
@property(nonatomic) unsigned char primaryBud;
@property(nonatomic) unsigned char rightDoubleTap;
@property(nonatomic) unsigned char leftDoubleTap;
@property(nonatomic) unsigned char buttonMode;
@property(nonatomic) unsigned char micMode;
@property(nonatomic) unsigned char secondaryInEar;
@property(nonatomic) unsigned char primaryInEar;
@end

// Helper functions to yank an object from a dictionary by key, and push it onto the LUA stack.
// May be switched to use global NSObject_to_lua, if it ever actually lands in Hammerspoon
// core; but since we're only needing a string, number, or boolean, and only at the top-level
// of the dictionary object, this highly simplified version works just as well.
static void NSObject_to_lua(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) { lua_pushnil(L); }
    else if ([obj isKindOfClass: [NSNumber class]]) {
        NSNumber* number = obj;
        if (number == (id)kCFBooleanTrue)
            lua_pushboolean(L, YES);
        else if (number == (id)kCFBooleanFalse)
            lua_pushboolean(L, NO);
        else if (CFNumberIsFloatType((CFNumberRef)number))
            lua_pushnumber(L, [number doubleValue]);
        else
            lua_pushinteger(L, [number intValue]);
    } else if ([obj isKindOfClass: [NSString class]]) {
        NSString* string = obj;
        lua_pushstring(L, [string UTF8String]);
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"<Object> : %@", obj] UTF8String]) ;
    }
}

static int _push_dict_key_value(lua_State* L, NSDictionary* dict, NSString* key) {
    id value = [dict objectForKey:key];
    NSObject_to_lua(L, value);
    return 1;
}

// Gets battery info from IOPM API.
NSDictionary* get_iopm_battery_info(void) {
    mach_port_t masterPort;
    CFArrayRef batteryInfo;

    if (kIOReturnSuccess == IOMasterPort(MACH_PORT_NULL, &masterPort) &&
        kIOReturnSuccess == IOPMCopyBatteryInfo(masterPort, &batteryInfo) &&
        CFArrayGetCount(batteryInfo))
    {
        CFDictionaryRef battery = CFDictionaryCreateCopy(NULL, CFArrayGetValueAtIndex(batteryInfo, 0));
        CFRelease(batteryInfo);
        return (__bridge_transfer NSDictionary*) battery;
    }
    return NULL;
}

// Get battery info from IOPS API.
NSDictionary* get_iops_battery_info(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();

    if (info == NULL)
        return NULL;


    CFArrayRef list = IOPSCopyPowerSourcesList(info);

    // Nothing we care about here...
    if (list == NULL || !CFArrayGetCount(list)) {
        if (list)
            CFRelease(list);

        CFRelease(info);
        return NULL;
    }

    CFDictionaryRef battery = CFDictionaryCreateCopy(NULL, IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, 0)));

    // Battery is released by ARC transfer.
    CFRelease(list);
    CFRelease(info);

    return (__bridge_transfer NSDictionary* ) battery;
}

// Get battery info from IOPMPS Apple Smart Battery API.
NSDictionary* get_iopmps_battery_info(void) {
    io_registry_entry_t entry = 0;
    entry = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceNameMatching("AppleSmartBattery"));
    if (entry == IO_OBJECT_NULL)
        return nil;

    CFMutableDictionaryRef battery;
    IORegistryEntryCreateCFProperties(entry, &battery, NULL, 0);
    return (__bridge_transfer NSDictionary *) battery;
}

/// hs.battery.cycles() -> number
/// Function
/// Returns the number of discharge cycles of the battery
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of cycles
///
/// Notes:
///  * One cycle is a full discharge of the battery, followed by a full charge. This may also be an aggregate of many smaller discharge-then-charge cycles (e.g. 10 iterations of discharging the battery from 100% to 90% and then charging back to 100% each time, is considered to be one cycle)
static int battery_cycles(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCycleCountKey);
}

/// hs.battery.name() -> string
/// Function
/// Returns the name of the battery
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the battery
static int battery_name(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSNameKey);
}

/// hs.battery.maxCapacity() -> number
/// Function
/// Returns the maximum capacity of the battery in mAh
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the observed maximum capacity of the battery in mAh
///
/// Notes:
///  * This may exceed the value of `hs.battery.designCapacity()` due to small variations in the production chemistry vs the design
static int battery_maxcapacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCapacityKey);
}

/// hs.battery.capacity() -> number
/// Function
/// Returns the current capacity of the battery in mAh
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the current capacity of the battery in mAh
///
/// Notes:
///  * This is the measure of how charged the battery is, vs the value of `hs.battery.maxCapacity()`
static int battery_capacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCurrentChargeKey);
}

/// hs.battery.designCapacity() -> number
/// Function
/// Returns the design capacity of the battery in mAh.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the rated maximum capacity of the battery
static int battery_designcapacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopmps_battery_info(), @kIOPMPSDesignCapacityKey);
}

/// hs.battery.voltage() -> number
/// Function
/// Returns the current voltage of the battery in mV
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the current voltage of the battery
static int battery_voltage(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryVoltageKey);
}

/// hs.battery.amperage() -> number
/// Function
/// Returns the amount of current flowing through the battery, in mAh
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the amount of current flowing through the battery. The value may be:
///   * Less than zero if the battery is being discharged (i.e. the computer is running on battery power)
///   * Zero if the battery is being neither charged nor discharged
///   * Greater than zero if the battery is being charged
static int battery_amperage(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryAmperageKey);
}

/// hs.battery.watts() -> number
/// Function
/// Returns the power entering or leaving the battery, in W
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the rate of energy conversion in the battery. The value may be:
///   * Less than zero if the battery is being discharged (i.e. the computer is running on battery power)
///   * Zero if the battery is being neither charged nor discharged
///   * Greater than zero if the battery is being charged
static int battery_watts(lua_State *L) {
    NSDictionary* battery = get_iopm_battery_info();

    NSNumber *amperage = [battery objectForKey:@kIOBatteryVoltageKey];
    NSNumber *voltage = [battery objectForKey:@kIOBatteryAmperageKey];

    if (amperage && voltage) {
        double battery_wattage = ([amperage doubleValue] * [voltage doubleValue]) / 1000000;
        lua_pushnumber(L, battery_wattage);
    } else
        lua_pushnil(L);

    return 1;
}

/// hs.battery.health() -> string
/// Function
/// Returns the health status of the battery.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing one of {Good, Fair, Poor}, as determined by the Apple Smart Battery controller
static int battery_health(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSBatteryHealthKey);
}

/// hs.battery.healthCondition() -> string or nil
/// Function
/// Returns the health condition status of the battery.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Nil if there are no health conditions to report, or a string containing either:
///   * "Check Battery"
///   * "Permanent Battery Failure"
static int battery_healthcondition(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSBatteryHealthConditionKey);
}

/// hs.battery.percentage() -> number
/// Function
/// Returns the current percentage of battery charge
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the percentage of battery charge
static int battery_percentage(lua_State *L) {
    NSDictionary* battery = get_iops_battery_info();

    // IOPS Gives the proper percentage reading, that the OS displays...
    // IOPM... oddly enough... is a few percentage points off.
    NSNumber *maxCapacity = [battery objectForKey:@kIOPSMaxCapacityKey];
    NSNumber *currentCapacity = [battery objectForKey:@kIOPSCurrentCapacityKey];

    if (maxCapacity && currentCapacity) {
        double battery_percentage = ([currentCapacity doubleValue] / [maxCapacity doubleValue]) * 100;
        lua_pushnumber(L, battery_percentage);
    } else
        lua_pushnil(L);

    return 1;
}

/// hs.battery.timeRemaining() -> number
/// Function
/// Returns the battery life remaining, in minutes
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the minutes of battery life remaining. The value may be:
///   * Greater than zero to indicate the number of minutes remaining
///   * -1 if the remaining battery life is still being calculated
///   * -2 if there is unlimited time remaining (i.e. the system is on AC power)
static int battery_timeremaining(lua_State* L) {
    CFTimeInterval remaining = IOPSGetTimeRemainingEstimate();

    if (remaining > 0)
        remaining /= 60;

    lua_pushnumber(L, remaining);
    return 1;
}

/// hs.battery.timeToFullCharge() -> number
/// Function
/// Returns the time remaining for the battery to be fully charged, in minutes
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the time (in minutes) remaining for the battery to be fully charged, or -1 if the remaining time is still being calculated
static int battery_timetofullcharge(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSTimeToFullChargeKey);
}

/// hs.battery.isCharging() -> boolean
/// Function
/// Returns the charging state of the battery
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the battery is being charged, false if not
static int battery_ischarging(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsChargingKey);
}

/// hs.battery.isCharged() -> boolean
/// Function
/// Returns the charged state of the battery
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the battery is charged, false if not
static int battery_ischarged(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsChargedKey);
}

/// hs.battery.isFinishingCharge() -> boolean or string
/// Function
/// Returns true if battery is finishing its charge
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the battery is in its final charging state (i.e. trickle charging), false if not, or "n/a" if the battery is not charging at all
static int battery_isfinishingcharge(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsFinishingChargeKey);
}

/// hs.battery.powerSource() -> string
/// Function
/// Returns current source of power
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing one of {AC Power, Battery Power, Off Line}.
static int battery_powersource(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSPowerSourceStateKey);
}

/// hs.battery.psuSerial() -> integer
/// Function
/// Returns the serial number of the attached power supply, if present
///
/// Parameters:
///  * None
///
/// Returns:
///  * An integer containing the power supply's serial number, or 0 if no serial can be found
static int battery_psuSerial(lua_State* L) {
    int serial = 0;

    CFDictionaryRef psuInfo = IOPSCopyExternalPowerAdapterDetails();
    if (psuInfo) {
        NSNumber *serialNumber = (__bridge NSNumber *)CFDictionaryGetValue(psuInfo, CFSTR(kIOPSPowerAdapterSerialNumberKey));
        if (serialNumber) {
            serial = [serialNumber intValue];
        }
        CFRelease(psuInfo);
    }

    lua_pushinteger(L, serial);
    return 1;
}

/// hs.battery.psuSerialString() -> string
/// Function
/// Returns the serial string of the attached power supply, if present
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the power supply's serial, or an empty string if no serial can be found
// This uses a private API definition
#ifndef kIOPSPowerAdapterSerialStringKey
#define kIOPSPowerAdapterSerialStringKey    "SerialString"
#endif
static int battery_psuSerialString(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    NSString *serial = @"";

    CFDictionaryRef psuInfo = IOPSCopyExternalPowerAdapterDetails();
    if (psuInfo) {
        NSString *serialString = (__bridge NSString *)CFDictionaryGetValue(psuInfo, CFSTR(kIOPSPowerAdapterSerialStringKey));
        if (serialString) {
            serial = serialString;
        }
        CFRelease(psuInfo);
    }

    [skin pushNSObject:serial];
    return 1;
}

/// hs.battery.otherBatteryInfo() -> table
/// Function
/// Returns information about non-PSU batteries (e.g. bluetooth accessories)
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about other batteries known to the system, or an empty table if no devices were found
static int battery_others(lua_State*L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    mach_port_t     masterPort;
    kern_return_t   kr;
    io_iterator_t   ite;
    io_object_t     obj = 0;
    CFMutableDictionaryRef  properties;
    NSMutableArray *batteryInfo = [NSMutableArray arrayWithCapacity:5];

    kr = IOMasterPort(bootstrap_port, &masterPort);
    if (kr != KERN_SUCCESS) {
        NSLog(@"IOMasterPort() failed: %x\n", kr);
        goto lua_return;
    }

    kr = IORegistryCreateIterator(masterPort,
                                  kIOServicePlane,
                                  true,
                                  &ite);

    while ((obj = IOIteratorNext(ite))) {
        kr = IORegistryEntryCreateCFProperties(obj,
                                               &properties,
                                               kCFAllocatorDefault,
                                               kNilOptions);

        if ((kr != KERN_SUCCESS) || !properties) {
            NSLog(@"IORegistryEntryCreateCFProperties error %x\n", kr);
            goto lua_return;
        } else {
            CFNumberRef percent = (CFNumberRef) CFDictionaryGetValue(properties, CFSTR("BatteryPercent"));
            if (percent) {
                SInt32 s;
                if(CFNumberGetValue(percent, kCFNumberSInt32Type, &s)) {
                    NSDictionary *deviceProperties = (__bridge NSDictionary *)properties;
                    [batteryInfo addObject:deviceProperties];
                }
            }
        }

        CFRelease(properties);
        IOObjectRelease(obj);
    }

    IOObjectRelease(ite);

lua_return:
    [skin pushNSObject:batteryInfo];
    return 1;
}

/// hs.battery.privateBluetoothBatteryInfo() -> table
/// Function
/// Returns information about Bluetooth devices using Apple Private APIs
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about devices using private Apple APIs.
///
/// Notes:
///  * This function uses private Apple APIs - that means it can break without notice on any macOS version update. Please report breakage to us!
///  * This function will return information for all connected Bluetooth devices, but much of it will be meaningless for most devices
///  * The table contains the following keys:
///    * vendorID - Numerical identifier for the vendor of the device (Apple's ID is 76)
///    * productID - Numerical identifier for the device
///    * address - The bluetooth address of the device
///    * isApple - A string containing "YES" or "NO", depending on whether or not this is an Apple/Beats product, or a third party product
///    * name - A human readable string containing the name of the device
///    * batteryPercentSingle - For some devices this will contain the percentage of the battery (e.g. Beats headphones)
///    * batteryPercentCombined - We do not currently understand what this field represents, please report if you find a non-zero value here
///    * batteryPercentCase - Battery percentage of AirPods cases (note that this will often read 0 - the AirPod case sleeps aggressively)
///    * batteryPercentLeft - Battery percentage of the left AirPod if it is out of the case
///    * batteryPercentRight - Battery percentage of the right AirPod if it is out of the case
///    * buttonMode - We do not currently understand what this field represents, please report if you find a value other than 1
///    * micMode - For AirPods this corresponds to the microphone option in the device's Bluetooth options
///    * leftDoubleTap - For AirPods this corresponds to the left double tap action in the device's Bluetooth options
///    * rightDoubleTap - For AirPods this corresponds to the right double tap action in the device's Bluetooth options
///    * primaryBud - For AirPods this is either "left" or "right" depending on which bud is currently considered the primary device
///    * primaryInEar - For AirPods this is "YES" or "NO" depending on whether or not the primary bud is currently in an ear
///    * secondaryInEar - For AirPods this is "YES" or "NO" depending on whether or not the secondary bud is currently in an ear
///    * isInEarDetectionSupported - Whether or not this device can detect when it is currently in an ear
///    * isEnhancedDoubleTapSupported - Whether or not this device supports double tapping
///    * isANCSupported - We believe this likely indicates whether or not this device supports Active Noise Cancelling (e.g. Beats Solo)
///  * Please report any crashes from this function - it's likely that there are Bluetooth devices we haven't tested which may return weird data
///  * Many/Most/All non-Apple party products will likely return zeros for all of the battery related fields here, as will Apple HID devices. It seems that these private APIs mostly exist to support Apple/Beats headphones.
static int battery_private(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    NSMutableArray *privateInfo = [[NSMutableArray alloc] init];

    NSDictionary *devices = [IOBluetoothDevice connectedDevices];
    for (IOBluetoothDevice *device in devices) {
        NSMutableDictionary *deviceInfo = [[NSMutableDictionary alloc] init];
        deviceInfo[@"name"] = device.name;
        //NSLog(@"Found: %@ %i:%i", device.name, device.vendorID, device.productID);
        deviceInfo[@"vendorID"] = [NSString stringWithFormat:@"%i", device.vendorID];
        deviceInfo[@"productID"] = [NSString stringWithFormat:@"%i", device.productID];
        deviceInfo[@"isApple"] = [NSString stringWithFormat:@"%@", device.isAppleDevice ? @"YES" : @"NO"];
        deviceInfo[@"address"] = device.addressString;

        deviceInfo[@"buttonMode"] = [NSString stringWithFormat:@"%i", device.buttonMode];

        deviceInfo[@"batteryPercentCombined"] = [NSString stringWithFormat:@"%i", device.batteryPercentCombined];
        deviceInfo[@"batteryPercentSingle"] = [NSString stringWithFormat:@"%i", device.batteryPercentSingle];

        deviceInfo[@"batteryPercentCase"] = [NSString stringWithFormat:@"%i", device.batteryPercentCase];
        deviceInfo[@"batteryPercentRight"] = [NSString stringWithFormat:@"%i", device.batteryPercentRight];
        deviceInfo[@"batteryPercentLeft"] = [NSString stringWithFormat:@"%i", device.batteryPercentLeft];

        deviceInfo[@"primaryBud"] = [NSString stringWithFormat:@"%@", (device.primaryBud == 1) ? @"left" : @"right"];
        deviceInfo[@"isInEarDetectionSupported"] = [NSString stringWithFormat:@"%@", device.isInEarDetectionSupported ? @"YES" : @"NO"];
        deviceInfo[@"secondaryInEar"] = [NSString stringWithFormat:@"%@", device.secondaryInEar ? @"NO" : @"YES"];
        deviceInfo[@"primaryInEar"] = [NSString stringWithFormat:@"%@", device.primaryInEar ? @"NO" : @"YES"];

        deviceInfo[@"isEnhancedDoubleTapSupported"] = [NSString stringWithFormat:@"%@", device.isEnhancedDoubleTapSupported ? @"YES" : @"NO"];
        deviceInfo[@"rightDoubleTap"] = [NSString stringWithFormat:@"%i", device.rightDoubleTap];
        deviceInfo[@"leftDoubleTap"] = [NSString stringWithFormat:@"%i", device.leftDoubleTap];

        deviceInfo[@"micMode"] = [NSString stringWithFormat:@"%i", device.micMode];
        deviceInfo[@"isANCSupported"] = [NSString stringWithFormat:@"%@", device.isANCSupported ? @"YES" : @"NO"];

        // Store the device
        [privateInfo addObject:deviceInfo];
    }
    [skin pushNSObject:privateInfo];
    return 1;
}

static const luaL_Reg battery_lib[] = {
    {"cycles", battery_cycles},
    {"name", battery_name},
    {"maxCapacity", battery_maxcapacity},
    {"capacity", battery_capacity},
    {"designCapacity", battery_designcapacity},
    {"percentage", battery_percentage},
    {"voltage", battery_voltage},
    {"amperage", battery_amperage},
    {"watts", battery_watts},
    {"health", battery_health},
    {"healthCondition", battery_healthcondition},
    {"timeRemaining", battery_timeremaining},
    {"timeToFullCharge", battery_timetofullcharge},
    {"isCharging", battery_ischarging},
    {"isCharged", battery_ischarged},
    {"isFinishingCharge", battery_isfinishingcharge},
    {"powerSource", battery_powersource},
    {"psuSerial", battery_psuSerial},
    {"psuSerialString", battery_psuSerialString},
    {"otherBatteryInfo", battery_others},
    {"privateBluetoothBatteryInfo", battery_private},
    {NULL, NULL}
};

int luaopen_hs_battery_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.battery" functions:battery_lib metaFunctions:nil];

    return 1;
}
